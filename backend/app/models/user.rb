class User < ApplicationRecord
  has_secure_password

  has_many :sessions, dependent: :destroy
  has_many :published_notices, class_name: "Notice", foreign_key: :publisher_id,
                               dependent: :nullify, inverse_of: :publisher
  has_many :registrations, dependent: :destroy
  has_many :reminders, dependent: :destroy

  before_validation :normalize_email

  validates :email, presence: true,
                    format: { with: URI::MailTo::EMAIL_REGEXP },
                    uniqueness: { case_sensitive: false }
  validates :role, inclusion: { in: %w[student coordinator] }
  validates :cgpa, numericality: { greater_than_or_equal_to: 0, less_than_or_equal_to: 10 },
                   allow_nil: true
  validates :class_x_percentage, numericality: { greater_than_or_equal_to: 0, less_than_or_equal_to: 100 },
                                 allow_nil: true
  validates :class_xii_percentage, numericality: { greater_than_or_equal_to: 0, less_than_or_equal_to: 100 },
                                   allow_nil: true

  def student?
    role == "student"
  end

  def coordinator?
    role == "coordinator"
  end

  # A profile is usable for eligibility only when every academic field the
  # engine checks is present. Standing arrears is a boolean with a default,
  # so it is always present.
  def profile_complete?
    branch.present? && cgpa.present? && class_x_percentage.present? && class_xii_percentage.present?
  end

  private

  def normalize_email
    self.email = email.to_s.strip.downcase
  end
end
