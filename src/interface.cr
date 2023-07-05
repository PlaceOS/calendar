module PlaceCalendar
  abstract class Interface
    abstract def list_users(query : String? = nil, limit : Int32? = nil, **options) : Array(User)
    abstract def get_user(id : String, **options) : User?
    abstract def get_user_by_email(email : String, **options) : User?
    abstract def list_calendars(mail : String, **options) : Array(Calendar)
    abstract def get_calendar(id : String, **options) : Calendar

    abstract def list_events_request(user_id : String, calendar_id : String? = nil, **options) : HTTP::Request
    abstract def list_events(user_id : String, calendar_id : String? = nil, **options) : Array(Event)
    abstract def list_events(user_id : String, response : HTTP::Client::Response) : Array(Event)

    abstract def get_event(user_id : String, id : String, **options) : Event?
    abstract def create_event(user_id : String, event : Event, calendar_id : String? = nil, **options) : Event?
    abstract def update_event(user_id : String, event : Event, calendar_id : String? = nil, **options) : Event?
    abstract def delete_event(user_id : String, id : String, calendar_id : String? = nil, **options) : Bool
    abstract def accept_event(user_id : String, id : String, calendar_id : String? = nil, notify : Bool = true, comment : String? = nil, **options) : Bool
    abstract def decline_event(user_id : String, id : String, calendar_id : String? = nil, notify : Bool = true, comment : String? = nil, **options) : Bool
    abstract def list_attachments(user_id : String, event_id : String, calendar_id : String? = nil, **options) : Array(Attachment)
    abstract def get_attachment(user_id : String, event_id : String, id : String, calendar_id : String? = nil, **options) : Attachment?
    abstract def create_attachment(user_id : String, event_id : String, attachment : Attachment, calendar_id : String? = nil, **options) : Attachment?
    abstract def delete_attachment(id : String, user_id : String, event_id : String, calendar_id : String? = nil, **options) : Bool
    abstract def get_availability(user_id : String, calendars : Array(String), starts_at : Time, ends_at : Time, **options) : Array(AvailabilitySchedule)
    abstract def batch(user_id : String, requests : Indexable(HTTP::Request)) : Hash(HTTP::Request, HTTP::Client::Response)

    abstract def get_groups(user_id : String, **options) : Array(Group)
    abstract def get_members(group_id : String, **options) : Array(Member)

    abstract def access_token(user_id : String? = nil) : NamedTuple(expires: Time, token: String)

    abstract def create_notifier(resource : String, notification_url : String, expiration_time : Time, client_secret : String? = nil, **options) : PlaceCalendar::Subscription
    abstract def renew_notifier(subscription : PlaceCalendar::Subscription, new_expiration_time : Time) : PlaceCalendar::Subscription
    abstract def reauthorize_notifier(subscription : PlaceCalendar::Subscription, new_expiration_time : Time? = nil) : PlaceCalendar::Subscription
    abstract def delete_notifier(subscription : PlaceCalendar::Subscription) : Nil

    alias EmailAttachment = NamedTuple(file_name: String, content: String)
    alias ResourceAttachment = NamedTuple(file_name: String, content: String, content_id: String)

    abstract def send_mail(
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

    # For use in processing send_mail
    protected def to_array(emails : String | Array(String)) : Array(String)
      case emails
      in String
        [emails]
      in Array(String)
        emails
      end
    end

    abstract def client_id : Symbol
    abstract def delegated_access? : Bool
  end
end
