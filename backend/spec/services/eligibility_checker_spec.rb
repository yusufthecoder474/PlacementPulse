require "rails_helper"

RSpec.describe EligibilityChecker, type: :service do
  let(:notice) { create(:notice, :published) }
  let(:student) { create(:user) }

  it "marks a fully qualifying student eligible with no reasons" do
    result = described_class.call(user: student, notice: notice)
    expect(result[:status]).to eq("eligible")
    expect(result[:reasons]).to be_empty
  end

  it "passes a student exactly at every threshold (inclusive boundary)" do
    student.update!(cgpa: 7.5, class_x_percentage: 75, class_xii_percentage: 70)
    result = described_class.call(user: student, notice: notice)
    expect(result[:status]).to eq("eligible")
  end

  it "reports an exact CGPA failure message" do
    student.update!(cgpa: 7.2)
    result = described_class.call(user: student, notice: notice)

    expect(result[:status]).to eq("not_eligible")
    expect(result[:reasons].map { |r| r[:message] }).to include("CGPA 7.2 is below the minimum 7.5.")
  end

  it "rejects a branch outside the eligible list" do
    student.update!(branch: "MECH")
    result = described_class.call(user: student, notice: notice)

    expect(result[:status]).to eq("not_eligible")
    expect(result[:reasons].map { |r| r[:code] }).to include("branch_not_included")
  end

  it "rejects a Class XII percentage below the minimum" do
    student.update!(class_xii_percentage: 69)
    result = described_class.call(user: student, notice: notice)
    expect(result[:status]).to eq("not_eligible")
  end

  it "rejects standing arrears when the notice prohibits them" do
    student.update!(standing_arrears: true)
    result = described_class.call(user: student, notice: notice)

    expect(result[:status]).to eq("not_eligible")
    expect(result[:reasons].map { |r| r[:code] }).to include("standing_arrears_prohibited")
  end

  it "allows standing arrears when the notice allows them" do
    notice.update!(arrears_rule: "standing_arrears_allowed")
    student.update!(standing_arrears: true)
    expect(described_class.call(user: student, notice: notice)[:status]).to eq("eligible")
  end

  it "needs clarification when the student profile is incomplete" do
    incomplete = create(:user, :incomplete_profile)
    result = described_class.call(user: incomplete, notice: notice)

    expect(result[:status]).to eq("needs_clarification")
    expect(result[:reasons].map { |r| r[:code] }).to include("missing_profile")
  end

  it "needs clarification for an unconfirmed requirement, never assumes it away" do
    notice.update!(minimum_cgpa: nil)
    result = described_class.call(user: student, notice: notice)

    expect(result[:status]).to eq("needs_clarification")
    expect(result[:reasons].map { |r| r[:code] }).to include("unconfirmed_minimum_cgpa")
  end

  it "skips a requirement the coordinator confirmed as unrestricted" do
    notice.update!(minimum_cgpa: nil, unrestricted_fields: ["minimum_cgpa"])
    expect(described_class.call(user: student, notice: notice)[:status]).to eq("eligible")
  end

  it "needs clarification for an empty eligible-branches list" do
    notice.update!(eligible_branches: [])
    result = described_class.call(user: student, notice: notice)

    expect(result[:status]).to eq("needs_clarification")
    expect(result[:reasons].map { |r| r[:code] }).to include("unconfirmed_eligible_branches")
  end

  it "needs clarification for an unpublished notice" do
    draft = create(:notice)
    result = described_class.call(user: student, notice: draft)

    expect(result[:status]).to eq("needs_clarification")
    expect(result[:reasons].map { |r| r[:code] }).to include("unpublished_notice")
  end
end
