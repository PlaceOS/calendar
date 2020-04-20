class PlaceCalendar::Event
  property id : String?
  property starts_at : Time?
  property ends_at : Time?
  property subject : String?
  property description : String?
  property attendees : Array(NamedTuple(name: String, email: String))
  property locations : Array(NamedTuple(name: String, email: String))
  property? is_private : Bool?
  property source : String?

  def initialize(
    @id = nil,
    @starts_at = nil,
    @ends_at = nil,
    @subject = nil,
    @description = nil,
    @attendees = [] of NamedTuple(name: String, email: String),
    @locations = [] of NamedTuple(name: String, email: String),
    @is_private = nil,
    @source = nil
  )
  end

  def duration=(duration : Time::Span)
    @ends_at = @starts_at + duration
  end
end
