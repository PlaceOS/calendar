class PlaceCalendar::User
  include JSON::Serializable

  @[JSON::Field(ignore: true)]
  property source : String?

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

  def initialize(
    @id = nil,
    @name = nil,
    @email = nil,
    @phone = nil,
    @department = nil,
    @title = nil,
    @photo = nil,
    @username = nil,
    @source = nil,
    @office_location = nil,
    @next_link = nil
  )
  end
end
