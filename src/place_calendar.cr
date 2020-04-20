require "office365"
require "google"

require "./models/*"
require "./interface"
require "./google"
require "./office365"

module PlaceCalendar
  VERSION = "0.1.0"

  enum Type
    Google
    Office365
  end

  class Client
    getter calendar : Interface

    delegate list_users, get_user, list_calendars, get_calendar, list_rooms,
      list_events, get_event, create_event, update_event, delete_event, to: @calendar

    def initialize(type : Type, **credentials)
      @calendar = case type
                  when Type::Google
                    Google.new(**credentials)
                  when Type::Office365
                    Office365.new(**credentials)
                  else
                    raise "Unsupported calendar type"
                  end
    end
  end
end
