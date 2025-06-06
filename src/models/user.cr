class PlaceCalendar::User
  include JSON::Serializable

  @[JSON::Field(ignore: true)]
  property next_link : String?

  property id : String?
  property name : String?
  property email : String?
  property phone : String?
  property department : String?
  property title : String?
  property photo : String?
  property username : String?
  property office_location : String?
  property suspended : Bool? = nil

  def initialize(
    @id = nil,
    @name = nil,
    @email = nil,
    @phone = nil,
    @department = nil,
    @title = nil,
    @photo = nil,
    @username = nil,
    @office_location = nil,
    @next_link = nil,
    @suspended = nil,
  )
  end
end
