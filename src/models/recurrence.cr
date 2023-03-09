class PlaceCalendar::Recurrence
  include JSON::Serializable

  @[JSON::Field(converter: Time::EpochConverter, type: "integer", format: "Int64")]
  property range_start : Time

  @[JSON::Field(converter: Time::EpochConverter, type: "integer", format: "Int64")]
  property range_end : Time

  property interval : Int32
  property pattern : String
  property days_of_week : String?

  def initialize(@range_start, @range_end, @interval, pattern, @days_of_week = nil)
    @pattern = pattern == "relativemonthly" ? "monthly" : pattern
  end
end
