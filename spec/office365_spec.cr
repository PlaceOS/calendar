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
end
