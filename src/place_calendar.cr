require "office365"
require "google"

require "./models/*"
require "./interface"
require "./google"
require "./office365"

module PlaceCalendar
  VERSION = "0.1.0"

  enum InterfaceType
    Office365
    Google
    Unknown
  end

  class Client
    getter calendar : Interface

    delegate list_users, get_user, list_calendars, get_calendar, list_rooms,
      list_events, get_event, create_event, update_event, delete_event,
      list_attachments, get_attachment, create_attachment, delete_attachment,
      get_availability, to: @calendar

    def initialize(type : InterfaceType, **options)
      case type
      when InterfaceType::Office365
        tenant        = required_param("tenant",        **options)
        client_id     = required_param("client_id",     **options)
        client_secret = required_param("client_secret", **options)

        @calendar = Office365.new(
          tenant.not_nil!,
          client_id.not_nil!,
          client_secret.not_nil!
        )
      when InterfaceType::Google
        scopes      = required_param("scopes",      **options)
        file_path   = required_param("file_path",   **options)
        domain      = required_param("domain",      **options)

        issuer      = optional_param("issuer",      **options)
        signing_key = optional_param("signing_key", **options)
        sub         = optional_param("sub",         **options) || ""
        user_agent  = optional_param("user_agent",  **options) || "Switch"

        @calendar = Google.new(
          scopes: scopes.not_nil!,
          domain: domain.not_nil!,
          issuer: issuer,
          signing_key: signing_key,
          file_path: file_path.not_nil!,
          user_agent: user_agent,
          sub: sub
        )
      else
        raise "Unsupported interface type #{type}"
      end
    end

    private def required_param(name, **params)
      get_param(name, true, false, **params)
    end

    private def optional_param(name, **params)
      get_param(name, false, true, **params)
    end

    private def get_param(name : String, required : Bool = false, nullable : Bool = false, **params)
      value = nil

      if params.has_key?(name)
        value = params[name]
      elsif required
        raise "Missing required param #{name}"
      end

      if value.nil? && !nullable
        raise "Non nullable param #{name} is nil"
      end

      if !nullable
        value = value.not_nil!
      end

      return value
    end
  end
end
