[![Build Status](https://travis-ci.com/PlaceOS/calendar.svg?branch=master)](https://travis-ci.com/PlaceOS/calendar)

# calendar

PlaceCalendar provides a standardised interface for cloud based calendaring solutions, with Office365 and Google currently supported.

Endpoints are provided for

* Users (list)
* Calendars (list, get)
* Events (list, get, create, update, delete)
* Attachments (list, get, create, update, delete)
* Availability (get)


## Installation

1. Add the dependency to your `shard.yml`:

   ```yaml
   dependencies:
     place_calendar:
       github: PlaceOS/calendar
   ```

2. Run `shards install`

## Usage

```crystal
require "place_calendar"
```

### Office365 Configuration

```
o365_creds = {
  tenant:        "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx",
  client_id:     "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx",
  client_secret: "xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx",
}

client = PlaceCalendar::Client.new(**o365_creds)
```

### Google Configuration

```
google_creds = {
  file_path: "/path/to/your/credtions.json",
  scopes:    ["https://www.googleapis.com/auth/calendar", "https://www.googleapis.com/auth/directory.user.readonly", "https://www.googleapis.com/auth/drive"],
  domain:    "yourdomain.com"
}

client = PlaceCalendar::Client.new(**google_creds)
```

### Users

```
list = client.list_users
```

### Calendars

```
# list calendars
calendars = client.list_calendars("mailbox@domain.com")

# get a calendar
calendar = client.get_calendar("mailbox@domain.com", calendar_id)
```

### Events

```
# list events
list = client.list_events("mailbox@domain.com")

# get an event
event = client.get_event("mailbox@domain.com", event_id)

# create an event
e = PlaceCalendar::Event.new
e.title = "My New Meeting"
e.body = "All about my new meeting"
e.event_start = Time.local
e.event_end = Time.local + 30.minutes
a.attendees << {name: "John Smith", email: "john.smith@domain.com"}
new_event = client.create_event(user_id: "mailbox@domain.com", event: e)

# update an event
new_event.attendees << {name: "Foo Bar", email: "foo.bar@domain.com"}
client.update_event(user_id: "mailbox@domain.com", event: new_event)

# delete an event
client.delete_event(user_id: "mailbox@domain.com", id: new_event.id)

# recurring events
daily_recurrence = PlaceCalendar::Recurrence.new(
  Time.local,           # recurrence start time
  Time.local + 14.days, # recurrence end time
  2,                    # recurrence interval
  "daily"               # recurrent pattern, daily, weekly, or monthly
)

my_event.recurrence = daily_recurrence
client.update_event(user_id: "mailbox@domain.com", id: my_event.id)
```

### Attachments

```
# list attachments
attachments = client.list_attachments(user_id: "mailbox@domain.com", event_id: my_event.id)

# get an attachment
attachment = client.get_attachent(user_id: "mailbox@domain.com", event_id: my_event.id, id: "123")

# create an attachment
my_attachment = PlaceCalendar::Attachment.new(name: "filename.ext", content_bytes: File.read("filename.ext"))
client.create_attachment(user_id: "mailbox@domain.com", event_id: event.id, attachment: my_attachment)

# delete an attachment
client.delete_attachment(user_id: "mailbox@domain.com", event_id: my_event.id, attachment_id: my_attachment.id)
```

### Availability

```
# get availability for multiple uers
# this will return an array of PlaceCalendar::Availability objects, one for each of the emails in the array, for the time period specified
schedule = client.get_availability("mailbox@domain.com", ["me@domain.com", "you@domain.com", "them@domain.com"], Time.local - 1.week, Time.local + 1.week)
```

## Development

TODO: Write development instructions here

## Contributing

1. Fork it (<https://github.com/your-github-user/place_calendar/fork>)
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create a new Pull Request

## Contributors

- [Toby Carvan](https://github.com/your-github-user) - creator and maintainer
