class PlaceCalendar::Recurrence
  include JSON::Serializable

  @[JSON::Field(converter: Time::EpochConverter)]
  property range_start : Time

  @[JSON::Field(converter: Time::EpochConverter)]
  property range_end : Time

  property interval : Int32
  property pattern : String
  property days_of_week : String?

  def initialize(@range_start, @range_end, @interval, pattern, @days_of_week = nil)
    @pattern = pattern == "relativemonthly" ? "monthly" : pattern
  end

  def to_google_params
    formatted_until_date = range_end.to_rfc3339.gsub("-", "").gsub(":", "").split(".").first
    until_date = "#{formatted_until_date}"
    case pattern
    when "daily"
      ["RRULE:FREQ=#{pattern.upcase};INTERVAL=#{interval};UNTIL=#{until_date}"]
    else
      ["RRULE:FREQ=#{pattern.upcase};INTERVAL=#{interval};BYDAY=#{days_of_week.not_nil!.upcase[0..1]};UNTIL=#{until_date}"]
    end
  end

  def self.from_google(recurrence_rule, event)
    rule_parts = recurrence_rule.not_nil!.first.split(";")
    location = event.start.time_zone ? Time::Location.load(event.start.time_zone.not_nil!) : Time::Location.load("UTC")
    PlaceCalendar::Recurrence.new(range_start: event.start.time.at_beginning_of_day.in(location),
      range_end: google_range_end(rule_parts, event),
      interval: google_interval(rule_parts),
      pattern: google_pattern(rule_parts),
      days_of_week: google_days_of_week(rule_parts),
    )
  end

  private def self.google_pattern(rule_parts)
    pattern_part = rule_parts.find do |parts|
      parts.includes?("RRULE:FREQ")
    end.not_nil!

    pattern_part.split("=").last.downcase
  end

  private def self.google_interval(rule_parts)
    interval_part = rule_parts.find do |parts|
      parts.includes?("INTERVAL")
    end.not_nil!

    interval_part.split("=").last.to_i
  end

  private def self.google_range_end(rule_parts, event)
    range_end_part = rule_parts.find do |parts|
      parts.includes?("UNTIL")
    end.not_nil!
    until_date = range_end_part.gsub("Z", "").split("=").last
    location = event.start.time_zone ? Time::Location.load(event.start.time_zone.not_nil!) : Time::Location.load("UTC")

    Time.parse(until_date, "%Y%m%dT%H%M%S", location)
  end

  private def self.google_days_of_week(rule_parts)
    byday_part = rule_parts.find do |parts|
      parts.includes?("BYDAY")
    end

    if byday_part
      byday = byday_part.not_nil!.split("=").last

      case byday
      when "SU"
        "sunday"
      when "MO"
        "monday"
      when "TU"
        "tuesday"
      when "WE"
        "wednesday"
      when "TH"
        "thursday"
      when "FR"
        "friday"
      when "SA"
        "saturday"
      end
    end
  end
end
