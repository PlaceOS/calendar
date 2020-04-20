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
      end
    end

    def list_events(user_id : String, calendar_id : String? = nil)
      if events = client.list_events(**options.merge(mailbox: user_id, calendar_id: calendar_id))
        events.value.map { |e| e.to_place_calendar }
      end
    end

    def create_event(user_id : String, event : Event, calendar_id : String? = nil, **options)
      attendees = [] of ::Office365::Attendee

      event.attendees.each do |a|
        attendees << ::Office365::Attendee.new(
          email: ::Office365::EmailAddress.new(address: a[:email], name: a[:name]),
          type: ::Office365::AttendeeType::Required
        )
      end

      event.locations.each do |a|
        attendees << ::Office365::Attendee.new(
          email: ::Office365::EmailAddress.new(address: a[:email], name: a[:name]),
          type: ::Office365::AttendeeType::Resource
        )
      end

      location = event.locations.first[:name] rescue ""

      client.create_event(
        mailbox: user_id,
        calendar_id: calendar_id,
        starts_at: event.starts_at || Time.local,
        ends_at: event.ends_at || Time.local + 30.minutes,
        subject: event.subject || "",
        description: event.description || "",
        attendees: attendees,
        location: location,
        sensitivity: event.is_private? ? ::Office365::Sensitivity::Normal : ::Office365::Sensitivity::Private,
      )
    end

    def get_event(user_id : String, id : String, **options)
      if event = client.get_event(**options.merge(id: id, mailbox: user_id))
        event.to_place_calendar
      end
    end

    def update_event(user_id : String, event : Event, calendar_id : String? = nil, **options) : Event?
      o365_event = ::Office365::Event.from_json(event.source || "")

      o365_event.starts_at = ::Office365::DateTimeTimeZone.new(event.starts_at || Time.local)
      o365_event.ends_at = ::Office365::DateTimeTimeZone.new(event.ends_at || Time.local + 30.minutes)
      o365_event.subject = event.subject
      o365_event.description = event.description
      o365_event.sensitivity = event.is_private? ? ::Office365::Sensitivity::Normal : ::Office365::Sensitivity::Private

      attendees = [] of ::Office365::Attendee
      event.attendees.each do |a|
        attendees << ::Office365::Attendee.new(
          email: ::Office365::EmailAddress.new(address: a[:email], name: a[:name]),
          type: ::Office365::AttendeeType::Required
        )
      end
      event.locations.each do |a|
        attendees << ::Office365::Attendee.new(
          email: ::Office365::EmailAddress.new(address: a[:email], name: a[:name]),
          type: ::Office365::AttendeeType::Resource
        )
      end
      o365_event.attendees = attendees

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
      starts_at: @starts_at.try &.to_time,
      ends_at: @ends_at.try &.to_time,
      subject: @subject,
      description: @body.try &.content,
      attendees: @attendees.map { |a| {name: a.email_address.name, email: a.email_address.address} if a.type != AttendeeType::Resource }.compact,
      locations: @attendees.map { |a| {name: a.email_address.name, email: a.email_address.address} if a.type == AttendeeType::Resource }.compact,
      is_private: is_private?,
      source: self.to_json
    )
  end
end
