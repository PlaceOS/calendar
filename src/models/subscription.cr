struct PlaceCalendar::Subscription
  include JSON::Serializable

  # Subscription details
  getter id : String
  getter expires_at : Time?
  getter resource_id : String
  getter resource_uri : String

  # Used to confirm that the message came from a reputable source
  @client_secret : String | Int64?

  def client_secret : String
    @client_secret.to_s
  end

  # Where the notifications are being sent
  getter notification_url : String

  getter user_id : String?

  def expired?
    if time = expires_at
      5.minutes.from_now >= time
    else
      false
    end
  end

  def initialize(@id, @resource_id, @resource_uri, @notification_url, @expires_at = nil, @client_secret = nil, @user_id = nil)
  end
end
