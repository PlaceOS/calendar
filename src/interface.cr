module PlaceCalendar
  abstract class Interface
    abstract def list_users(query : String? = nil, limit : Int32? = nil, **options) : Array(User)
    abstract def get_user(id : String, **options) : User?
    abstract def list_calendars(mail : String, **options) : Array(Calendar)
    abstract def get_calendar(id : String, **options) : Calendar
    abstract def list_events(user_id : String, calendar_id : String? = nil, **options) : Array(Event)
    abstract def get_event(user_id : String, id : String, **options) : Event?
    abstract def create_event(user_id : String, event : Event, calendar_id : String? = nil, **options) : Event?
    abstract def update_event(user_id : String, event : Event, calendar_id : String? = nil, **options) : Event?
    abstract def delete_event(user_id : String, id : String, **options) : Bool
    abstract def list_attachments(user_id : String, event_id : String, calendar_id : String? = nil, **options) : Array(Attachment)
    abstract def get_attachment(user_id : String, event_id : String, id : String, calendar_id : String? = nil, **options) : Attachment?
    abstract def create_attachment(user_id : String, event_id : String, attachment : Attachment, calendar_id : String? = nil, **options) : Attachment?
    abstract def delete_attachment(id : String, user_id : String, event_id : String, calendar_id : String? = nil, **options) : Bool
    abstract def get_availability(user_id : String, calendars : Array(String), starts_at : Time, ends_at : Time) : Array(AvailabilitySchedule)
  end
end
