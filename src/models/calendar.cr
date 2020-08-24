class PlaceCalendar::Calendar
  include JSON::Serializable

  @[JSON::Field(ignore: true)]
  property source : String?

  property id : String?
  property summary : String

  property primary : Bool

  def initialize(@id, @summary, @source, @primary = false)
  end
end
