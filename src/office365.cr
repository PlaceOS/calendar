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
    end

    def get_user(id : String, **options)
      if user = client.get_user(**options.merge(id: id))
        user.to_place_calendar
      end
    end

    def list_calendars(mail : String, **options)
      if calendars = client.list_calendars(**options.merge(mailbox: mail))
        calendars.value.map { |c| c.to_place_calendar }
      else
        [] of Calendar
      end
    end

    def list_events(user_id : String, calendar_id : String? = nil, **options)
      # TODO: need the period_start and period_end stuff that google has here
      if events = client.list_events(**options.merge(mailbox: user_id, calendar_id: calendar_id))
        events.value.map { |e| e.to_place_calendar }
      else
        [] of Event
      end
    end

    def create_event(user_id : String, event : Event, calendar_id : String? = nil, **options)
      params = event_params(event).merge(mailbox: user_id, calendar_id: calendar_id)
      new_event = client.create_event(**params)

      new_event.to_place_calendar
    end

    def get_event(user_id : String, id : String, **options)
      if event = client.get_event(**options.merge(id: id, mailbox: user_id))
        event.to_place_calendar
      end
    end

    def update_event(user_id : String, event : Event, calendar_id : String? = nil, **options) : Event?
      o365_event = ::Office365::Event.new(**event_params(event))

      if updated_event = client.update_event(**options.merge(mailbox: user_id, calendar_id: calendar_id, event: o365_event))
        updated_event.to_place_calendar
      end
    end

    def delete_event(user_id : String, id : String, **options) : Bool
      client.delete_event(**options.merge(mailbox: user_id, id: id)) || false
    end

    private def event_params(event)
      attendees = event.attendees.map do |a|
        ::Office365::Attendee.new(
          email: ::Office365::EmailAddress.new(address: a[:email], name: a[:name])
        )
      end

      sensitivity = event.private? ? ::Office365::Sensitivity::Normal : ::Office365::Sensitivity::Private

      {
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
      }
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
    event_end   = @ends_at

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
      timezone: event_start.location.to_s
    )
  end
end
