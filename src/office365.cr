require "office365"

module PlaceCalendar
  class Office365 < Interface
    DEFAULT_CONFERENCE = "teamsForBusiness"
    DEFAULT_SCOPE      = "https://graph.microsoft.com/.default"

    def initialize(tenant : String, client_id : String, client_secret : String, @conference_type : String? = DEFAULT_CONFERENCE, scopes : String = DEFAULT_SCOPE)
      @delegated_access = false
      @client = ::Office365::Client.new(tenant, client_id, client_secret, scopes)
    end

    def initialize(token : String, @conference_type : String? = DEFAULT_CONFERENCE, @delegated_access = false)
      @client = ::Office365::Client.new(token)
    end

    getter client : ::Office365::Client
    getter? delegated_access : Bool

    @calendar_list_cache = Hash(String, Tuple(Time, Array(::Office365::Calendar))).new

    def client_id : Symbol
      :office365
    end

    def create_notifier(resource : String, notification_url : String, expiration_time : Time, client_secret : String? = nil, **options) : PlaceCalendar::Subscription
      change_type = options[:change_type]? || ::Office365::Subscription::Change::All
      lifecycle_notification_url = options[:lifecycle_notification_url]?
      client.create_subscription(resource, change_type, notification_url, expiration_time, client_secret, lifecycle_notification_url).to_place_subscription(notification_url)
    rescue ex : ::Office365::Exception
      handle_office365_exception(ex)
    end

    def renew_notifier(subscription : PlaceCalendar::Subscription, new_expiration_time : Time) : PlaceCalendar::Subscription
      client.renew_subscription(subscription.id, new_expiration_time).to_place_subscription(subscription.notification_url)
    rescue ex : ::Office365::Exception
      handle_office365_exception(ex)
    end

    def reauthorize_notifier(subscription : PlaceCalendar::Subscription, new_expiration_time : Time? = nil) : PlaceCalendar::Subscription
      client.reauthorize_subscription(subscription.id)
      renew_notifier(subscription, new_expiration_time || subscription.expires_at.as(Time))
    rescue ex : ::Office365::Exception
      handle_office365_exception(ex)
    end

    def delete_notifier(subscription : PlaceCalendar::Subscription) : Nil
      client.delete_subscription(subscription.id)
    rescue ex : ::Office365::Exception
      handle_office365_exception(ex)
    end

    def access_token(user_id : String? = nil) : NamedTuple(expires: Time, token: String)
      token = client.get_token
      {expires: token.created_at + token.expires_in.seconds, token: token.access_token}
    end

    def get_groups(user_id : String, **options) : Array(Group)
      client.groups_member_of(user_id).value.map(&.to_place_group)
    rescue ex : ::Office365::Exception
      handle_office365_exception(ex)
    end

    def get_members(group_id : String, **options) : Array(Member)
      client.list_group_members(group_id).value.map(&.to_place_member)
    rescue ex : ::Office365::Exception
      handle_office365_exception(ex)
    end

    def list_users(query : String? = nil, limit : Int32? = nil, filter : String? = nil, **options) : Array(User)
      filter_string = AzureADFilter::Parser.parse(filter).to_s if filter
      if users = client.list_users(query, limit, **options, filter: filter_string)
        users.value.map(&.to_place_calendar)
      else
        [] of User
      end
    rescue ex : ::Office365::Exception
      handle_office365_exception(ex)
    end

    def get_user(id : String, **options) : User?
      if user = client.get_user(**options.merge(id: id))
        user.to_place_calendar
      end
    rescue ex : ::Office365::Exception
      handle_office365_exception(ex)
    end

    # This function will work with IDs and emails
    def get_user_by_email(email : String, **options) : User?
      if email.includes?("@")
        client.get_user_by_mail(email).to_place_calendar
      else
        get_user(email, **options)
      end
    rescue ex : ::Office365::Exception
      handle_office365_exception(ex)
    rescue error : Enumerable::EmptyError
      nil
    end

    def get_calendar(id : String, **options) : Calendar
      {{ raise "Uninplemented" }}
    end

    def list_calendars(mail : String, **options) : Array(Calendar)
      only_writable = options[:only_writable]? || false

      mail = mail.downcase

      if delegated_access?
        cached_list = @calendar_list_cache.delete(mail)
        if cached_list
          expires, cached = cached_list
          expires = cached = nil if expires && expires <= Time.utc
        end
      end

      if calendars = cached || client.list_calendars(mail).value
        if delegated_access?
          expires = expires || 10.minutes.from_now
          @calendar_list_cache[mail] = {expires, calendars}
        end

        calendars.compact_map do |calendar|
          # we only want to list calendars with mailboxes
          next if calendar.is_removable? && calendar.owner.try(&.address.try(&.downcase)) == mail

          if only_writable
            calendar.to_place_calendar(mail) if calendar.can_edit?
          else
            calendar.to_place_calendar(mail)
          end
        end
      else
        [] of Calendar
      end
    rescue ex : ::Office365::Exception
      handle_office365_exception(ex)
    end

    protected def extract_user_calendar_params(user_id, calendar_id)
      if calendar_id && delegated_access?
        mailbox = user_id
        if calendar_id == mailbox
          calendar_id = nil
        elsif calendar_id.includes?('@')
          # we need to convert this email to the actual id of the calendar
          find_cal = calendar_id.downcase
          if result = list_calendars(mailbox).find { |cal| cal.id.try(&.downcase) == find_cal }
            calendar_id = result.ref
          end
        end
      else
        mailbox = calendar_id || user_id
        calendar_id = nil
      end
      {mailbox, calendar_id}
    end

    def list_events_request(
      user_id : String,
      calendar_id : String? = nil,
      period_start : Time = Time.local.at_beginning_of_day,
      period_end : Time? = nil,
      ical_uid : String? = nil,
      showDeleted : Bool? = nil,
      **options
    ) : HTTP::Request
      mailbox, calendar_id = extract_user_calendar_params(user_id, calendar_id)
      client.list_events_request(**options.merge(mailbox: mailbox, calendar_id: calendar_id, period_start: period_start, period_end: period_end, ical_uid: ical_uid))
    rescue ex : ::Office365::Exception
      handle_office365_exception(ex)
    end

    def list_events(
      user_id : String,
      calendar_id : String? = nil,
      period_start : Time = Time.local.at_beginning_of_day,
      period_end : Time? = nil,
      ical_uid : String? = nil,
      showDeleted : Bool? = nil,
      **options
    ) : Array(Event)
      # TODO: support showDeleted, silently ignoring for now. Currently calendarView only returns non cancelled events
      mailbox, calendar_id = extract_user_calendar_params(user_id, calendar_id)
      if events = client.list_events(**options.merge(mailbox: mailbox, calendar_id: calendar_id, period_start: period_start, period_end: period_end, ical_uid: ical_uid))
        events.value.map(&.to_place_calendar(mailbox))
      else
        [] of Event
      end
    rescue ex : ::Office365::Exception
      handle_office365_exception(ex)
    end

    def list_events(user_id : String, response : HTTP::Client::Response) : Array(Event)
      if events = client.list_events(response)
        events.value.map(&.to_place_calendar(user_id))
      else
        [] of Event
      end
    rescue ex : ::Office365::Exception
      handle_office365_exception(ex)
    end

    def create_event(user_id : String, event : Event, calendar_id : String? = nil, **options) : Event?
      mailbox, calendar_id = extract_user_calendar_params(user_id, calendar_id)
      params = event_params(event).merge(mailbox: mailbox, calendar_id: calendar_id)

      new_event = client.create_event(**params)

      new_event.to_place_calendar(mailbox)
    rescue ex : ::Office365::Exception
      handle_office365_exception(ex)
    end

    def get_event(user_id : String, id : String, calendar_id : String? = nil, **options) : Event?
      mailbox, calendar_id = extract_user_calendar_params(user_id, calendar_id)
      if event = client.get_event(id: id, mailbox: mailbox, calendar_id: calendar_id)
        event.to_place_calendar(mailbox)
      end
    rescue ex : ::Office365::Exception
      handle_office365_exception(ex)
    end

    def update_event(user_id : String, event : Event, calendar_id : String? = nil, **options) : Event?
      mailbox, calendar_id = extract_user_calendar_params(user_id, calendar_id)
      o365_event = ::Office365::Event.new(**event_params(event))

      if updated_event = client.update_event(**options.merge(mailbox: mailbox, calendar_id: calendar_id, event: o365_event))
        updated_event.to_place_calendar(mailbox)
      end
    rescue ex : ::Office365::Exception
      handle_office365_exception(ex)
    end

    def delete_event(user_id : String, id : String, calendar_id : String? = nil, **options) : Bool
      mailbox, calendar_id = extract_user_calendar_params(user_id, calendar_id)
      # TODO: Silently ignoring notify from options. o365 doesn't offer option to notify on deletion
      client.delete_event(mailbox: mailbox, calendar_id: calendar_id, id: id) || false
    rescue ex : ::Office365::Exception
      handle_office365_exception(ex)
    end

    def decline_event(user_id : String, id : String, calendar_id : String? = nil, notify : Bool = true, comment : String? = nil, **options) : Bool
      mailbox, calendar_id = extract_user_calendar_params(user_id, calendar_id)
      response = client.decline_event(mailbox: mailbox, calendar_id: calendar_id, id: id, notify: notify, comment: comment)
      # Office365 requires you cancel an event if you're the host so we just check if the above failed
      response = client.cancel_event(mailbox: mailbox, id: id, comment: comment) unless response
      response
    rescue ex : ::Office365::Exception
      handle_office365_exception(ex)
    end

    private def event_params(event)
      attendees = event.attendees.map do |a|
        if a.response_status
          status_type = case a.response_status
                        when "needsAction"
                          ::Office365::ResponseStatus::Response::NotResponded
                        when "accepted"
                          ::Office365::ResponseStatus::Response::Accepted
                        when "tentative"
                          ::Office365::ResponseStatus::Response::TentativelyAccepted
                        when "declined"
                          ::Office365::ResponseStatus::Response::Declined
                        else
                          ::Office365::ResponseStatus::Response::NotResponded
                        end

          ::Office365::Attendee.new(
            email: ::Office365::EmailAddress.new(address: a.email, name: a.name),
            status: ::Office365::ResponseStatus.new(response: status_type, time: Time::Format::ISO_8601_DATE_TIME.format(Time.utc)),
            type: a.resource ? ::Office365::AttendeeType::Resource : ::Office365::AttendeeType::Required
          )
        else
          ::Office365::Attendee.new(
            email: ::Office365::EmailAddress.new(address: a.email, name: a.name),
            type: a.resource ? ::Office365::AttendeeType::Resource : ::Office365::AttendeeType::Required
          )
        end
      end

      sensitivity = event.private? ? ::Office365::Sensitivity::Private : ::Office365::Sensitivity::Normal
      starts_at = event.event_start || Time.local

      params = {
        id:                      event.id,
        organizer:               event.host,
        starts_at:               starts_at,
        ends_at:                 event.event_end,
        subject:                 event.title || "",
        description:             event.body,
        all_day:                 event.all_day?,
        sensitivity:             sensitivity,
        attendees:               attendees,
        hide_attendees:          event.hide_attendees?,
        location:                event.location,
        recurrence:              nil,
        online_meeting_provider: event.online_meeting_provider || @conference_type,
      }
      if e_recurrence = event.recurrence
        timezone = event.timezone
        timezone_loc = timezone ? Time::Location.load(timezone) : Time::Location.load("UTC")

        index = nil
        day_of_month = nil
        pattern = case e_recurrence.pattern
                  when "monthly"
                    # need to calculate the weekly index
                    starts_at = starts_at.in(timezone_loc)
                    week = starts_at.day // 7
                    index = ::Office365::WeekIndex.from_value week
                    "relativeMonthly"
                  when "month_day"
                    day_of_month = starts_at.in(timezone_loc).day
                    "absoluteMonthly"
                  else
                    e_recurrence.pattern
                  end

        recurrence_params = ::Office365::RecurrenceParam.new(
          pattern: pattern,
          range_end: e_recurrence.range_end.in(location: timezone_loc),
          interval: e_recurrence.interval,
          days_of_week: e_recurrence.days_of_week,
          index: index,
          day_of_month: day_of_month
        )
        params = params.merge(recurrence: recurrence_params)
      end
      params
    end

    def list_attachments(user_id : String, event_id : String, calendar_id : String? = nil, **options) : Array(Attachment)
      if attachments = client.list_attachments(**options.merge(mailbox: user_id, event_id: event_id, calendar_id: calendar_id))
        attachments.value.map(&.to_placecalendar)
      else
        [] of Attachment
      end
    rescue ex : ::Office365::Exception
      handle_office365_exception(ex)
    end

    def get_attachment(user_id : String, event_id : String, id : String, calendar_id : String? = nil, **options) : Attachment?
      if attachment = client.get_attachment(**options.merge(mailbox: user_id, event_id: event_id, id: id, calendar_id: calendar_id))
        attachment.to_placecalendar
      else
        nil
      end
    rescue ex : ::Office365::Exception
      handle_office365_exception(ex)
    end

    def create_attachment(user_id : String, event_id : String, attachment : Attachment, calendar_id : String? = nil, **options) : Attachment?
      params = options.merge(mailbox: user_id, event_id: event_id, calendar_id: calendar_id)
      if new_attachment = client.create_attachment(**params.merge(attachment_params(attachment)))
        new_attachment.to_placecalendar
      else
        nil
      end
    rescue ex : ::Office365::Exception
      handle_office365_exception(ex)
    end

    def delete_attachment(id : String, user_id : String, event_id : String, calendar_id : String? = nil, **options) : Bool
      if client.delete_attachment(**options.merge(id: id, mailbox: user_id, event_id: event_id, calendar_id: calendar_id))
        true
      else
        false
      end
    rescue ex : ::Office365::Exception
      handle_office365_exception(ex)
    end

    def get_availability(user_id : String, calendars : Array(String), starts_at : Time, ends_at : Time, **options) : Array(AvailabilitySchedule)
      view_interval = options[:view_interval]? || 30

      # Max is 100 so we need to batch if we're above this
      if calendars.size > 100
        requests = Array(HTTP::Request).new((calendars.size / 100).round(:to_positive).to_i)
        calendars.in_groups_of(100) do |cals|
          requests << client.get_availability_request(user_id, cals.compact, starts_at, ends_at, view_interval)
        end
        client.batch(requests).values.flat_map { |response| client.get_availability(response).map(&.to_placecalendar) }
      elsif availability = client.get_availability(user_id, calendars, starts_at, ends_at, view_interval)
        availability.map(&.to_placecalendar)
      else
        [] of AvailabilitySchedule
      end
    rescue ex : ::Office365::Exception
      handle_office365_exception(ex)
    end

    def batch(user_id : String, requests : Indexable(HTTP::Request)) : Hash(HTTP::Request, HTTP::Client::Response)
      client.batch(requests)
    rescue ex : ::Office365::Exception
      handle_office365_exception(ex)
    end

    private def attachment_params(attachment)
      {
        name:          attachment.name,
        content_bytes: attachment.content_bytes,
      }
    end

    def send_mail(
      from : String,
      to : String | Array(String),
      subject : String,
      message_plaintext : String? = nil,
      message_html : String? = nil,
      resource_attachments : Array(ResourceAttachment) = [] of ResourceAttachment,
      attachments : Array(EmailAttachment) = [] of EmailAttachment,
      cc : String | Array(String) = [] of String,
      bcc : String | Array(String) = [] of String
    )
      content_type = message_html.presence ? "HTML" : "Text"
      content = message_html.presence || message_plaintext || ""

      attach = attachments.map { |a| ::Office365::Attachment.new(a[:file_name], a[:content], base64_encoded: true) }
      attach.concat resource_attachments.map { |a|
        tmp_attach = ::Office365::Attachment.new(a[:file_name], a[:content], base64_encoded: true)
        tmp_attach.content_id = a[:content_id]
        tmp_attach
      }

      client.send_mail(
        from,
        ::Office365::Message.new(
          subject,
          content,
          content_type,
          to_array(to),
          to_array(cc),
          to_array(bcc),
          attachments: attach
        )
      )
    end

    private def handle_office365_exception(ex : ::Office365::Exception)
      raise PlaceCalendar::Exception.new(ex.http_status, ex.http_body, ex.message)
    end
  end
end

class Office365::User
  def to_place_calendar
    PlaceCalendar::User.new(
      id: @id,
      name: @display_name,
      title: @job_title,
      email: email,
      phone: @mobile_phone,
      username: @user_principal_name,
      source: self.to_json
    )
  end

  def to_place_member
    PlaceCalendar::Member.new(@id, email, @user_principal_name, @display_name, self.to_json)
  end
end

class Office365::Calendar
  def to_place_calendar(mailbox : String? = nil)
    id = @owner.try(&.address) || mailbox || @id

    PlaceCalendar::Calendar.new(
      id: id,
      summary: @name,
      primary: !!self.is_default_calendar?,
      can_edit: !!self.can_edit?,
      ref: @id,
      source: self.to_json
    )
  end
end

class Office365::Event
  def to_place_calendar(mailbox : String? = nil)
    event_start = @starts_at || Time.local
    event_end = @ends_at

    if timezone = @timezone.presence
      tz_location = DateTimeTimeZone.tz_location(timezone)
      event_start = event_start.in(tz_location)

      if ending = event_end
        event_end = ending.in(tz_location)
      end
    end

    attendees = (@attendees).compact_map do |attendee|
      email = attendee.email_address.address
      next unless email
      email = email.downcase
      name = attendee.email_address.name || email
      resource = attendee.type == AttendeeType::Resource

      status = if attend_status = attendee.status
                 case attend_status.response
                 in Office365::ResponseStatus::Response::None
                   "needsAction"
                 in Office365::ResponseStatus::Response::Organizer
                   "accepted"
                 in Office365::ResponseStatus::Response::TentativelyAccepted
                   "tentative"
                 in Office365::ResponseStatus::Response::Accepted
                   "accepted"
                 in Office365::ResponseStatus::Response::Declined
                   "declined"
                 in Office365::ResponseStatus::Response::NotResponded
                   "needsAction"
                 in Nil
                   "needsAction"
                 end
               end

      PlaceCalendar::Event::Attendee.new(name: name,
        email: email,
        response_status: status,
        resource: resource)
    end

    source_location = @location || @locations.try &.first?
    location = source_location.try &.display_name

    recurrence = if (e_recurrence = @recurrence) && (range = e_recurrence.range) && (pattern = e_recurrence.pattern)
                   days_of_week = pattern.days_of_week ? pattern.days_of_week.try(&.map(&.to_s.downcase)) : nil

                   recurrence_time_zone = range.recurrence_time_zone
                   recurrence_time_zone_loc = recurrence_time_zone ? Time::Location.load(recurrence_time_zone) : Time::Location.load("UTC")
                   range_start = Time.parse(range.start_date, pattern: "%F", location: recurrence_time_zone_loc)
                   range_end = Time.parse(range.end_date, pattern: "%F", location: recurrence_time_zone_loc)

                   pos_pattern = case pattern.type.as(::Office365::RecurrencePatternType)
                                 when .absolute_monthly?
                                   "month_day"
                                 when .relative_monthly?
                                   "monthly"
                                 else
                                   pattern.type.to_s.downcase
                                 end

                   PlaceCalendar::Recurrence.new(range_start: range_start,
                     range_end: range_end,
                     interval: pattern.interval.not_nil!,
                     pattern: pos_pattern,
                     days_of_week: days_of_week || [] of String,
                   )
                 end

    if @is_cancelled
      status = "cancelled"
    else
      status = if resp_status = @response_status
                 case resp_status.response
                 when Office365::ResponseStatus::Response::Accepted
                   "confirmed"
                 when Office365::ResponseStatus::Response::Organizer
                   "confirmed"
                 when Office365::ResponseStatus::Response::TentativelyAccepted
                   "tentative"
                 when Office365::ResponseStatus::Response::Declined
                   "cancelled"
                 end
               end
    end

    PlaceCalendar::Event.new(
      id: @id,
      host: @organizer.try &.email_address.try &.address,
      event_start: event_start,
      event_end: event_end,
      title: @subject,
      body: @body.try &.content,
      attendees: attendees,
      hide_attendees: @hide_attendees,
      private: is_private?,
      all_day: all_day?,
      location: location,
      source: self.to_json,
      timezone: event_start.location.to_s,
      recurrence: recurrence,
      status: status,
      creator: @organizer.try &.email_address.try &.address,
      recurring_event_id: @series_master_id,
      ical_uid: @icaluid,
      online_meeting_provider: online_meeting_provider,
      online_meeting_phones: online_meeting_phones,
      online_meeting_url: online_meeting_url,
      online_meeting_id: online_meeting_id,
      created: @created,
      updated: @updated,
    ).set_mailbox(mailbox)
  end
end

class Office365::Attachment
  def to_placecalendar
    PlaceCalendar::Attachment.new(
      id: @id,
      name: @name,
      content_type: @content_type,
      content_bytes: @content_bytes,
      size: @size
    )
  end
end

class Office365::AvailabilitySchedule
  def to_placecalendar
    PlaceCalendar::AvailabilitySchedule.new(
      @calendar,
      @availability.map(&.to_placecalendar)
    )
  end
end

class Office365::Availability
  def to_placecalendar
    starts_at = @starts_at
    ends_at = @ends_at

    raise "@starts_at cannot be nil!" unless starts_at
    raise "@ends_at cannot be nil!" unless ends_at

    PlaceCalendar::Availability.new(
      @status == ::Office365::AvailabilityStatus::Free ? PlaceCalendar::AvailabilityStatus::Free : PlaceCalendar::AvailabilityStatus::Busy,
      starts_at,
      ends_at,
      starts_at.location.to_s
    )
  end
end

class Office365::Group
  def to_place_group
    PlaceCalendar::Group.new(@id, @display_name, @mail, @description, self.to_json)
  end
end

class Office365::Subscription
  def to_place_subscription(notification_url : String)
    PlaceCalendar::Subscription.new(@id.as(String), @resource, @resource, notification_url, @expiration_date_time, @client_state, source: self.to_json)
  end
end
