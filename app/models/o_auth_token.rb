class OAuthToken < ActiveRecord::Base
  attr_accessible :access_token, :expires_at, :refresh_token, :service

  belongs_to :account

  validates_presence_of :account
  validates_uniqueness_of :service, :scope => :account_id

  enumerated_attribute :service, %w(^google)

  def self.new_from(oauth_response, a_service)
    self.new :access_token => oauth_response.token,
      :refresh_token => oauth_response.refresh_token,
      :expires_at => DateTime.now.utc + oauth_response.expires_in.to_i.seconds,
      :service => a_service
  end

  def expired?
    # Use 1 minute as epsilon, usual tokens last for at least an hour
    (self.expires_at + 1.minute) < DateTime.now.utc
  end

  def refresh!
    new_token = oauth2_access_token.refresh!
    self.access_token = new_token.token
    self.expires_at = DateTime.now.utc + new_token.expires_in.to_i.seconds
  end

  private

  def oauth2_access_token
    OAuth2::AccessToken.new client, self.access_token,
      refresh_token: refresh_token,
      expires_at: expires_at.utc.to_i
  end

  def client
    OAuth2::Client.send(self.service)
  end

end
