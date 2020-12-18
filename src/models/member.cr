class PlaceCalendar::Member
  include JSON::Serializable

  @[JSON::Field(ignore: true)]
  property source : String?

  property id : String
  property email : String
  property username : String

  def initialize(@id, @email, @username, @source = nil)
  end
end
