class PlaceCalendar::Group
  include JSON::Serializable

  property id : String
  property name : String
  property email : String?
  property description : String?

  def initialize(@id, @name, @email, @description)
  end
end
