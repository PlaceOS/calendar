class PlaceCalendar::Attachment
  include JSON::Serializable

  property id : String?
  property name : String
  property content_type : String?
  property content_bytes : String
  property size : Int32?

  def initialize(
    @name,
    @content_bytes,
    @id = nil,
    @content_type = nil,
    @size = nil,
  )
  end
end
