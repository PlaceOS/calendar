require "spec"
require "../src/place_calendar"
require "vcr"

# I change the fields included here to exlude body + headers
# otherwise the md5sums VCR generates from request#to_json change
# too frequently
class HTTP::Request
  def to_json
    {
      method:       method,
      host:         host,
      resource:     resource,
    }.to_json
  end
end


def o365_creds
  {
    tenant:        "bb89674a-238b-4b7d-91ec-6bebad83553a",
    client_id:     "",
    client_secret: "",
  }
end

def google_creds
  {
    # this is not a real key
    file_path: "./spec/fixtures/client_auth.json",
    domain:    "redant.com.au",
    sub:       "toby@redant.com.au",
    scopes:    "https://www.googleapis.com/auth/calendar https://www.googleapis.com/auth/directory.user.readonly https://www.googleapis.com/auth/drive",
  }
end

def authentication_spec(client)
  client.should_not be_nil
  client.should be_a(PlaceCalendar::Client)
end

def users_spec(client)
  list = client.list_users

  list.should be_a(Array(PlaceCalendar::User))
  list.size.should be > 0

  user_id = list[0].try &.id

  user = client.get_user(id: user_id)
  if !user.nil?
    user.should be_a(PlaceCalendar::User)
    user.id.should eq(user_id)
  else
    raise "uh.. #get_user returned nil?"
  end
end

def calendars_spec(client, username)
  list = client.list_calendars(username)
  list.should be_a(Array(PlaceCalendar::Calendar))
  list.size.should be > 0
end

def events_spec(client, username)
  a = PlaceCalendar::Event.new
  a.title = "My New Meeting, Delete me"
  a.description = "The quick brown fox jumps over the lazy dog"

  start_time = Time.local(year: 2020, month: 8, day: 31, hour: 10, minute: 0, location: Time::Location.load("Australia/Sydney"))

  a.event_start = start_time
  a.event_end = start_time + 30.minutes
  a.attendees << {name: "Toby Carvan", email: "testing@redant.com.au"}
  a.attendees << {name: "Amit Gaur", email: "amit@redant.com.au"}

  new_event = client.create_event(user_id: username, event: a)
  new_event.should be_a(PlaceCalendar::Event)

  list = client.list_events(username)
  list.should be_a(Array(PlaceCalendar::Event))
  list.size.should be > 0

  event = nil
  if !new_event.nil?
    event = client.get_event(username, new_event.try &.id.not_nil!)
    event.should be_a(PlaceCalendar::Event)
  end

  schedule = client.get_availability(username, [username], start_time - 1.week, start_time + 1.week)
  schedule.should be_a(Array(PlaceCalendar::AvailabilitySchedule))
  schedule.size.should eq(1)
  schedule.first.availability.should be_a(Array(PlaceCalendar::Availability))
  schedule.first.availability.size.should be > 0

  if !new_event.nil?
    example_attachment_path = File.expand_path("./spec/fixtures/not_sure_if.jpg")
    attachment = PlaceCalendar::Attachment.new(name: "not_sure_if.jpg", content_bytes: File.read(example_attachment_path))
    client.create_attachment(user_id: username, event_id: new_event.id.not_nil!, attachment: attachment).should be_a(PlaceCalendar::Attachment)
    attachment_list = client.list_attachments(user_id: username, event_id: new_event.id.not_nil!)
    attachment_list.size.should eq(1)
    jpg = client.get_attachment(user_id: username, event_id: new_event.id.not_nil!, id: attachment_list[0].try &.id.not_nil!)
    jpg.should be_a(PlaceCalendar::Attachment)
    File.write("not_sure_if_new.jpg", jpg.try &.content_bytes)
    #File.size("not_sure_if_new.jpg").should eq(File.size(example_attachment_path))
    File.delete("not_sure_if_new.jpg")
    if !jpg.nil?
      client.delete_attachment(user_id: username, event_id: new_event.id.not_nil!, id: jpg.id.not_nil!).should be_true
    end

    client.list_attachments(user_id: username, event_id: new_event.id.not_nil!).size.should eq(0)

    new_event.all_day?.should be_false
    new_event.event_start.hour.should eq(10)
    new_event.event_start.location.to_s.should eq("Australia/Sydney")
    new_event.all_day = true
    new_event.event_start = start_time.at_beginning_of_day
    new_event.event_end = start_time.at_beginning_of_day + 1.day
    new_event.title = "A whole new title"
    updated_event = client.update_event(user_id: username, event: new_event)
    updated_event.should be_a(PlaceCalendar::Event)
    updated_event.try &.title.should eq("A whole new title")
    updated_event.try &.all_day?.should be_true

    if !updated_event.nil?
      updated_event_id = updated_event.try &.id
      if !updated_event_id.nil?
        client.delete_event(id: updated_event_id, user_id: username).should be_true
      end
    else
      raise "failed to delete a  event?"
    end
  end
end

def events_recurrence_spec(client, username)
  cleanup_events(client, username)

  a = PlaceCalendar::Event.new
  a.title = "My new recurring meeting, Delete me"
  a.description = "The quick brown fox jumps over the lazy dog"

  start_time = Time.local(year: 2020, month: 8, day: 31, hour: 10, minute: 0, location: Time::Location.load("Australia/Sydney"))
  daily_recurrence_end = start_time + 14.days
  daily_recurrence = PlaceCalendar::Recurrence.new(start_time, daily_recurrence_end, 2, "daily")

  a.event_start = start_time
  a.event_end = start_time + 30.minutes
  a.attendees << {name: "Toby Carvan", email: "testing@redant.com.au"}
  a.attendees << {name: "Amit Gaur", email: "amit@redant.com.au"}
  a.recurrence = daily_recurrence
  new_event = client.create_event(user_id: username, event: a)
  new_event.should be_a(PlaceCalendar::Event)
  ne_recurrence = new_event.not_nil!.recurrence.not_nil!
  ne_recurrence.interval.should eq(2)
  ne_recurrence.pattern.should eq("daily")
  ne_recurrence.range_end.should eq(daily_recurrence_end.at_beginning_of_day)
  ne_recurrence.range_start.should eq(start_time.at_beginning_of_day)

  client.list_events(username).size.should eq(8)

  if !new_event.nil?
    # Testing the data on fetched event
    fetched_event = client.get_event(username, new_event.try &.id.not_nil!)
    fe_recurrence = fetched_event.not_nil!.recurrence.not_nil!
    fe_recurrence.interval.should eq(2)
    fe_recurrence.pattern.should eq("daily")
    fe_recurrence.range_end.should eq(daily_recurrence_end.at_beginning_of_day)
    fe_recurrence.range_start.should eq(start_time.at_beginning_of_day)

    # remove recurrence
    new_event.not_nil!.recurrence = nil
    client.update_event(user_id: username, event: new_event)
    # should be left with single instance
    client.list_events(username).size.should eq(1)
  end

  cleanup_events(client, username)
  # Weekly recurrence tests
  a = PlaceCalendar::Event.new
  a.title = "Weekly recurring meeting, Delete me"
  a.description = "Weekly The quick brown fox jumps over the lazy dog"
  weekly_recurrence_end = start_time + 4.weeks
  a.event_start = start_time
  a.event_end = start_time + 30.minutes
  a.attendees << {name: "Toby Carvan", email: "testing@redant.com.au"}
  a.attendees << {name: "Amit Gaur", email: "amit@redant.com.au"}
  weekly_recurrence = PlaceCalendar::Recurrence.new(start_time, weekly_recurrence_end, 1, "weekly", "monday")
  a.recurrence = weekly_recurrence
  new_event = client.create_event(user_id: username, event: a)
  ne_recurrence = new_event.not_nil!.recurrence.not_nil!
  ne_recurrence.interval.should eq(1)
  ne_recurrence.pattern.should eq("weekly")
  ne_recurrence.days_of_week.should eq("monday")
  event_list = client.list_events(username)
  # Google creates event for start_date(1) + recurrence(4) if start date is not recurrence start date
  # Microsoft only creates for recurrence(4)
  event_list.size.should be <= 5
  event_list.size.should be >= 4

  # Recurring Events are 1 week apart
  event_list_starts = event_list.map do |recurring_event|
    recurring_event.event_start
  end
  recurring_starts = event_list_starts.last(4)
  (recurring_starts[0] + 1.week).should eq(recurring_starts[1])
  (recurring_starts[1] + 1.week).should eq(recurring_starts[2])
  (recurring_starts[2] + 1.week).should eq(recurring_starts[3])

  # Moving start date
  new_event.not_nil!.event_start = start_time + 1.week
  new_event.not_nil!.event_end = start_time + 1.week + 30.minutes
  client.update_event(user_id: username, event: new_event.not_nil!)

  event_list = client.list_events(username)
  # Have 1 less event as everything moved by 1 week
  event_list.size.should be <= 4
  event_list.size.should be >= 3
  event_list_starts = event_list.map do |recurring_event|
    recurring_event.event_start
  end
  recurring_starts = event_list_starts.last(3)
  (recurring_starts[0] + 1.week).should eq(recurring_starts[1])
  (recurring_starts[1] + 1.week).should eq(recurring_starts[2])

  cleanup_events(client, username)
  # Monthly recurrence tests
  a = PlaceCalendar::Event.new
  a.title = "Monthly recurring meeting, Delete me"
  a.description = "Monthly The quick brown fox jumps over the lazy dog"
  monthly_recurrence_end = start_time + 4.months
  a.event_start = start_time
  a.event_end = start_time + 30.minutes
  a.attendees << {name: "Toby Carvan", email: "testing@redant.com.au"}
  a.attendees << {name: "Amit Gaur", email: "amit@redant.com.au"}
  monthly_recurrence = PlaceCalendar::Recurrence.new(start_time, monthly_recurrence_end, 2, "monthly", "tuesday")
  a.recurrence = monthly_recurrence
  new_event = client.create_event(user_id: username, event: a)
  new_event.should be_a(PlaceCalendar::Event)
  ne_recurrence = new_event.not_nil!.recurrence.not_nil!
  ne_recurrence.interval.should eq(2)
  ne_recurrence.pattern.should eq("monthly")
  # it should start from next Tuesday
  ne_recurrence.days_of_week.should eq("tuesday")
  event_list = client.list_events(username)
  event_list.map do |recurring_event|
    recurring_event.event_start
  end
  # Google creates event for start_date + recurrence
  # Microsoft only creates for recurrence
  event_list.size.should be <= 3
end

def cleanup_events(client, username)
  # Cleanup before we start
  existing_events = client.list_events(username)
  existing_events.each do |event|
    client.delete_event(id: event.try &.id.not_nil!, user_id: username)
  end
end
