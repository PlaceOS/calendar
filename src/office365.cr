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
      if events = client.list_events(**options.merge(mailbox: user_id, calendar_id: calendar_id))
        events.value.map { |e| e.to_place_calendar }
      else
        [] of Event
      end
    end

    def create_event(user_id : String, event : Event, calendar_id : String? = nil, **options)
      placeholder = ::Office365::Event.from_place_calendar(event)

      new_event = client.create_event(
        mailbox: user_id,
        calendar_id: calendar_id,
        starts_at: event.event_start || Time.local,
        ends_at: event.event_end,
        subject: event.title,
        description: placeholder.description,
        attendees: placeholder.attendees,
        location: "",
        all_day: placeholder.all_day?,
        sensitivity: placeholder.sensitivity,
      )

      new_event.to_place_calendar
    end

    def get_event(user_id : String, id : String, **options)
      if event = client.get_event(**options.merge(id: id, mailbox: user_id))
        event.to_place_calendar
      end
    end

    def update_event(user_id : String, event : Event, calendar_id : String? = nil, **options) : Event?
      o365_event = ::Office365::Event.from_place_calendar(event)
      o365_event.populate_from_place_calendar(event)

      if updated_event = client.update_event(**options.merge(mailbox: user_id, calendar_id: calendar_id, event: o365_event))
        updated_event.to_place_calendar
      end
    end

    def delete_event(user_id : String, id : String, **options) : Bool
      client.delete_event(**options.merge(mailbox: user_id, id: id)) || false
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

class Office365::DateTimeTimeZone
  def to_time
    @date_time.in(Time::Location.load(@time_zone))
  end
end

class Office365::Event
  def to_place_calendar
    PlaceCalendar::Event.new(
      id: @id,
      host: @organizer.try &.email_address.try &.address,
      event_start: @starts_at.try &.to_time,
      event_end: @ends_at.try &.to_time,
      title: @subject,
      description: @body.try &.content,
      attendees: @attendees.map { |a| {name: a.email_address.name, email: a.email_address.address} if a.type != AttendeeType::Resource }.compact,
      private: is_private?,
      all_day: all_day?,
      source: self.to_json
    )
  end

  def populate_from_place_calendar(event : PlaceCalendar::Event)
    @starts_at = ::Office365::DateTimeTimeZone.new(event.event_start || Time.local)
    ends_at = event.event_end
    if !ends_at.nil?
      @ends_at = ::Office365::DateTimeTimeZone.new(ends_at)
    end
    @subject = event.title
    description = event.description
    @all_day = event.all_day?
    @sensitivity = event.private? ? ::Office365::Sensitivity::Normal : ::Office365::Sensitivity::Private
    @attendees = event.attendees.map do |a|
      ::Office365::Attendee.new(
        email: ::Office365::EmailAddress.new(address: a[:email], name: a[:name])
      )
    end
  end

  def self.from_place_calendar(event : PlaceCalendar::Event)
    new_event = event.source.nil? ? new : ::Office365::Event.from_json(event.source || "")
    new_event.populate_from_place_calendar(event)

    new_event
  end
end
