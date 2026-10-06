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

  # Which occurrence of its weekday `time` is in the month, for "monthly" patterns:
  # 1 to 4 for days 1 to 28, or -1 (last) for days 29 to 31, which are always the
  # fifth and final occurrence.
  def self.week_of_month(time : Time) : Int32
    week = (time.day - 1) // 7 + 1
    week == 5 ? -1 : week
  end
end
