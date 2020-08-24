require "mime"

module PlaceCalendar
  class Google < Interface
    def initialize(
      @file_path : String,
      @scopes : String | Array(String),
      @domain : String,
      @sub : String = "",
      @user_agent : String = "PlaceOS"
    )
      @issuer = ""
      @signing_key = ""
    end

    def initialize(
      @issuer : String,
      @signing_key : String,
      @scopes : String | Array(String),
      @domain : String,
      @sub : String = "",
      @user_agent : String = "PlaceOS"
    )
      @file_path = ""
    end

    def auth(sub = @sub) : ::Google::FileAuth | ::Google::Auth
      if @file_path.empty?
        ::Google::Auth.new(issuer: @issuer, signing_key: @signing_key, scopes: @scopes, sub: sub, user_agent: @user_agent)
      else
        ::Google::FileAuth.new(file_path: @file_path, scopes: @scopes, sub: sub, user_agent: @user_agent)
      end
    rescue ex : ::Google::Exception
      handle_google_exception(ex)
    end

    def list_users(query : String? = nil, limit : Int32? = nil, **options) : Array(User)
      if users = directory.users(query, limit || 500, **options)
        # TODO: Deal with pagination
        users.users.map { |u| u.to_place_calendar }
      else
        [] of User
      end
    rescue ex : ::Google::Exception
      handle_google_exception(ex)
    end

    # do we need this
    def get_user(id : String?, **options) : User?
      if user = directory.lookup(id)
        user.to_place_calendar
      else
        nil
      end
    rescue ex : ::Google::Exception
      handle_google_exception(ex)
    end

    def list_calendars(mail : String, **options) : Array(Calendar)
      if calendars = calendar(mail).calendar_list
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

    def list_events(
      user_id : String,
      calendar_id : String? = nil,
      period_start : Time = Time.local.at_beginning_of_day,
      period_end : Time? = nil,
      **options
    ) : Array(Event)
      # user_id ignored?
      # TODO: how to avoid duplicating default values from the shards
      calendar_id = "primary" if calendar_id.nil?

      if events = calendar(user_id).events(calendar_id, period_start, period_end, **options)
        events.items.map { |e| e.to_place_calendar }
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

    def create_event(user_id : String, event : Event, calendar_id : String? = nil, **options) : Event?
      new_event = calendar(user_id).create(**event_params(event, calendar_id))

      new_event ? new_event.to_place_calendar : nil
    rescue ex : ::Google::Exception
      handle_google_exception(ex)
    end

    def update_event(user_id : String, event : Event, calendar_id : String = "primary", **options) : Event?
      params = event_params(event, calendar_id).merge(event_id: event.id)
      updated_event = calendar(user_id).update(**params)
      updated_event ? updated_event.to_place_calendar : nil
    rescue ex : ::Google::Exception
      handle_google_exception(ex)
    end

    def delete_event(user_id : String, id : String, calendar_id : String = "primary", **options) : Bool
      if calendar(user_id).delete(id, calendar_id)
        true
      else
        false
      end
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
        event_start: event.event_start,
        event_end:   event.event_end || Time.local + 1.hour,
        calendar_id: calendar_id ? calendar_id : "primary",
        attendees:   event.attendees.map { |e| e[:email] },
        all_day:     event.all_day?,
        visibility:  event.private? ? ::Google::Visibility::Private : ::Google::Visibility::Default,
        summary:     event.title,
        description: event.description,
        location:    event.location.try &.text,
        recurrence:  nil,
      }
      if event.recurrence
        e_recurrence = event.recurrence.not_nil!
        params = params.merge(recurrence: PlaceCalendar::Google.recurrence_to_google(e_recurrence))
      end
      params
    end

    def list_attachments(user_id : String, event_id : String, calendar_id : String? = "primary", **options)
      attachments = [] of Attachment

      if event = calendar(user_id).event(event_id, calendar_id)
        attachments = event.attachments.map { |a| create_place_calendar_attachment(user_id, a) }
      end

      attachments
    rescue ex : ::Google::Exception
      handle_google_exception(ex)
    end

    def get_attachment(user_id : String, event_id : String, id : String, calendar_id : String? = "primary", **options)
      if attachments = list_attachments(user_id, event_id, calendar_id)
        attachments.find { |a| a.id == id }
      else
        nil
      end
    rescue ex : ::Google::Exception
      handle_google_exception(ex)
    end

    def create_attachment(user_id : String, event_id : String, attachment : Attachment, calendar_id : String = "primary", **options)
      file = drive_files(user_id).create(name: attachment.name, content_bytes: attachment.content_bytes, content_type: extract_mime_type(attachment.name).not_nil!)

      if !file.nil?
        metadata = drive_files(user_id).file(file.id.not_nil!)
        calendar(user_id).update(
          event_id: event_id,
          calendar_id: calendar_id,
          attachments: [::Google::Calendar::Attachment.new(file_id: metadata.id, file_url: metadata.link)]
        )

        attachments = list_attachments(user_id, event_id, calendar_id)
        attachments.find { |a| a.id == file.id }
      else
        nil
      end
    rescue ex : ::Google::Exception
      handle_google_exception(ex)
    end

    def delete_attachment(id : String, user_id : String, event_id : String, calendar_id : String? = "primary", **options)
      event = calendar(user_id).event(event_id, calendar_id)

      if !event.nil?
        if calendar(user_id).update(
             event_id: event_id,
             calendar_id: calendar_id,
             attachments: event.attachments.reject! { |a| a.file_id == id }
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

    def get_availability(user_id : String, calendars : Array(String), starts_at : Time, ends_at : Time)
      if schedule = calendar(user_id).availability(calendars, starts_at, ends_at)
        schedule.map { |a| a.to_place_calendar }
      else
        [] of AvailabilitySchedule
      end
    rescue ex : ::Google::Exception
      handle_google_exception(ex)
    end

    private def create_place_calendar_attachment(user_id : String, attachment : ::Google::Calendar::Attachment) : PlaceCalendar::Attachment
      metadata = drive_files(user_id).file(attachment.file_id.not_nil!)
      file = drive_files(user_id).download_file(attachment.file_id.not_nil!)

      PlaceCalendar::Attachment.new(
        id: metadata.id,
        content_bytes: file,
        content_type: extract_mime_type(metadata.name),
        name: metadata.name,
      )
    end

    private def extract_mime_type(filename : String?)
      if match = /(.\w+)$/.match(filename)
        MIME.from_extension?(match.not_nil![0])
      else
        "text/plain"
      end
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
        ["RRULE:FREQ=#{pattern.upcase};INTERVAL=#{interval};BYDAY=#{days_of_week.not_nil!.upcase[0..1]};UNTIL=#{until_date}"]
      when "monthly"
        ["RRULE:FREQ=#{pattern.upcase};INTERVAL=#{interval};BYDAY=1#{days_of_week.not_nil!.upcase[0..1]};UNTIL=#{until_date}"]
      end
    end

    def self.recurrence_from_google(recurrence_rule, event)
      rule_parts = recurrence_rule.not_nil!.first.split(";")
      location = event.start.time_zone ? Time::Location.load(event.start.time_zone.not_nil!) : Time::Location.load("UTC")
      PlaceCalendar::Recurrence.new(range_start: event.start.time.at_beginning_of_day.in(location),
        range_end: google_range_end(rule_parts, event),
        interval: google_interval(rule_parts),
        pattern: google_pattern(rule_parts),
        days_of_week: google_days_of_week(rule_parts),
      )
    end

    private def self.google_pattern(rule_parts)
      pattern_part = rule_parts.find do |parts|
        parts.includes?("RRULE:FREQ")
      end.not_nil!

      pattern_part.split("=").last.downcase
    end

    private def self.google_interval(rule_parts)
      interval_part = rule_parts.find do |parts|
        parts.includes?("INTERVAL")
      end.not_nil!

      interval_part.split("=").last.to_i
    end

    private def self.google_range_end(rule_parts, event)
      range_end_part = rule_parts.find do |parts|
        parts.includes?("UNTIL")
      end.not_nil!
      until_date = range_end_part.gsub("Z", "").split("=").last
      location = event.start.time_zone ? Time::Location.load(event.start.time_zone.not_nil!) : Time::Location.load("UTC")

      Time.parse(until_date, "%Y%m%dT%H%M%S", location)
    end

    private def self.google_days_of_week(rule_parts)
      byday_part = rule_parts.find do |parts|
        parts.includes?("BYDAY")
      end

      if byday_part
        byday = byday_part.not_nil!.split("=").last

        case byday
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
    PlaceCalendar::User.new(
      id: self.id,
      name: "", # TODO: Update google shard to extract name
      email: self.primary_email,
      source: self.to_json
    )
  end
end

class Google::Calendar::ListEntry
  def to_place_calendar
    PlaceCalendar::Calendar.new(
      id: @id,
      summary: @summary_main,
      source: self.to_json,
      primary: !!@primary,
    )
  end
end

class Google::Calendar::CalendarAvailability
  def to_place_calendar
    PlaceCalendar::AvailabilitySchedule.new(
      @calendar,
      @availability.map { |a| a.to_place_calendar }
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
    tz_location = Time::Location.load(timezone)
    event_start = event_start.in(tz_location)

    if !event_end.nil?
      event_end = event_end.not_nil!.in(tz_location)
    end

    # Grab the list of external visitors
    attendees = (@attendees || NOP_G_ATTEND).map do |attendee|
      email = attendee.email.downcase

      {
        name:  attendee.display_name || email,
        email: email,
        # TODO: Stephen includes some extra stuff here not included in our spec
        # response_status: attendee.responseStatus,
        # organizer:       attendee.organizer,
        # resource:        attendee.resource,
      }
    end

    recurrence = if @recurrence
                   PlaceCalendar::Google.recurrence_from_google(@recurrence, self)
                 end

    PlaceCalendar::Event.new(
      id: @id,
      host: @organizer.try &.email,
      event_start: event_start,
      event_end: event_end,
      title: @summary,
      description: @description,
      location: @location.nil? ? nil : PlaceCalendar::Location.new(text: @location),
      attendees: attendees,
      private: @visibility.in?({"private", "confidential"}),
      all_day: !!@start.date,
      source: self.to_json,
      timezone: timezone,
      recurrence: recurrence,
      status: @status
    )
  end
end
