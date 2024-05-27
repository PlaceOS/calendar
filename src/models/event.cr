class PlaceCalendar::Event
  include JSON::Serializable

  @[JSON::Field(converter: Time::EpochConverter, type: "integer", format: "Int64")]
  property event_start : Time

  @[JSON::Field(converter: Time::EpochConverter, type: "integer", format: "Int64")]
  property event_end : Time?

  property id : String?
  property recurring_event_id : String?
  property host : String?
  property title : String?
  property body : String?
  property attendees : Array(Attendee)
  property? hide_attendees : Bool = false
  property location : String?
  property? private : Bool
  property? all_day : Bool
  property timezone : String?
  property recurring : Bool? = false

  property created : Time? = nil
  property updated : Time? = nil

  property attachments : Array(Attachment)
  property recurrence : Recurrence?
  property status : String?
  property creator : String?
  property ical_uid : String?

  property online_meeting_provider : String?
  property online_meeting_phones : Array(String)?
  property online_meeting_url : String?
  property online_meeting_sip : String?
  property online_meeting_pin : String?
  property online_meeting_id : String?

  property extended_properties : Hash(String, String?)?

  # the mailbox this event was retrieved from
  getter mailbox : String? = nil

  def set_mailbox(mailbox : String?)
    @mailbox = mailbox
    self
  end

  def initialize(
    @id = nil,
    @host = nil,
    @event_start = Time.local,
    @event_end = nil,
    @title = nil,
    @body = nil,
    @attendees = [] of Attendee,
    @hide_attendees = false,
    @location = nil,
    @private = false,
    @all_day = false,
    @timezone = nil,
    @attachments = [] of Attachment,
    @recurrence = nil,
    @status = nil,
    @creator = nil,
    @recurring_event_id = nil,
    @ical_uid = nil,
    @online_meeting_provider = nil,
    @online_meeting_phones = nil,
    @online_meeting_url = nil,
    @online_meeting_sip = nil,
    @online_meeting_pin = nil,
    @online_meeting_id = nil,
    @extended_properties = nil,
    @created = nil,
    @updated = nil
  )
    @recurring = !@recurrence.nil?
  end

  struct Attendee
    include JSON::Serializable

    property name : String
    property email : String
    property response_status : String?
    property resource : Bool?
    property organizer : Bool?

    def initialize(@name, @email, @response_status = nil, @resource = nil, @organizer = nil)
    end
  end
end
