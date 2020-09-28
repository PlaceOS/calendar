class PlaceCalendar::Event
  include JSON::Serializable

  @[JSON::Field(converter: Time::EpochConverter)]
  property event_start : Time

  @[JSON::Field(converter: Time::EpochConverter)]
  property event_end : Time?

  property id : String?
  property recurring_event_id : String?
  property host : String?
  property title : String?
  property body : String?
  property attendees : Array(Attendee)
  property location : String?
  property? private : Bool
  property? all_day : Bool
  property timezone : String?
  property recurring : Bool

  property attachments : Array(Attachment)
  property recurrence : Recurrence?
  property status : String?
  property creator : String?

  @[JSON::Field(ignore: true)]
  property source : String?

  def initialize(
    @id = nil,
    @host = nil,
    @event_start = Time.local,
    @event_end = nil,
    @title = nil,
    @body = nil,
    @attendees = [] of Attendee,
    @location = nil,
    @private = false,
    @all_day = false,
    @source = nil,
    @timezone = nil,
    @attachments = [] of Attachment,
    @recurrence = nil,
    @status = nil,
    @creator = nil,
    @recurring_event_id = nil
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
