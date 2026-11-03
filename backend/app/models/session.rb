class Session < ApplicationRecord
  belongs_to :user

  TOKEN_LIFETIME = 24.hours

  validates :token_digest, presence: true, uniqueness: true
  validates :expires_at, presence: true

  scope :active, -> { where("expires_at > ?", Time.current) }

  # Creates a session and returns [session, plaintext_token]. The plaintext
  # token is returned exactly once (at login) and is never stored; only its
  # SHA256 digest is persisted, so a database leak does not hand out sessions.
  def self.create_for(user)
    token = SecureRandom.hex(32)
    session = create!(
      user: user,
      token_digest: digest(token),
      expires_at: TOKEN_LIFETIME.from_now
    )
    [session, token]
  end

  # Returns the session for a presented Bearer token, or nil when the token
  # is unknown, expired, or has been revoked (deleted).
  def self.authenticate(token)
    return nil if token.blank?

    session = find_by(token_digest: digest(token))
    return nil if session.nil? || session.expires_at <= Time.current

    session
  end

  def self.digest(token)
    Digest::SHA256.hexdigest(token.to_s)
  end
end
