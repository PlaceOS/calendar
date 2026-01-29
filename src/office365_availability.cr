module PlaceCalendar::Office365Availability
  # "Nice" bucket sizes in minutes (descending for easy selection)
  NICE_INTERVALS_MINUTES = [
    1440, 720, 480, 360, 240, 180,
    120, 60, 30, 20, 15, 10, 5,
  ]

  MIN_INTERVAL =    5
  MAX_INTERVAL = 1440
  TARGET_SLOTS =   24

  def self.select_view_interval(window : Time::Span) : Int32
    # Convert to minutes, rounding up to avoid zero-length edge cases
    window_minutes = (window.total_seconds / 60.0).ceil.to_i

    # Graph constraint: interval must be >= 5 and < window
    if window_minutes <= MIN_INTERVAL
      raise ArgumentError.new(
        "Window must be greater than #{MIN_INTERVAL} minutes (got #{window_minutes})"
      )
    end

    # Target an interval that yields ~TARGET_SLOTS buckets
    raw = ((window_minutes - 1) // TARGET_SLOTS)

    # Pick the largest "nice" interval <= raw
    interval_minutes =
      NICE_INTERVALS_MINUTES.find { |m| m <= raw } || MIN_INTERVAL

    # Safety: ensure strict < window
    while interval_minutes >= window_minutes
      idx = NICE_INTERVALS_MINUTES.index(interval_minutes)
      interval_minutes =
        idx && idx < NICE_INTERVALS_MINUTES.size - 1 ? NICE_INTERVALS_MINUTES[idx + 1] : MIN_INTERVAL
    end

    # Clamp (defensive, should never trigger)
    interval_minutes = interval_minutes.clamp(MIN_INTERVAL, MAX_INTERVAL)

    interval_minutes
  end
end
