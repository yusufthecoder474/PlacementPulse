class Registration < ApplicationRecord
  belongs_to :user
  belongs_to :notice

  validates :status, inclusion: { in: %w[registered] }
  validates :user_id, uniqueness: { scope: :notice_id }

  before_create :stamp_registered_at

  private

  def stamp_registered_at
    self.registered_at ||= Time.current
  end
end
