require "./spec_helper"

describe PlaceCalendar::Office365 do
  it "authenticates" do
    VCR.use_cassette("office365-authentication") do
      client = PlaceCalendar::Client.new(**o365_creds)
      authentication_spec(client)
    end
  end

  it "lists users, and gets users" do
    mock_office365_client_auth

    WebMock.stub(:get, "https://graph.microsoft.com/v1.0/users?%24filter=accountEnabled+eq+true")
      .to_return(Office365::UserQuery.new(
        value: [Office365::User.from_json(%({"id":"1234","displayName":"Test User","businessPhones":[],"userPrincipalName":"test-user@example.com"}))]
      ).to_json
      )

    WebMock.stub(:get, "https://graph.microsoft.com/v1.0/users/1234")
      .to_return(Office365::User.from_json(%({"id":"1234","displayName":"Test User","businessPhones":[],"userPrincipalName":"test-user@example.com"})).to_json
      )

    client = PlaceCalendar::Client.new(**o365_creds)
    users_spec(client)
  end

  it "lists calendars" do
    mock_office365_client_auth

    WebMock.stub(:get, "https://graph.microsoft.com/v1.0/users/dev%40acaprojects.com/calendars?")
      .to_return(Office365::CalendarQuery.new(
        value: [Office365::Calendar.from_json(%({"id":"1234","name":"Test calendar"}))]
      ).to_json
      )

    client = PlaceCalendar::Client.new(**o365_creds)
    calendars_spec(client, "dev@acaprojects.com")
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

  it "sends an attendees-only update when notify_existing_attendees is false" do
    mock_office365_client_auth

    captured_body = ""
    WebMock.stub(:patch, "https://graph.microsoft.com/v1.0/users/dev%40acaprojects.com/calendar/events/1234")
      .to_return do |request|
        captured_body = request.body.try(&.gets_to_end) || ""
        HTTP::Client::Response.new(200, body: Office365::Event.new(
          starts_at: Time.utc,
          ends_at: Time.utc + 30.minutes,
          subject: "Existing Meeting",
        ).to_json)
      end

    client = PlaceCalendar::Client.new(**o365_creds)

    event = PlaceCalendar::Event.new
    event.id = "1234"
    event.title = "Existing Meeting"
    event.event_start = Time.utc
    event.event_end = Time.utc + 30.minutes
    event.attendees << PlaceCalendar::Event::Attendee.new(name: "Existing", email: "existing@example.com")
    event.attendees << PlaceCalendar::Event::Attendee.new(name: "New", email: "new@example.com")

    client.update_event(user_id: "dev@acaprojects.com", event: event, calendar_id: "dev@acaprojects.com", notify_existing_attendees: false)

    body = JSON.parse(captured_body).as_h
    # Only the attendees property is sent so office365 emails the newly added
    # attendee(s) only and leaves existing attendees alone.
    body.keys.should eq(["attendees"])
    body["attendees"].as_a.size.should eq(2)
  end
end
