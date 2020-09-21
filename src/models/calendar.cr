class PlaceCalendar::Calendar
  include JSON::Serializable

  @[JSON::Field(ignore: true)]
  property source : String?

  property id : String?
  property summary : String

  property primary : Bool
  property can_edit : Bool?

  def initialize(@id, @summary, @source, @primary = false, @can_edit = false)
  end
end
