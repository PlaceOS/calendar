require "./spec_helper"

describe PlaceCalendar::Office365 do

  it "authenticates" do
    client = PlaceCalendar::Client.new(PlaceCalendar::InterfaceType::Office365, **o365_creds)
    authentication_spec(client)
  end

  it "lists users, and gets users" do
    client = PlaceCalendar::Client.new(PlaceCalendar::InterfaceType::Office365, **o365_creds)
    users_spec(client)
  end

  it "lists calendars" do
    client = PlaceCalendar::Client.new(PlaceCalendar::InterfaceType::Office365, **o365_creds)
    calendars_spec(client, "dev@acaprojects.com")
  end

  it "lists, creates, updates, and deletes events" do
    client = PlaceCalendar::Client.new(PlaceCalendar::InterfaceType::Office365, **o365_creds)
    events_spec(client, "dev@acaprojects.com")
  end

  it "supports recurring events" do
    client = PlaceCalendar::Client.new(PlaceCalendar::InterfaceType::Office365, **o365_creds)
    events_recurrence_spec(client, "dev@acaprojects.com")
  end

end
