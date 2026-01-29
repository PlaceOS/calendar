module PlaceCalendar::Office365Availability
  NICE_INTERVALS_MINUTES = [
    1440, 720, 480, 360, 240, 180,
    120, 60, 30, 20, 15, 10, 5,
  ]

  MIN_INTERVAL =    5
  MAX_INTERVAL = 1440
  TARGET_SLOTS =   24

  def self.select_view_interval(window : Time::Span) : Int32
    window_minutes = (window.total_seconds / 60.0).ceil.to_i

    if window_minutes <= MIN_INTERVAL
      raise ArgumentError.new(
        "Window must be greater than #{MIN_INTERVAL} minutes (got #{window_minutes})"
      )
    end

    # ---- Human-friendly breakpoints ----
    interval_minutes =
      case window_minutes
      when 0..30
        5
      when 31..59
        15
      when 60..360
        30
      when 361..1440
        60
      else
        # ---- Generic scaling for large windows ----
        raw = ((window_minutes - 1) // TARGET_SLOTS)
        NICE_INTERVALS_MINUTES.find { |m| m <= raw } || 60
      end

    # Enforce Graph constraint: interval < window
    while interval_minutes >= window_minutes
      idx = NICE_INTERVALS_MINUTES.index(interval_minutes)
      interval_minutes =
        idx && idx < NICE_INTERVALS_MINUTES.size - 1 ? NICE_INTERVALS_MINUTES[idx + 1] : MIN_INTERVAL
    end

    interval_minutes.clamp(MIN_INTERVAL, MAX_INTERVAL)
  end
end
