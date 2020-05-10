class PlaceCalendar::User
  include JSON::Serializable

  property source : String?
  property id : String?
  property name : String?
  property email : String?

  def initialize(@id, @name, @email, @source)
  end
end
