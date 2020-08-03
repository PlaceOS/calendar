require "office365"
require "google"

require "./models/*"
require "./interface"
require "./google"
require "./office365"

module PlaceCalendar
  VERSION = {{ `shards version "#{__DIR__}"`.chomp.stringify.downcase }}

  class Exception < ::Exception
    property http_status : HTTP::Status
    property http_body : String

    def initialize(@http_status, @http_body, @message = nil)
    end
  end

  class Client
    getter calendar : Interface

    delegate list_users, get_user, list_calendars, get_calendar, list_rooms,
      list_events, get_event, create_event, update_event, delete_event,
      list_attachments, get_attachment, create_attachment, delete_attachment,
      get_availability, to: @calendar

    def initialize(
      file_path : String,
      domain : String,
      calendar_scope : String = "https://www.googleapis.com/auth/calendar",
      directory_scope : String = "https://www.googleapis.com/auth/admin.directory.user.readonly",
      sub : String = "",
      user_agent = "PlaceOS"
    )
      @calendar = Google.new(file_path, domain, calendar_scope, directory_scope, sub, user_agent)
    end

    def initialize(
      issuer : String,
      signing_key : String,
      domain : String,
      calendar_scope : String = "https://www.googleapis.com/auth/calendar",
      directory_scope : String = "https://www.googleapis.com/auth/admin.directory.user.readonly",
      sub : String = "",
      user_agent = "PlaceOS"
    )
      @calendar = Google.new(issuer, signing_key, domain, calendar_scope, directory_scope, sub, user_agent)
    end

    def initialize(tenant : String, client_id : String, client_secret : String, _ignore : Int32 = 0)
      @calendar = Office365.new(tenant, client_id, client_secret)
    end
  end
end
