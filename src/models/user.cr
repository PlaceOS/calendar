class PlaceCalendar::User
  include JSON::Serializable

  @[JSON::Field(ignore: true)]
  property source : String?

  property id : String?
  property name : String?
  property email : String?

  def initialize(@id, @name, @email, @source)
  end
end
