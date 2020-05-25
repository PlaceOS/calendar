require "office365"
require "google"

require "./models/*"
require "./interface"
require "./google"
require "./office365"

module PlaceCalendar
  VERSION = "0.1.0"

  class Client
    getter calendar : Interface

    delegate list_users, get_user, list_calendars, get_calendar, list_rooms,
      list_events, get_event, create_event, update_event, delete_event,
      list_attachments, get_attachment, create_attachment, delete_attachment, to: @calendar

    def initialize(
      tenant : String, 
      client_id : String, 
      client_secret : String
    )
      @calendar = Office365.new(tenant, client_id, client_secret)
    end

    def initialize(
      scopes : String | Array(String), 
      file_path : String,
      domain : String,
      issuer : String? = nil,
      signing_key : String? = nil,
      sub : String = "",
      user_agent : String = "Switch"
    )
      @calendar = Google.new(scopes: scopes, domain: domain, issuer: issuer, signing_key: signing_key, file_path: file_path, user_agent: user_agent, sub: sub)
    end

    def initialize(**ignored)
      @calendar = Interface.new
    end
  end
end
