require "office365"

module PlaceCalendar
  class Office365 < Interface
    DEFAULT_CONFERENCE = "teamsForBusiness"

    def initialize(@tenant : String, @client_id : String, @client_secret : String, @conference_type : String? = DEFAULT_CONFERENCE)
    end

    def client_id : Symbol
      :office365
    end

    def client : ::Office365::Client
      @client ||= ::Office365::Client.new(@tenant, @client_id, @client_secret)
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

    def list_users(query : String? = nil, limit : Int32? = nil, **options) : Array(User)
      if users = client.list_users(query, limit)
        users.value.map { |u| u.to_place_calendar }
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
      if primary = client.get_calendar(mail)
        [primary.to_place_calendar(primary_calendar_id: primary.id, mailbox: mail)]
      else
        [] of Calendar
      end
    rescue ex : ::Office365::Exception
      handle_office365_exception(ex)
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
      # WARNING: This code is conflating calendar_id / mailbox
      mailbox = calendar_id || user_id
      client.list_events_request(**options.merge(mailbox: mailbox, period_start: period_start, period_end: period_end, ical_uid: ical_uid))
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
      # WARNING: This code is conflating calendar_id / mailbox
      mailbox = calendar_id || user_id
      if events = client.list_events(**options.merge(mailbox: mailbox, period_start: period_start, period_end: period_end, ical_uid: ical_uid))
        events.value.map { |e| e.to_place_calendar }
      else
        [] of Event
      end
    rescue ex : ::Office365::Exception
      handle_office365_exception(ex)
    end

    def list_events(user_id : String, response : HTTP::Client::Response) : Array(Event)
      if events = client.list_events(response)
        events.value.map { |e| e.to_place_calendar }
      else
        [] of Event
      end
    rescue ex : ::Office365::Exception
      handle_office365_exception(ex)
    end

    def create_event(user_id : String, event : Event, calendar_id : String? = nil, **options) : Event?
      mailbox = calendar_id || user_id
      params = event_params(event).merge(mailbox: user_id)

      new_event = client.create_event(**params)

      new_event.to_place_calendar
    rescue ex : ::Office365::Exception
      handle_office365_exception(ex)
    end

    def get_event(user_id : String, id : String, calendar_id : String? = nil, **options) : Event?
      mailbox = calendar_id || user_id
      if event = client.get_event(id: id, mailbox: mailbox)
        event.to_place_calendar
      end
    rescue ex : ::Office365::Exception
      handle_office365_exception(ex)
    end

    def update_event(user_id : String, event : Event, calendar_id : String? = nil, **options) : Event?
      mailbox = calendar_id || user_id
      o365_event = ::Office365::Event.new(**event_params(event))

      if updated_event = client.update_event(**options.merge(mailbox: mailbox, event: o365_event))
        updated_event.to_place_calendar
      end
    rescue ex : ::Office365::Exception
      handle_office365_exception(ex)
    end

    def delete_event(user_id : String, id : String, calendar_id : String? = nil, **options) : Bool
      mailbox = calendar_id || user_id
      # TODO: Silently ignoring notify and calendar_id from options. o365 doesn't offer option to notify on deletion
      client.delete_event(mailbox: mailbox, id: id) || false
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
            status: ::Office365::ResponseStatus.new(response: status_type, time: Time::Format::ISO_8601_DATE_TIME.format(Time.utc))
          )
        else
          ::Office365::Attendee.new(
            email: ::Office365::EmailAddress.new(address: a.email, name: a.name)
          )
        end
      end

      sensitivity = event.private? ? ::Office365::Sensitivity::Private : ::Office365::Sensitivity::Normal

      params = {
        id:                      event.id,
        organizer:               event.host,
        starts_at:               event.event_start || Time.local,
        ends_at:                 event.event_end,
        subject:                 event.title || "",
        description:             event.body,
        all_day:                 event.all_day?,
        sensitivity:             sensitivity,
        attendees:               attendees,
        location:                event.location,
        recurrence:              nil,
        online_meeting_provider: @conference_type,
      }
      if event.recurrence
        e_recurrence = event.recurrence.not_nil!
        timezone_loc = event.timezone ? Time::Location.load(event.timezone.not_nil!) : Time::Location.load("UTC")
        recurrence_params = ::Office365::RecurrenceParam.new(pattern: e_recurrence.pattern,
          range_end: e_recurrence.range_end.in(location: timezone_loc),
          interval: e_recurrence.interval,
          days_of_week: e_recurrence.days_of_week)
        params = params.merge(recurrence: recurrence_params)
      end
      params
    end

    def list_attachments(user_id : String, event_id : String, calendar_id : String? = nil, **options) : Array(Attachment)
      if attachments = client.list_attachments(**options.merge(mailbox: user_id, event_id: event_id, calendar_id: calendar_id))
        attachments.value.map { |a| a.to_placecalendar }
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

    def get_availability(user_id : String, calendars : Array(String), starts_at : Time, ends_at : Time) : Array(AvailabilitySchedule)
      if availability = client.get_availability(user_id, calendars, starts_at, ends_at)
        availability.map { |a| a.to_placecalendar }
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
      content = message_html.presence || message_plaintext.not_nil!

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
    PlaceCalendar::User.new(id: @id, name: @display_name, email: email, phone: @mobile_phone, username: @user_principal_name, source: self.to_json)
  end

  def to_place_member
    PlaceCalendar::Member.new(@id, email, @user_principal_name, @display_name, self.to_json)
  end
end

class Office365::Calendar
  def to_place_calendar(primary_calendar_id : String?, mailbox : String? = nil)
    PlaceCalendar::Calendar.new(id: mailbox || @id, summary: @name, primary: (@id == primary_calendar_id), can_edit: @can_edit, source: self.to_json)
  end
end

class Office365::Event
  def to_place_calendar
    event_start = @starts_at || Time.local
    event_end = @ends_at

    if !@timezone.nil?
      tz_location = DateTimeTimeZone.tz_location(@timezone.not_nil!)

      event_start = event_start.in(tz_location)

      if !event_end.nil?
        event_end = event_end.not_nil!.in(tz_location)
      end
    end

    attendees = (@attendees).map do |attendee|
      email = attendee.email_address.address.not_nil!.downcase
      name = attendee.email_address.name || email
      resource = attendee.type == AttendeeType::Resource

      status = if attendee.status
                 case attendee.status.not_nil!.response
                 when Office365::ResponseStatus::Response::None
                   "needsAction"
                 when Office365::ResponseStatus::Response::Organizer
                   "accepted"
                 when Office365::ResponseStatus::Response::TentativelyAccepted
                   "tentative"
                 when Office365::ResponseStatus::Response::Accepted
                   "accepted"
                 when Office365::ResponseStatus::Response::Declined
                   "declined"
                 when Office365::ResponseStatus::Response::NotResponded
                   "declined"
                 end
               end

      PlaceCalendar::Event::Attendee.new(name: name,
        email: email,
        response_status: status,
        resource: resource)
    end

    source_location = @location || @locations.try &.first
    location = if source_location
                 source_location.display_name
               end

    recurrence = if @recurrence
                   e_recurrence = @recurrence.not_nil!
                   range = e_recurrence.range.not_nil!
                   pattern = e_recurrence.pattern.not_nil!
                   days_of_week = pattern.days_of_week ? pattern.days_of_week.not_nil!.first.to_s.downcase : nil
                   recurrence_time_zone_loc = range.recurrence_time_zone ? Time::Location.load(range.recurrence_time_zone.not_nil!) : Time::Location.load("UTC")
                   range_start = Time.parse(range.start_date, pattern: "%F", location: recurrence_time_zone_loc)
                   range_end = Time.parse(range.end_date, pattern: "%F", location: recurrence_time_zone_loc)
                   PlaceCalendar::Recurrence.new(range_start: range_start,
                     range_end: range_end,
                     interval: pattern.interval.not_nil!,
                     pattern: pattern.type.to_s.downcase,
                     days_of_week: days_of_week,
                   )
                 end

    status = if @response_status
               case @response_status.not_nil!.response
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

    PlaceCalendar::Event.new(
      id: @id,
      host: @organizer.try &.email_address.try &.address,
      event_start: event_start,
      event_end: event_end,
      title: @subject,
      body: @body.try &.content,
      attendees: attendees,
      private: is_private?,
      all_day: all_day?,
      location: location,
      source: self.to_json,
      timezone: event_start.location.to_s,
      recurrence: recurrence,
      status: status,
      creator: @organizer.try &.email_address.try &.address,
      recurring_event_id: @series_master_id,
      ical_uid: @icaluid
    )
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
      @availability.map { |a| a.to_placecalendar }
    )
  end
end

class Office365::Availability
  def to_placecalendar
    raise "@starts_at cannot be nil!" if @starts_at.nil?
    raise "@ends_at cannot be nil!" if @ends_at.nil?

    starts_at = @starts_at.not_nil!
    ends_at = @ends_at.not_nil!

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
