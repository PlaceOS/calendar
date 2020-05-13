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

    def auth(sub = @sub) : ::Google::FileAuth
      ::Google::FileAuth.new(file_path: @file_path, scopes: @scopes, sub: sub, user_agent: @user_agent)
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
      if calendars = calendar(mail).calendar_list
        calendars.map { |c| c.to_place_calendar }
      else
        return [] of Calendar
      end
    end

    def get_calendar(id : String, **options) : Calendar
    end

    def list_events(
      user_id : String,
      calendar_id : String? = nil,
      period_start : Time = Time.local,
      period_end : Time? = nil,
      **options
    ) : Array(Event)
      # user_id ignored?
      # TODO: how to avoid duplicating default values from the shards
      calendar_id = "primary" if calendar_id.nil?

      if events = calendar(user_id).events(calendar_id, period_start, period_end, **options)
        events.items.map { |e| e.to_place_calendar }
      else
        return [] of Event
      end
    end

    def get_event(user_id : String, id : String, calendar_id : String = "primary", **options) : Event?
      if event = calendar(user_id).event(id, calendar_id)
        event.to_place_calendar
      else
        nil
      end
    end

    def create_event(user_id : String, event : Event, calendar_id : String? = nil, **options) : Event?
      new_event = calendar(user_id).create(event_params(event, calendar_id))

      new_event ? new_event.to_place_calendar : nil
    end

    def update_event(user_id : String, event : Event, calendar_id : String = "primary", **options) : Event?
      params = event_params(event, calendar_id).merge(event_id: event.id)
      updated_event = calendar(user_id).update(**params)
      updated_event ? updated_event.to_place_calendar : nil
    end

    def delete_event(user_id : String, id : String, calendar_id : String = "primary", **options) : Bool
      if calendar(user_id).delete(id, calendar_id)
        true
      else
        false
      end
    end

    def directory : ::Google::Directory
      @directory ||= ::Google::Directory.new(auth: auth, domain: @domain)
    end

    def calendar(sub = @sub)
      @calendar ||= ::Google::Calendar.new(auth: auth)
    end

    private def event_params(event, calendar_id)
      {
        event_start: event.event_start,
        event_end:   event.event_end || Time.local + 1.hour,
        calendar_id: calendar_id ? calendar_id : "primary",
        attendees:   event.attendees.map {|e| e[:email] },
        all_day:     event.all_day?,
        visibility:  event.private? ? ::Google::Visibility::Private : ::Google::Visibility::Default,
        summary:     event.title,
        description: event.description
      }
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
      description: @description,
      attendees: attendees,
      private: @visibility.in?({"private", "confidential"}),
      all_day: !!@start.date,
      source: self.to_json
    )
  end

end
