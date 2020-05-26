class PlaceCalendar::Recurrence
  include JSON::Serializable

  property range_start : Int64
  property range_end : Int64
  property interval : Int32
  property pattern : String
  property days_of_week : String?

  def initialize(@range_start, @range_end, @interval, @pattern, @days_of_week = nil)
  end
end
