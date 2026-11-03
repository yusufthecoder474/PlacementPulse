class Notice < ApplicationRecord
  belongs_to :publisher, class_name: "User", optional: true, inverse_of: :published_notices
  has_many :registrations, dependent: :destroy
  has_many :reminders, dependent: :destroy

  ARREARS_RULES = %w[no_standing_arrears standing_arrears_allowed].freeze

  # Fields the coordinator must either fill in or explicitly confirm as
  # "no requirement" (via unrestricted_fields) before publication.
  REQUIRED_FIELDS = %w[
    company category drive_date eligible_branches
    minimum_cgpa minimum_class_x_percentage minimum_class_xii_percentage
    arrears_rule ctc stipend registration_deadline registration_url location
  ].freeze

  validates :status, inclusion: { in: %w[draft published] }
  validates :arrears_rule, inclusion: { in: ARREARS_RULES }, allow_nil: true
  validates :minimum_cgpa, numericality: { greater_than_or_equal_to: 0, less_than_or_equal_to: 10 },
                           allow_nil: true
  validates :minimum_class_x_percentage, numericality: { greater_than_or_equal_to: 0, less_than_or_equal_to: 100 },
                                         allow_nil: true
  validates :minimum_class_xii_percentage, numericality: { greater_than_or_equal_to: 0, less_than_or_equal_to: 100 },
                                           allow_nil: true
  validates :registration_url,
            format: { with: %r{\Ahttps?://\S+\z}, message: "must be an http(s) URL" },
            allow_blank: true

  scope :published, -> { where(status: "published") }

  def published?
    status == "published"
  end

  def draft?
    status == "draft"
  end

  # A field counts as missing when it is nil, blank, or (for branches) empty.
  def field_missing?(field)
    value = public_send(field)
    value.nil? || (value.respond_to?(:empty?) && value.empty?)
  end

  # Uncertainties that currently block publication: every required field that
  # is missing AND has not been coordinator-confirmed as unrestricted.
  # Each entry is { "field" => ..., "message" => ... }.
  def publish_blocking_uncertainties
    REQUIRED_FIELDS.filter_map do |field|
      next unless field_missing?(field)
      next if unrestricted_fields&.include?(field)

      { "field" => field, "message" => "#{field.humanize} is missing and has not been confirmed as having no requirement." }
    end
  end

  def publishable?
    publish_blocking_uncertainties.empty?
  end
end
