class Reminder < ApplicationRecord
  belongs_to :user
  belongs_to :notice

  KINDS = %w[publication reminder_24h reminder_2h].freeze

  validates :kind, inclusion: { in: KINDS }
  validates :scheduled_at, presence: true
  validates :user_id, uniqueness: { scope: %i[notice_id kind] }

  scope :unsent, -> { where(sent_at: nil) }
  scope :due, -> { where("scheduled_at <= ?", Time.current) }

  def sent?
    sent_at.present?
  end
end
