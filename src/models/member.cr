class PlaceCalendar::Member
  include JSON::Serializable

  @[JSON::Field(ignore: true)]
  property source : String?

  property id : String
  property email : String

  def initialize(@id, @email, @source = nil)
  end
end
