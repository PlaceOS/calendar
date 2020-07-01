class PlaceCalendar::Location
  include JSON::Serializable

  property text : String?
  property address : String?
  property coordinates : Coordinates?

  def initialize(
    @text = nil,
    @address = nil,
    @coordinates = nil
  )
  end
end
