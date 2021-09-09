class PlaceCalendar::Calendar
  include JSON::Serializable

  @[JSON::Field(ignore: true)]
  property source : String?

  property id : String?
  property ref : String?
  property summary : String

  property primary : Bool
  property can_edit : Bool?

  def mailbox
    @id
  end

  def initialize(@id, @summary, @source, @primary = false, @can_edit = false, @ref = nil)
  end
end
