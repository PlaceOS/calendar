class PlaceCalendar::User
  property source : String?
  property id : String?
  property name : String?
  property email : String?

  def initialize(@id, @name, @email, @source)
  end
end
