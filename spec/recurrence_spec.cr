require "./spec_helper"

describe PlaceCalendar::Recurrence do
  it "works out which occurrence of its weekday a day is in the month" do
    {
      1 => 1, 7 => 1, 8 => 2, 14 => 2, 15 => 3, 21 => 3,
      22 => 4, 28 => 4, 29 => -1, 31 => -1,
    }.each do |day, week|
      PlaceCalendar::Recurrence.week_of_month(Time.utc(2026, 10, day)).should eq(week)
    end
  end

  it "builds Google monthly rules from the start day" do
    range_end = Time.utc(2027, 1, 1)
    monthly = PlaceCalendar::Recurrence.new(Time.utc(2026, 10, 7), range_end, 1, "monthly", "wednesday")
    PlaceCalendar::Google.recurrence_to_google(monthly, Time.utc(2026, 10, 7)).not_nil!.first.should contain("BYDAY=1WE")
    PlaceCalendar::Google.recurrence_to_google(monthly, Time.utc(2026, 10, 28)).not_nil!.first.should contain("BYDAY=4WE")

    month_day = PlaceCalendar::Recurrence.new(Time.utc(2026, 10, 5), range_end, 1, "month_day")
    PlaceCalendar::Google.recurrence_to_google(month_day, Time.utc(2026, 10, 5)).not_nil!.first.should contain("BYMONTHDAY=5;")
  end
end
