require "./spec_helper"

describe PlaceCalendar::Google do

  it "authenticates" do
    client = PlaceCalendar::Client.new(**google_creds)
    authentication_spec(client)
  end

  it "lists users, and gets users" do
    client = PlaceCalendar::Client.new(**google_creds)
    users_spec(client)
  end

  it "lists calendars" do
    client = PlaceCalendar::Client.new(**google_creds)
    calendars_spec(client)
  end

  it "lists, creates, updates, and deletes events" do
    client = PlaceCalendar::Client.new(**google_creds)
    events_spec(client)
  end

end
