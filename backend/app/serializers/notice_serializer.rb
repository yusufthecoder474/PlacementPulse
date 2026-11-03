# Shapes a notice exactly as the API contract requires.
#
# - source_text is included ONLY when include_source: true, which the
#   controller sets only for coordinators. Students never see it.
# - eligibility and registration are computed for students; for
#   coordinators the contract allows a neutral placeholder, so the shape
#   stays identical and the frontend never has to nil-check.
class NoticeSerializer
  def self.call(notice, current_user: nil, include_source: false)
    data = {
      id: notice.id,
      company: notice.company,
      category: notice.category,
      drive_date: notice.drive_date&.to_s,
      eligible_branches: notice.eligible_branches || [],
      minimum_cgpa: notice.minimum_cgpa&.to_f,
      minimum_class_x_percentage: notice.minimum_class_x_percentage&.to_f,
      minimum_class_xii_percentage: notice.minimum_class_xii_percentage&.to_f,
      arrears_rule: notice.arrears_rule,
      ctc: notice.ctc,
      stipend: notice.stipend,
      registration_deadline: notice.registration_deadline&.iso8601,
      registration_url: notice.registration_url,
      location: notice.location,
      status: notice.status
    }

    if current_user&.student?
      data[:eligibility] = EligibilityChecker.call(user: current_user, notice: notice)
      registration = Registration.find_by(user: current_user, notice: notice)
      data[:registration] = registration_json(registration)
    else
      data[:eligibility] = { status: "needs_clarification", reasons: [] }
      data[:registration] = { status: "not_registered", registered_at: nil }
    end

    data[:source_text] = notice.source_text if include_source
    data
  end

  def self.registration_json(registration)
    if registration
      { status: registration.status, registered_at: registration.registered_at&.iso8601 }
    else
      { status: "not_registered", registered_at: nil }
    end
  end
end
