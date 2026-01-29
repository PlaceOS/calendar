require "spec"

module PlaceCalendar
  describe Office365Availability do
    describe ".select_view_interval" do
      it "uses 30 minute buckets for 1–2 hour windows" do
        Office365Availability.select_view_interval(1.hour)
          .should eq(30)

        Office365Availability.select_view_interval(2.hours)
          .should eq(30)
      end

      it "uses finer granularity for short windows" do
        Office365Availability.select_view_interval(20.minutes)
          .should eq(5)

        Office365Availability.select_view_interval(45.minutes)
          .should eq(15)
      end

      it "scales to hourly buckets for half-day windows" do
        Office365Availability.select_view_interval(8.hours)
          .should eq(1.hour.total_minutes)
      end

      it "scales naturally for multi-day windows" do
        Office365Availability.select_view_interval(7.days)
          .should eq(6.hours.total_minutes)
      end

      it "always returns an interval strictly smaller than the window" do
        windows = [10.minutes, 1.hour, 6.hours, 2.days]

        windows.each do |w|
          interval = Office365Availability.select_view_interval(w)
          interval.minutes.should be < w
        end
      end
    end
  end
end
