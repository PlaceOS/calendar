class PlaceCalendar::Group
  include JSON::Serializable

  @[JSON::Field(ignore: true)]
  property source : String?

  property id : String
  property name : String
  property email : String?
  property description : String?

  def initialize(@id, @name, @email, @description, @source = nil)
  end
end
