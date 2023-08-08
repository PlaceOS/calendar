class PlaceCalendar::Recurrence
  include JSON::Serializable

  @[JSON::Field(converter: Time::EpochConverter, type: "integer", format: "Int64")]
  property range_start : Time

  @[JSON::Field(converter: Time::EpochConverter, type: "integer", format: "Int64")]
  property range_end : Time

  # the gap in the pattern (daily + an interval of every 2nd day etc)
  property interval : Int32

  # one of daily, weekly, monthly, month_day
  property pattern : String

  # sunday, monday, wednesday, thursday, friday, saturday
  property days_of_week : Array(String) { [] of String }

  def initialize(@range_start, @range_end, @interval, @pattern, days_of_week : String | Array(String) = [] of String)
    @days_of_week = days_of_week.is_a?(Array) ? days_of_week : [days_of_week]
  end
end
