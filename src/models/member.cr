class PlaceCalendar::Member
  include JSON::Serializable

  @[JSON::Field(ignore: true)]
  property next_link : String?

  property id : String
  property name : String?
  property email : String
  property phone : String?
  property username : String
  property suspended : Bool?

  def initialize(@id, @email, @username, @name = nil, @suspended = nil, @next_link = nil, @phone = nil)
  end
end
