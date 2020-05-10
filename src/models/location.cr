class PlaceCalendar::Location
  include JSON::Serializable

  property text : String?
  property address : String?
  property coordinates : Coordinates?
end
