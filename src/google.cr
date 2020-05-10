module PlaceCalendar
  class Google < Interface
    def initialize(
      @scopes : String | Array(String),
      @file_path : String,
      @domain : String,
      @issuer : String? = nil,
      @signing_key : String? = nil,
      @sub : String = "",
      @user_agent : String = "Switch"
    )
    end

    def auth : ::Google::FileAuth
      @auth ||= ::Google::FileAuth.new(file_path: @file_path, scopes: @scopes, sub: @sub, user_agent: @user_agent)
    end

    def list_users(**options) : Array(User)
      if users = directory.users
        # TODO: Deal with pagination
        users.users.map { |u| u.to_place_calendar }
      else
        return [] of User
      end
    end

    # do we need this
    def get_user(id : String?, **options) : User?
    end

    def list_calendars(mail : String, **options) : Array(Calendar)
      if calendars = calendar.calendar_list
        calendars.map { |c| c.to_place_calendar }
      else
        return [] of Calendar
      end
    end

    def get_calendar(id : String, **options) : Calendar
    end

    def list_events(user_id : String, calendar_id : String? = nil, **options) : Array(Event)
      if events = calendar.events
        events.items.map { |u| u.to_place_calendar }
      else
        return [] of Event
      end
    end

    def get_event(user_id : String, id : String, **options) : Event?
    end

    def create_event(user_id : String, event : Event, calendar_id : String? = nil, **options) : Event?
    end

    def update_event(user_id : String, event : Event, calendar_id : String? = nil, **options) : Event?
    end

    def delete_event(user_id : String, id : String, **options) : Bool
      false
    end

    def directory : ::Google::Directory
      @directory ||= ::Google::Directory.new(auth: auth, domain: @domain)
    end

    def calendar
      @calendar ||= ::Google::Calendar.new(auth: auth)
    end
  end
end

class Google::Directory::User
  def to_place_calendar
    PlaceCalendar::User.new(
      id: self.id,
      name: "", # TODO: Update google shard to extract name
      email: self.primaryEmail,
      source: self.to_json
    )
  end
end

class Google::Calendar::ListEntry
  def to_place_calendar
    PlaceCalendar::Calendar.new(id: @id, name: @summaryMain, source: self.to_json)
  end
end

class Google::Calendar::Event
  NOP_G_ATTEND = [] of ::Google::Calendar::Attendee

  def to_place_calendar
    event_start = (@start.dateTime || @start.date).not_nil!
    event_end = @end.try { |time| (time.dateTime || time.date) }

    # Grab the list of external visitors
    attendees = (@attendees || NOP_G_ATTEND).map do |attendee|
      email = attendee.email.downcase

      {
        name:            attendee.displayName || email,
        email:           email,
        # TODO: Stephen includes some extra stuff here not included in our spec
        # response_status: attendee.responseStatus,
        # organizer:       attendee.organizer,
        # resource:        attendee.resource,
      }
    end

    PlaceCalendar::Event.new(
      id: @id,
      host: @organizer.try &.email,
      event_start: event_start,
      event_end: event_end,
      title: @summary,
      description: "",
      attendees: attendees,
      private: @visibility.in?({"private", "confidential"}),
      all_day: !!@start.date,
      source: self.to_json
    )
  end
end
