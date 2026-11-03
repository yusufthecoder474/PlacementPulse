# Pure eligibility engine. Used by the student dashboard, the eligibility
# endpoint, and Sidekiq notification targeting, so all three always agree.
#
# EligibilityChecker.call(user:, notice:) returns
#   { status: "eligible" | "not_eligible" | "needs_clarification",
#     reasons: [{ field:, code:, message: }, ...] }
#
# Rules:
# - Boundaries are inclusive: a student value exactly equal to a minimum
#   passes (for example, CGPA 7.5 meets a 7.5 minimum).
# - A definite failure wins over an uncertainty: if the branch already
#   disqualifies the student, the result is "not_eligible" even if another
#   rule is unconfirmed.
# - A required notice field that is nil and not coordinator-confirmed as
#   unrestricted (unrestricted_fields) yields "needs_clarification", never
#   an assumption of "no requirement".
# - A required student profile value that is missing also yields
#   "needs_clarification".
# - An unpublished notice is never "eligible" through this checker.
class EligibilityChecker
  FIELD_LABELS = {
    "eligible_branches" => "eligible branches",
    "minimum_cgpa" => "minimum CGPA",
    "minimum_class_x_percentage" => "minimum Class X percentage",
    "minimum_class_xii_percentage" => "minimum Class XII percentage",
    "arrears_rule" => "arrears rule"
  }.freeze

  PROFILE_LABELS = {
    "eligible_branches" => "branch",
    "minimum_cgpa" => "CGPA",
    "minimum_class_x_percentage" => "Class X percentage",
    "minimum_class_xii_percentage" => "Class XII percentage"
  }.freeze

  def self.call(user:, notice:)
    new(user, notice).call
  end

  def initialize(user, notice)
    @user = user
    @notice = notice
    @reasons = []
    @failed = false
    @unclear = false
  end

  def call
    if !@notice.published?
      return {
        status: "needs_clarification",
        reasons: [{ field: "status", code: "unpublished_notice",
                    message: "This notice has not been published yet." }]
      }
    end

    check_branch
    check_minimum(:minimum_cgpa, @user.cgpa, "CGPA")
    check_minimum(:minimum_class_x_percentage, @user.class_x_percentage, "Class X percentage")
    check_minimum(:minimum_class_xii_percentage, @user.class_xii_percentage, "Class XII percentage")
    check_arrears

    status = @failed ? "not_eligible" : (@unclear ? "needs_clarification" : "eligible")
    { status: status, reasons: @reasons }
  end

  private

  def unrestricted?(field)
    @notice.unrestricted_fields&.include?(field.to_s)
  end

  # Returns true when the check can proceed (requirement present, or the
  # field is unrestricted). Otherwise records a clarification reason.
  def requirement_present?(field)
    value = @notice.public_send(field)
    return true unless value.nil? || (value.respond_to?(:empty?) && value.empty?)
    return true if unrestricted?(field)

    @unclear = true
    @reasons << { field: field.to_s, code: "unconfirmed_#{field}",
                  message: "#{FIELD_LABELS[field.to_s]} has not been confirmed by the coordinator." }
    false
  end

  def profile_present?(field, value)
    return true unless value.nil?

    @unclear = true
    @reasons << { field: field.to_s, code: "missing_profile",
                  message: "Your #{PROFILE_LABELS[field.to_s]} is not set in your profile." }
    false
  end

  def check_branch
    return unless requirement_present?(:eligible_branches)
    return if unrestricted?(:eligible_branches)
    return unless profile_present?(:eligible_branches, @user.branch)

    unless @notice.eligible_branches.include?(@user.branch)
      @failed = true
      @reasons << { field: "eligible_branches", code: "branch_not_included",
                    message: "Branch #{@user.branch} is not in the eligible branches (#{@notice.eligible_branches.join(', ')})." }
    end
  end

  def check_minimum(field, student_value, label)
    return unless requirement_present?(field)
    return if unrestricted?(field)
    return unless profile_present?(field, student_value)

    minimum = @notice.public_send(field)
    if student_value < minimum
      @failed = true
      @reasons << { field: field.to_s, code: "#{field}_below_minimum",
                    message: "#{label} #{format_number(student_value)} is below the minimum #{format_number(minimum)}." }
    end
  end

  def check_arrears
    return unless requirement_present?(:arrears_rule)
    return if unrestricted?(:arrears_rule)

    if @user.standing_arrears && @notice.arrears_rule == "no_standing_arrears"
      @failed = true
      @reasons << { field: "arrears_rule", code: "standing_arrears_prohibited",
                    message: "Standing arrears are not allowed for this notice." }
    end
  end

  def format_number(value)
    text = value.to_s
    text.sub(/\.0+\z/, "")
  end
end
