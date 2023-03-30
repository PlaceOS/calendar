module PlaceCalendar
  enum AvailabilityStatus
    Busy
    Free

    def to_json(json : JSON::Builder)
      json.string(to_s.downcase)
    end
  end

  class AvailabilitySchedule
    include JSON::Serializable

    property calendar : String
    property availability : Array(Availability)

    def initialize(@calendar, @availability = [] of Availability)
    end
  end

  class Availability
    include JSON::Serializable

    property status : AvailabilityStatus

    @[JSON::Field(converter: Time::EpochConverter, type: "integer", format: "Int64")]
    property starts_at : Time

    @[JSON::Field(converter: Time::EpochConverter, type: "integer", format: "Int64")]
    property ends_at : Time

    property timezone : String

    def initialize(@status, @starts_at, @ends_at, @timezone)
    end
  end
end
