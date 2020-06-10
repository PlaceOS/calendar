require "./spec_helper"

describe PlaceCalendar::Google do
  it "authenticates" do
    client = PlaceCalendar::Client.new(PlaceCalendar::InterfaceType::Google, **google_creds)
    authentication_spec(client)
  end

  it "lists users, and gets users" do
    client = PlaceCalendar::Client.new(PlaceCalendar::InterfaceType::Google, **google_creds)
    users_spec(client)
  end

  it "lists calendars" do
    client = PlaceCalendar::Client.new(PlaceCalendar::InterfaceType::Google, **google_creds)
    calendars_spec(client, "toby@redant.com.au")
  end

  it "lists, creates, updates, and deletes events" do
    client = PlaceCalendar::Client.new(PlaceCalendar::InterfaceType::Google, **google_creds)
    events_spec(client, "testing@redant.com.au")

    # WARNING: ALWAYS USE TEST EMAIL ACCOUNT HERE
    # TESTS DELETE EVENTS TO RUN THEIR ASSERTIONS
    events_recurrence_spec(client, "testing@redant.com.au")
  end
end
