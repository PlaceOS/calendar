require "./spec_helper"

describe PlaceCalendar::Google do
  it "authenticates" do
    VCR.use_cassette("google-authentication") do
      client = PlaceCalendar::Client.new(**google_creds)
      authentication_spec(client)
    end
  end

  it "lists users, and gets users" do
    VCR.use_cassette("google-users") do
      client = PlaceCalendar::Client.new(**google_creds)
      users_spec(client)
    end
  end

  it "lists calendars" do
    VCR.use_cassette("google-calendars") do
      client = PlaceCalendar::Client.new(**google_creds)
      calendars_spec(client, "toby@redant.com.au")
    end
  end

  it "lists, creates, updates, and deletes events" do
    VCR.use_cassette("google-events", :in_order) do
      client = PlaceCalendar::Client.new(**google_creds)
      events_spec(client, "testing@redant.com.au")
    end
  end

  it "supports recurring events" do
    VCR.use_cassette("google-recurrence", :in_order) do
      client = PlaceCalendar::Client.new(**google_creds)
      # WARNING: ALWAYS USE TEST EMAIL ACCOUNT HERE
      # TESTS DELETE EVENTS TO RUN THEIR ASSERTIONS
      events_recurrence_spec(client, "testing@redant.com.au")
    end
  end
end
