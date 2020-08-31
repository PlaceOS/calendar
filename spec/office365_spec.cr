require "./spec_helper"

describe PlaceCalendar::Office365 do
  it "authenticates" do
    VCR.use_cassette("office365-authentication") do
      client = PlaceCalendar::Client.new(**o365_creds)
      authentication_spec(client)
    end
  end

  it "lists users, and gets users" do
    VCR.use_cassette("office365-users") do
      client = PlaceCalendar::Client.new(**o365_creds)
      users_spec(client)
    end
  end

  it "lists calendars" do
    VCR.use_cassette("office365-calendars") do
      client = PlaceCalendar::Client.new(**o365_creds)
      calendars_spec(client, "dev@acaprojects.com")
    end
  end

  it "lists, creates, updates, and deletes events" do
    VCR.use_cassette("office365-events", :in_order) do
      client = PlaceCalendar::Client.new(**o365_creds)
      events_spec(client, "dev@acaprojects.com")
    end
  end

  it "supports recurring events" do
    VCR.use_cassette("office365-recurrence", :in_order) do
      client = PlaceCalendar::Client.new(**o365_creds)
      events_recurrence_spec(client, "dev@acaprojects.com")
    end
  end
end
