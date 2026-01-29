require "spec"

module PlaceCalendar
  describe Office365Availability do
    describe ".select_view_interval" do
      it "returns 5 minutes for small windows" do
        Office365Availability.select_view_interval(15.minutes)
          .should eq(5)

        Office365Availability.select_view_interval(29.minutes)
          .should eq(5)
      end

      it "handles exact boundaries safely" do
        Office365Availability.select_view_interval(6.minutes)
          .should eq(5)

        Office365Availability.select_view_interval(10.minutes)
          .should eq(5)
      end

      it "scales up for hour-scale windows" do
        Office365Availability.select_view_interval(2.hours)
          .should eq(5)

        Office365Availability.select_view_interval(8.hours)
          .should eq(15)
      end

      it "returns sensible intervals for day-scale windows" do
        Office365Availability.select_view_interval(24.hours)
          .should eq(30)

        Office365Availability.select_view_interval(7.days)
          .should eq(6.hours.total_minutes)
      end

      it "returns daily buckets for very large windows" do
        Office365Availability.select_view_interval(30.days)
          .should eq(1.day.total_minutes)
      end

      it "raises for windows too small to satisfy Graph constraints" do
        expect_raises(ArgumentError) do
          Office365Availability.select_view_interval(5.minutes)
        end

        expect_raises(ArgumentError) do
          Office365Availability.select_view_interval(3.minutes)
        end
      end

      it "always returns an interval strictly smaller than the window" do
        windows = [
          6.minutes,
          20.minutes,
          90.minutes,
          12.hours,
          3.days,
        ]

        windows.each do |w|
          interval = Office365Availability.select_view_interval(w)
          interval.minutes.should be < w
        end
      end
    end
  end
end
