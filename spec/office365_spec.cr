require "./spec_helper"

describe PlaceCalendar::Office365 do

  it "authenticates" do
    client = PlaceCalendar::Client.new(**o365_credentials)

    client.should_not be_nil
    client.should be_a(PlaceCalendar::Client)
  end

  it "lists users, and gets users" do
    client = PlaceCalendar::Client.new(**o365_credentials)

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

  it "lists calendars" do
    client = PlaceCalendar::Client.new(**o365_credentials)

    list = client.list_calendars("dev@acaprojects.com")
    list.should be_a(Array(PlaceCalendar::Calendar))
    list.size.should be > 0
  end

  it "lists, creates, updates, and deletes events" do
    client = PlaceCalendar::Client.new(**o365_credentials)
    list = client.list_events("dev@acaprojects.com")
    list.should be_a(Array(PlaceCalendar::Event))
    list.size.should be > 0

    a = PlaceCalendar::Event.new
    a.title = "My New Meeting, Delete me"
    a.description = "The quick brown fox jumps over the lazy dog"
    a.event_start = Time.local
    a.event_end = Time.local + 30.minutes
    a.attendees << {name: "Toby Carvan", email: "toby@redant.com.au"}
    a.attendees << {name: "Amit Gaur", email: "amit@redant.com.au"}

    new_event = client.create_event(user_id: "dev@acaprojects.com", event: a)
    new_event.should be_a(PlaceCalendar::Event)

    if !new_event.nil?
      new_event.title = "A whole new title"
      updated_event = client.update_event(user_id: "dev@acaprojects.com", event: new_event)
      updated_event.should be_a(PlaceCalendar::Event)
      updated_event.try &.title.should eq("A whole new title")

      if !updated_event.nil?
        updated_event_id = updated_event.try &.id
        if !updated_event_id.nil?
          client.delete_event(id: updated_event_id, user_id: "dev@acaprojects.com").should be_true
        end
      else
        raise "failed to delete a  event?"
      end
    end

    
  end

end
