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
  property unmapped : Hash(String, ::JSON::Any)? = nil

  def initialize(@id, @email, @username, @name = nil, @suspended = nil, @next_link = nil, @phone = nil, @unmapped = nil)
  end
end
