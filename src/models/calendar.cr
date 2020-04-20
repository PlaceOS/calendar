class PlaceCalendar::Calendar
  property source : String?
  property id : String?
  property name : String

  def initialize(@id, @name, @source)
  end
end
