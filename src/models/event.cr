class PlaceCalendar::Event
  include JSON::Serializable

  @[JSON::Field(converter: Time::EpochConverter)]
  property event_start : Time

  @[JSON::Field(converter: Time::EpochConverter)]
  property event_end : Time?

  property id : String?
  property host : String?
  property title : String?
  property description : String?
  property attendees : Array(NamedTuple(name: String, email: String))
  property location : Location?
  property? private : Bool
  property? all_day : Bool

  @[JSON::Field(ignore: true)]
  property source : String?

  def initialize(
    @id = nil,
    @host = nil,
    @event_start = Time.local,
    @event_end = nil,
    @title = nil,
    @description = nil,
    @attendees = [] of NamedTuple(name: String, email: String),
    @location = nil,
    @private = false,
    @all_day = false,
    @source = nil
  )
    
  end

  def timezone
    @timezone ||= @event_start.zone.to_s
  end

  def location=(text : String)
    @location ||= Location.new
    @location.text = text
  end
end

