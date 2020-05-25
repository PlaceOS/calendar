module PlaceCalendar
  class Interface
    def initialize(**credentials)
    end

    def list_users(**options) : Array(User)
      return [] of User
    end

    # do we need this 
    def get_user(id : String?, **options) : User?
    end

    def list_calendars(mail : String, **options) : Array(Calendar)
      return [] of Calendar
    end

    def get_calendar(id : String, **options) : Calendar
    end

    def list_events(user_id : String, calendar_id : String? = nil, **options) : Array(Event)
      return [] of Event
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

    def list_attachments(user_id : String, event_id : String, calendar_id : String? = nil, **options) : Array(Attachment)
      return [] of Attachment
    end

    def get_attachment(user_id : String, event_id : String, id : String, calendar_id : String? = nil, **options) : Attachment?
    end

    def create_attachment(user_id : String, event_id : String, attachment : Attachment, calendar_id : String? = nil, **options) : Attachment?
    end

    def delete_attachment(id : String, user_id : String, event_id : String, calendar_id : String? = nil, **options) : Bool
      false
    end
  end
end
