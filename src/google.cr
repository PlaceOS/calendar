require "uri"
require "mime"
require "uuid"
require "email"

module PlaceCalendar
  class Google < Interface
    DEFAULT_CONFERENCE = "hangoutsMeet"

    @static_auth : ::Google::Auth? = nil

    def initialize(
      @file_path : String,
      @scopes : String | Array(String),
      @domain : String,
      @sub : String = "",
      @user_agent : String = "PlaceOS",
      @conference_type : String? = DEFAULT_CONFERENCE
    )
      @delegated_access = false
      @signing_key = @issuer = ""
    end

    def initialize(
      @issuer : String,
      @signing_key : String,
      @scopes : String | Array(String),
      @domain : String,
      @sub : String = "",
      @user_agent : String = "PlaceOS",
      @conference_type : String? = DEFAULT_CONFERENCE
    )
      @delegated_access = false
      @file_path = ""
    end

    def initialize(
      auth : ::Google::Auth,
      @domain : String,
      @user_agent : String = "PlaceOS",
      @conference_type : String? = DEFAULT_CONFERENCE,
      @delegated_access : Bool = false
    )
      @static_auth = auth
      @signing_key = @issuer = @file_path = @scopes = @sub = ""
    end

    def client_id : Symbol
      :google
    end

    getter? delegated_access : Bool

    def auth(sub = @sub) : ::Google::Auth
      if auth = @static_auth
        auth
      elsif @file_path.empty?
        ::Google::Auth.new(issuer: @issuer, signing_key: @signing_key, scopes: @scopes, sub: sub, user_agent: @user_agent)
      else
        ::Google::FileAuth.new(file_path: @file_path, scopes: @scopes, sub: sub, user_agent: @user_agent)
      end
    rescue ex : ::Google::Exception
      handle_google_exception(ex)
    end

    def access_token(user_id : String? = nil) : NamedTuple(expires: Time, token: String)
      token = auth(user_id || @sub).get_token
      {expires: token.expires, token: token.access_token}
    end

    # https://developers.google.com/calendar/api/guides/push
    def create_notifier(resource : String, notification_url : String, expiration_time : Time, client_secret : String? = nil, **options) : PlaceCalendar::Subscription
      notifier_id = UUID.random.to_s
      user_id = options[:user_id]? || @sub
      calendar(user_id).watch(notifier_id, resource, notification_url, client_secret, expiration_time).to_place_subscription(user_id, resource, notification_url)
    end

    def renew_notifier(subscription : PlaceCalendar::Subscription, new_expiration_time : Time) : PlaceCalendar::Subscription
      # There is no renewal process with google, the subscriptions will just overlap for a short period of time
      create_notifier(subscription.resource_uri, subscription.notification_url, new_expiration_time, subscription.client_secret, user_id: subscription.user_id)
    end

    def reauthorize_notifier(subscription : PlaceCalendar::Subscription, new_expiration_time : Time? = nil) : PlaceCalendar::Subscription
      raise NotImplementedError.new("google watchers don't support reauthorization")
    end

    def delete_notifier(subscription : PlaceCalendar::Subscription) : Nil
      calendar(subscription.user_id || @sub).stop_watching(subscription.id, subscription.resource_id)
    end

    def get_groups(user_id : String, **options) : Array(Group)
      directory.groups(user_id).groups.map(&.to_place_group)
    rescue ex : ::Google::Exception
      handle_google_exception(ex)
    end

    def get_members(group_id : String, **options) : Array(Member)
      directory.members(group_id).members.map(&.to_place_member)
    rescue ex : ::Google::Exception
      handle_google_exception(ex)
    end

    def list_users(query : String? = nil, limit : Int32? = nil, filter : String? = nil, **options) : Array(User)
      query = AzureADFilter::Parser.parse(filter).to_google if filter
      if users = directory.users(query, limit || 500, **options)
        # TODO: Deal with pagination
        users.users.map(&.to_place_calendar)
      else
        [] of User
      end
    rescue ex : ::Google::Exception
      handle_google_exception(ex)
    end

    def get_user(id : String, **options) : User?
      if user = directory.lookup(id)
        user.to_place_calendar
      else
        nil
      end
    rescue ex : ::Google::Exception
      handle_google_exception(ex)
    end

    def get_user_by_email(email : String, **options) : User?
      list_users(email: email).first?
    end

    def list_calendars(mail : String, **options) : Array(Calendar)
      only_writable = options[:only_writable]? || false
      calendars = only_writable ? calendar(mail).calendar_list(::Google::Access::Writer) : calendar(mail).calendar_list
      if calendars
        # filtering out hidden and rejected calendars as seen in google-staff-api
        calendars.compact_map { |item|
          item.to_place_calendar unless item.hidden || item.deleted
        }
      else
        [] of Calendar
      end
    rescue ex : ::Google::Exception
      handle_google_exception(ex)
    end

    def get_calendar(id : String, **options) : Calendar
    end

    def list_events_request(
      user_id : String,
      calendar_id : String? = nil,
      period_start : Time = Time.local.at_beginning_of_day,
      period_end : Time? = nil,
      ical_uid : String? = nil,
      **options
    ) : HTTP::Request
      calendar_id = "primary" if calendar_id.nil?

      calendar(user_id).events_request(calendar_id, period_start, period_end, **options.merge(iCalUID: ical_uid))
    rescue ex : ::Google::Exception
      handle_google_exception(ex)
    end

    def list_events(
      user_id : String,
      calendar_id : String? = nil,
      period_start : Time = Time.local.at_beginning_of_day,
      period_end : Time? = nil,
      ical_uid : String? = nil,
      **options
    ) : Array(Event)
      # user_id ignored?
      # TODO: how to avoid duplicating default values from the shards
      calendar_id = "primary" if calendar_id.nil?

      if events = calendar(user_id).events(calendar_id, period_start, period_end, **options.merge(iCalUID: ical_uid))
        events.items.map(&.to_place_calendar)
      else
        [] of Event
      end
    rescue ex : ::Google::Exception
      handle_google_exception(ex)
    end

    def list_events(user_id : String, response : HTTP::Client::Response) : Array(Event)
      if events = calendar(user_id).events(response)
        events.items.map(&.to_place_calendar)
      else
        [] of Event
      end
    rescue ex : ::Google::Exception
      handle_google_exception(ex)
    end

    def get_event(user_id : String, id : String, calendar_id : String = "primary", **options) : Event?
      if event = calendar(user_id).event(id, calendar_id)
        event.to_place_calendar
      else
        nil
      end
    rescue ex : ::Google::Exception
      handle_google_exception(ex)
    end

    alias EntryPoint = ::Google::Calendar::EntryPoint

    def create_event(user_id : String, event : Event, calendar_id : String? = nil, **options) : Event?
      new_event = if meeting_url = event.online_meeting_url
                    meeting_uri = URI.parse meeting_url
                    meeting_type = meeting_uri.host.try &.starts_with?("meet.") ? "hangoutsMeet" : "addOn"

                    meeting_id = event.online_meeting_id
                    meeting_id ||= meeting_type == "hangoutsMeet" ? meeting_uri.path[1..-1] : raise ArgumentError.new("online_meeting_id required for addOn meeting types")

                    access_code = event.online_meeting_pin
                    entry_points = [EntryPoint.new("video", meeting_url, "#{meeting_uri.host}#{meeting_uri.path}", access_code)]

                    if sip = event.online_meeting_sip
                      entry_points << EntryPoint.new("sip", "sip:#{sip}", sip, access_code)
                    end

                    if phones = event.online_meeting_phones
                      phones.each do |phone|
                        entry_points << EntryPoint.new("phone", "tel:#{phone}", phone, access_code)
                      end
                    end

                    params = event_params(event, calendar_id)
                    params = params.merge({
                      conference: {
                        conferenceId:       meeting_id,
                        conferenceSolution: {
                          key:  {type: meeting_type},
                          name: event.online_meeting_provider,
                        },
                        entryPoints: entry_points,
                      },
                    })
                    calendar(user_id).create(**params)
                  elsif conference_type = @conference_type
                    params = event_params(event, calendar_id)
                    params = params.merge(
                      conference: {
                        createRequest: {
                          requestId:             UUID.random.to_s,
                          conferenceSolutionKey: {
                            type: conference_type,
                          },
                        },
                      }
                    )
                    calendar(user_id).create(**params)
                  else
                    params = event_params(event, calendar_id)
                    calendar(user_id).create(**params)
                  end
      new_event ? new_event.to_place_calendar : nil
    rescue ex : ::Google::Exception
      handle_google_exception(ex)
    end

    def update_event(user_id : String, event : Event, calendar_id : String? = nil, **options) : Event?
      calendar_id ||= "primary"
      params = event_params(event, calendar_id).merge(event_id: event.id)
      updated_event = calendar(user_id).update(**params)
      updated_event ? updated_event.to_place_calendar : nil
    rescue ex : ::Google::Exception
      handle_google_exception(ex)
    end

    def delete_event(user_id : String, id : String, calendar_id : String? = nil, **options) : Bool
      calendar_id ||= "primary"
      notify_option = options[:notify]? ? ::Google::UpdateGuests::All : ::Google::UpdateGuests::None
      if calendar(user_id).delete(id, calendar_id, notify_option)
        true
      else
        false
      end
    rescue ex : ::Google::Exception
      handle_google_exception(ex)
    end

    def decline_event(user_id : String, id : String, calendar_id : String? = nil, notify : Bool = true, comment : String? = nil, **options) : Bool
      calendar_id ||= "primary"
      notify_option = notify ? ::Google::UpdateGuests::All : ::Google::UpdateGuests::None
      calendar(user_id).decline(id, calendar_id, notify_option, comment)
    rescue ex : ::Google::Exception
      handle_google_exception(ex)
    end

    def batch(user_id : String, requests : Indexable(HTTP::Request)) : Hash(HTTP::Request, HTTP::Client::Response)
      calendar(user_id).batch(requests)
    rescue ex : ::Google::Exception
      handle_google_exception(ex)
    end

    def directory : ::Google::Directory
      @directory ||= ::Google::Directory.new(auth: auth, domain: @domain)
    end

    def calendar(sub = @sub)
      ::Google::Calendar.new(auth: auth(sub))
    end

    private def handle_google_exception(ex : ::Google::Exception)
      raise PlaceCalendar::Exception.new(ex.http_status, ex.http_body, ex.message)
    end

    private def drive_files(sub = @sub)
      ::Google::Files.new(auth: auth(sub))
    end

    private def event_params(event, calendar_id)
      params = {
        event_start:                 event.event_start,
        event_end:                   event.event_end || Time.local + 1.hour,
        calendar_id:                 calendar_id ? calendar_id : "primary",
        attendees:                   event.attendees.map { |e| e.response_status ? {email: e.email, responseStatus: e.response_status} : {email: e.email} },
        guests_can_see_other_guests: !event.hide_attendees?,
        all_day:                     event.all_day?,
        visibility:                  event.private? ? ::Google::Visibility::Private : ::Google::Visibility::Default,
        summary:                     event.title,
        description:                 event.body,
        location:                    event.location,
        recurrence:                  nil,
        extended_properties:         event.extended_properties,
      }
      if e_recurrence = event.recurrence
        params = params.merge(recurrence: PlaceCalendar::Google.recurrence_to_google(e_recurrence))
      end
      params
    end

    def list_attachments(user_id : String, event_id : String, calendar_id : String? = nil, **options) : Array(Attachment)
      calendar_id ||= "primary"
      attachments = [] of Attachment

      if event = calendar(user_id).event(event_id, calendar_id)
        attachments = event.attachments.map { |a| create_place_calendar_attachment(user_id, a) }
      end

      attachments
    rescue ex : ::Google::Exception
      handle_google_exception(ex)
    end

    def get_attachment(user_id : String, event_id : String, id : String, calendar_id : String? = nil, **options) : Attachment?
      calendar_id ||= "primary"
      if attachments = list_attachments(user_id, event_id, calendar_id)
        attachments.find(&.id.==(id))
      else
        nil
      end
    rescue ex : ::Google::Exception
      handle_google_exception(ex)
    end

    def create_attachment(user_id : String, event_id : String, attachment : Attachment, calendar_id : String? = nil, **options) : Attachment?
      calendar_id ||= "primary"
      file = drive_files(user_id).create(name: attachment.name, content_bytes: attachment.content_bytes, content_type: extract_mime_type(attachment.name).not_nil!)

      if file
        metadata = drive_files(user_id).file(file.id.as(String))
        calendar(user_id).update(
          event_id: event_id,
          calendar_id: calendar_id,
          attachments: [::Google::Calendar::Attachment.new(file_id: metadata.id, file_url: metadata.link)]
        )

        attachments = list_attachments(user_id, event_id, calendar_id)
        attachments.find(&.id.==(file.id))
      else
        nil
      end
    rescue ex : ::Google::Exception
      handle_google_exception(ex)
    end

    def delete_attachment(id : String, user_id : String, event_id : String, calendar_id : String? = nil, **options) : Bool
      calendar_id ||= "primary"
      event = calendar(user_id).event(event_id, calendar_id)

      if !event.nil?
        if calendar(user_id).update(
             event_id: event_id,
             calendar_id: calendar_id,
             attachments: event.attachments.reject!(&.file_id.==(id))
           )
          true
        else
          false
        end
      else
        false
      end
    rescue ex : ::Google::Exception
      handle_google_exception(ex)
    end

    def get_availability(user_id : String, calendars : Array(String), starts_at : Time, ends_at : Time, **options) : Array(AvailabilitySchedule)
      # Max is 50 so we need to batch if we're above this
      if calendars.size > 50
        requests = Array(HTTP::Request).new((calendars.size / 50).round(:to_positive).to_i)
        client = calendar(user_id)
        calendars.in_groups_of(50) do |cals|
          requests << client.availability_request(cals.compact, starts_at, ends_at)
        end
        client.batch(requests).values.flat_map { |response| client.availability(response).map(&.to_place_calendar) }
      elsif schedule = calendar(user_id).availability(calendars, starts_at, ends_at)
        schedule.map(&.to_place_calendar)
      else
        [] of AvailabilitySchedule
      end
    rescue ex : ::Google::Exception
      handle_google_exception(ex)
    end

    private def create_place_calendar_attachment(user_id : String, attachment : ::Google::Calendar::Attachment) : PlaceCalendar::Attachment
      metadata = drive_files(user_id).file(attachment.file_id.as(String))
      file = drive_files(user_id).download_file(attachment.file_id.as(String))

      PlaceCalendar::Attachment.new(
        id: metadata.id,
        content_bytes: file,
        content_type: extract_mime_type(metadata.name),
        name: metadata.name,
      )
    end

    private def extract_mime_type(filename : String?)
      if match = /(.\w+)$/.match(filename)
        MIME.from_extension?(match[0])
      else
        "text/plain"
      end
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
      email = EMail::Message.new
      email.from from
      to_array(to).each { |address| email.to address }
      to_array(cc).each { |address| email.cc address }
      to_array(bcc).each { |address| email.bcc address }
      email.subject subject
      email.message message_plaintext.as(String) if message_plaintext
      email.message_html message_html.as(String) if message_html

      {resource_attachments, attachments}.map(&.each).each.flatten.each do |attachment|
        # Base64 decode to memory, then attach to email
        attachment_io = IO::Memory.new
        Base64.decode(attachment[:content], attachment_io)
        attachment_io.rewind

        case attachment
        in EmailAttachment
          email.attach(io: attachment_io, file_name: attachment[:file_name])
        in ResourceAttachment
          email.message_resource(io: attachment_io, file_name: attachment[:file_name], cid: attachment[:content_id])
        end
      end

      ::Google::Gmail::Messages.new(auth: auth(from)).send(from, email.to_s)
    end

    def self.recurrence_to_google(recurrence)
      interval = recurrence.interval
      pattern = recurrence.pattern
      days_of_week = recurrence.days_of_week

      formatted_until_date = recurrence.range_end.to_rfc3339.gsub("-", "").gsub(":", "").split(".").first
      until_date = "#{formatted_until_date}"
      case pattern
      when "daily"
        ["RRULE:FREQ=#{pattern.upcase};INTERVAL=#{interval};UNTIL=#{until_date}"]
      when "weekly"
        ["RRULE:FREQ=#{pattern.upcase};INTERVAL=#{interval};BYDAY=#{days_of_week.map(&.upcase[0..1]).join(",")};UNTIL=#{until_date}"]
      when "monthly"
        ["RRULE:FREQ=#{pattern.upcase};INTERVAL=#{interval};BYDAY=1#{days_of_week.first.upcase[0..1]};UNTIL=#{until_date}"]
      end
    end

    def self.recurrence_from_google(recurrence_rule, event)
      rule_parts = recurrence_rule.first.split(";")

      timezone = event.start.time_zone
      location = timezone ? Time::Location.load(timezone) : Time::Location.load("UTC")
      PlaceCalendar::Recurrence.new(range_start: event.start.time.at_beginning_of_day.in(location),
        range_end: google_range_end(rule_parts, event),
        interval: google_interval(rule_parts),
        pattern: google_pattern(rule_parts),
        days_of_week: google_days_of_week(rule_parts),
      )
    end

    private def self.google_pattern(rule_parts)
      pattern_part = rule_parts.find! do |parts|
        parts.includes?("RRULE:FREQ")
      end

      pattern_part.split("=").last.downcase
    end

    private def self.google_interval(rule_parts)
      interval_part = rule_parts.find! do |parts|
        parts.includes?("INTERVAL")
      end

      interval_part.split("=").last.to_i
    end

    private def self.google_range_end(rule_parts, event)
      range_end_part = rule_parts.find! do |parts|
        parts.includes?("UNTIL")
      end
      until_date = range_end_part.gsub("Z", "").split("=").last

      timezone = event.start.time_zone
      location = timezone ? Time::Location.load(timezone) : Time::Location.load("UTC")

      Time.parse(until_date, "%Y%m%dT%H%M%S", location)
    end

    private def self.google_days_of_week(rule_parts)
      byday_part = rule_parts.find do |parts|
        parts.includes?("BYDAY")
      end

      return [] of String unless byday_part

      days = byday_part.split("=").last
      days.split(",").compact_map do |byday|
        case byday.strip.upcase
        when "SU", "1SU"
          "sunday"
        when "MO", "1MO"
          "monday"
        when "TU", "1TU"
          "tuesday"
        when "WE", "1WE"
          "wednesday"
        when "TH", "1TH"
          "thursday"
        when "FR", "1FR"
          "friday"
        when "SA", "1SA"
          "saturday"
        end
      end
    end
  end
end

class Google::Directory::User
  def to_place_calendar
    user_name = @name.full_name || "#{@name.given_name} #{@name.family_name}"

    if phones = @phones
      preference = phones.select(&.primary)

      {"work_mobile", "mobile", "work", "assistant"}.each do |type|
        break unless preference.empty?
        preference.concat phones.select(&.type.==(type))
      end

      phone = preference.first?.try(&.value) || phones.first?.try(&.value) || @recovery_phone
    end

    if orgs = @organizations
      preferred_org = orgs.select(&.primary)
      preferred_org = orgs if preferred_org.empty?
      if org = preferred_org.first?
        department = org.department
        title = org.title
      end
    end

    if accounts = @posix_accounts
      preferred_account = accounts.select(&.primary)
      preferred_account = accounts if preferred_account.empty?
      account = preferred_account.first?.try &.username
    end

    PlaceCalendar::User.new(
      id: self.id,
      name: user_name,
      email: self.primary_email,
      phone: phone,
      department: department,
      title: title,
      photo: @thumbnail_photo_url,
      username: account,
      source: self.to_json
    )
  end
end

class Google::Calendar::ListEntry
  CALENDAR_WRITABLE = {"writer", "owner"}

  def to_place_calendar
    PlaceCalendar::Calendar.new(
      id: @id,
      summary: @summary_main,
      source: self.to_json,
      primary: !!@primary,
      can_edit: @access_role.in?(CALENDAR_WRITABLE)
    )
  end
end

class Google::Calendar::CalendarAvailability
  def to_place_calendar
    PlaceCalendar::AvailabilitySchedule.new(
      @calendar,
      @availability.map(&.to_place_calendar)
    )
  end
end

class Google::Calendar::AvailabilityStatus
  def to_place_calendar
    PlaceCalendar::Availability.new(
      @status == "free" ? PlaceCalendar::AvailabilityStatus::Free : PlaceCalendar::AvailabilityStatus::Busy,
      @starts_at.time,
      @ends_at.time,
      @starts_at.time_zone || @starts_at.time.location.to_s
    )
  end
end

class Google::Calendar::Event
  NOP_G_ATTEND = [] of ::Google::Calendar::Attendee

  def to_place_calendar
    event_start = (@start.date_time || @start.date).not_nil!
    event_end = @end.try { |time| (time.date_time || time.date) }

    timezone = @start.time_zone || "UTC"
    tz_location = if timezone.starts_with?("GMT")
                    offset_str = timezone.split("GMT").last
                    Time.parse!(offset_str, "%:z").location
                  else
                    Time::Location.load(timezone)
                  end
    event_start = event_start.in(tz_location)

    if event_end
      event_end = event_end.in(tz_location)
    end

    # Grab the list of external visitors
    attendees = (@attendees || NOP_G_ATTEND).map do |attendee|
      email = attendee.email.downcase

      PlaceCalendar::Event::Attendee.new(name: attendee.display_name || email,
        email: email,
        response_status: attendee.response_status,
        resource: attendee.resource,
        organizer: attendee.organizer)
    end

    hide_attendees = @guests_can_see_other_guests.nil? ? false : !@guests_can_see_other_guests

    recurrence = if rec = @recurrence
                   PlaceCalendar::Google.recurrence_from_google(rec, self)
                 end

    # obtain online meeting details
    pins = [] of String?
    if url = online_meeting_url
      pins << url[1]
    end
    if sip = online_meeting_sip
      pins << sip[1]
    end
    phones = online_meeting_phones.try &.map do |phone|
      pins << phone[1]
      phone[0]
    end

    ext_prop = (@extended_properties.try(&.[]?("shared")) || @extended_properties.try(&.[]?("private"))).try &.transform_values(&.as(String | Nil))

    PlaceCalendar::Event.new(
      id: @id,
      host: @organizer.try &.email,
      event_start: event_start,
      event_end: event_end,
      title: @summary,
      body: @description,
      location: @location,
      attendees: attendees,
      hide_attendees: hide_attendees,
      private: @visibility.in?({"private", "confidential"}),
      all_day: !!@start.date,
      source: self.to_json,
      timezone: timezone,
      recurrence: recurrence,
      status: @status,
      creator: @creator.try &.email,
      recurring_event_id: @recurring_event_id,
      ical_uid: @ical_uid,
      online_meeting_provider: online_meeting_provider,
      online_meeting_phones: phones,
      online_meeting_url: url.try &.[](0),
      online_meeting_sip: sip.try &.[](0),
      online_meeting_pin: pins.compact.first?,
      online_meeting_id: online_meeting_id,
      extended_properties: ext_prop,
      created: @created,
      updated: @updated
    )
  end
end

class Google::Directory::Member
  def to_place_member
    PlaceCalendar::Member.new(@id, @email, @email, nil, self.to_json)
  end
end

class Google::Directory::Group
  def to_place_group
    PlaceCalendar::Group.new(@id, @name, @email, @description, self.to_json)
  end
end

struct Google::Calendar::Notification::Receipt
  def to_place_subscription(user_id : String, resource : String, notification_url : String)
    if expires = expiration
      expires_time = Time.unix_ms(expires)
    end
    PlaceCalendar::Subscription.new(@id.as(String), @resource_id, resource, notification_url, expires_time, @token, user_id, source: self.to_json)
  end
end
