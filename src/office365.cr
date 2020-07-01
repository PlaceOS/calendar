require "office365"

module PlaceCalendar
  class Office365 < Interface
    def initialize(@tenant : String, @client_id : String, @client_secret : String)
    end

    def client : ::Office365::Client
      @client ||= ::Office365::Client.new(@tenant, @client_id, @client_secret)
    end

    def list_users(**options)
      if users = client.list_users(**options)
        users.value.map { |u| u.to_place_calendar }
      else
        [] of User
      end
    rescue ex : ::Office365::Exception
      handle_office365_exception(ex)
    end

    def get_user(id : String, **options)
      if user = client.get_user(**options.merge(id: id))
        user.to_place_calendar
      end
    rescue ex : ::Office365::Exception
      handle_office365_exception(ex)
    end

    def list_calendars(mail : String, **options)
      if calendars = client.list_calendars(**options.merge(mailbox: mail))
        calendars.value.map { |c| c.to_place_calendar }
      else
        [] of Calendar
      end
    rescue ex : ::Office365::Exception
      handle_office365_exception(ex)
    end

    def list_events(
      user_id : String,
      calendar_id : String? = nil,
      period_start : Time = Time.local.at_beginning_of_day,
      period_end : Time? = nil,
      **options
    )
      if events = client.list_events(**options.merge(mailbox: user_id, calendar_id: calendar_id, period_start: period_start, period_end: period_end))
        events.value.map { |e| e.to_place_calendar }
      else
        [] of Event
      end
    rescue ex : ::Office365::Exception
      handle_office365_exception(ex)
    end

    def create_event(user_id : String, event : Event, calendar_id : String? = nil, **options)
      params = event_params(event).merge(mailbox: user_id, calendar_id: calendar_id)
      new_event = client.create_event(**params)

      new_event.to_place_calendar
    rescue ex : ::Office365::Exception
      handle_office365_exception(ex)
    end

    def get_event(user_id : String, id : String, **options)
      if event = client.get_event(**options.merge(id: id, mailbox: user_id))
        event.to_place_calendar
      end
    rescue ex : ::Office365::Exception
      handle_office365_exception(ex)
    end

    def update_event(user_id : String, event : Event, calendar_id : String? = nil, **options) : Event?
      o365_event = ::Office365::Event.new(**event_params(event))

      if updated_event = client.update_event(**options.merge(mailbox: user_id, calendar_id: calendar_id, event: o365_event))
        updated_event.to_place_calendar
      end
    rescue ex : ::Office365::Exception
      handle_office365_exception(ex)
    end

    def delete_event(user_id : String, id : String, **options) : Bool
      client.delete_event(**options.merge(mailbox: user_id, id: id)) || false
    rescue ex : ::Office365::Exception
      handle_office365_exception(ex)
    end

    private def event_params(event)
      attendees = event.attendees.map do |a|
        ::Office365::Attendee.new(
          email: ::Office365::EmailAddress.new(address: a[:email], name: a[:name])
        )
      end

      sensitivity = event.private? ? ::Office365::Sensitivity::Normal : ::Office365::Sensitivity::Private

      params = {
        id:          event.id,
        organizer:   event.host,
        starts_at:   event.event_start || Time.local,
        ends_at:     event.event_end,
        subject:     event.title || "",
        description: event.description,
        all_day:     event.all_day?,
        sensitivity: sensitivity,
        attendees:   attendees,
        location:    event.location.try(&.text),
        recurrence:  nil,
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

    def list_attachments(user_id : String, event_id : String, calendar_id : String? = nil, **options)
      if attachments = client.list_attachments(**options.merge(mailbox: user_id, event_id: event_id, calendar_id: calendar_id))
        attachments.value.map { |a| a.to_placecalendar }
      else
        [] of Attachment
      end
    rescue ex : ::Office365::Exception
      handle_office365_exception(ex)
    end

    def get_attachment(user_id : String, event_id : String, id : String, calendar_id : String? = nil, **options)
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

    def get_availability(user_id : String, calendars : Array(String), starts_at : Time, ends_at : Time)
      if availability = client.get_availability(user_id, calendars, starts_at, ends_at)
        availability.map { |a| a.to_placecalendar }
      else
        [] of AvailabilitySchedule
      end
    rescue ex : ::Office365::Exception
      handle_office365_exception(ex)
    end

    private def attachment_params(attachment)
      {
        name:          attachment.name,
        content_bytes: attachment.content_bytes,
      }
    end

    private def handle_office365_exception(ex : ::Office365::Exception)
      raise PlaceCalendar::Exception.new(ex.http_status, ex.http_body, ex.message)
    end
  end
end

class Office365::User
  def to_place_calendar
    PlaceCalendar::User.new(id: @id, name: @display_name, email: @mail, source: self.to_json)
  end
end

class Office365::Calendar
  def to_place_calendar
    PlaceCalendar::Calendar.new(id: @id, name: @name, source: self.to_json)
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

    attendees = @attendees
      .select { |a| a.type != AttendeeType::Resource }
      .map { |a| {name: a.email_address.name, email: a.email_address.address} }

    source_location = @location || @locations.try &.first
    location = if source_location
                 PlaceCalendar::Location.new(text: source_location.display_name)
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

    PlaceCalendar::Event.new(
      id: @id,
      host: @organizer.try &.email_address.try &.address,
      event_start: event_start,
      event_end: event_end,
      title: @subject,
      description: @body.try &.content,
      attendees: attendees,
      private: is_private?,
      all_day: all_day?,
      location: location,
      source: self.to_json,
      timezone: event_start.location.to_s,
      recurrence: recurrence
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
