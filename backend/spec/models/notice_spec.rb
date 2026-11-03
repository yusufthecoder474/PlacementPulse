require "rails_helper"

RSpec.describe Notice, type: :model do
  it "rejects a non-http(s) registration URL" do
    notice = build(:notice, registration_url: "ftp://example.com/register")
    expect(notice).not_to be_valid
  end

  it "rejects an unknown arrears rule" do
    notice = build(:notice, arrears_rule: "sometimes")
    expect(notice).not_to be_valid
  end

  it "blocks publication when a required field is missing and unconfirmed" do
    notice = build(:notice, minimum_cgpa: nil)
    blocking = notice.publish_blocking_uncertainties
    expect(blocking.map { |u| u["field"] }).to include("minimum_cgpa")
    expect(notice.publishable?).to be(false)
  end

  it "allows publication when the missing field is coordinator-confirmed" do
    notice = build(:notice, minimum_cgpa: nil, unrestricted_fields: ["minimum_cgpa"])
    expect(notice.publishable?).to be(true)
  end

  it "enforces the CGPA range at the database level too" do
    notice = build(:notice, minimum_cgpa: 11)
    expect(notice).not_to be_valid
    expect do
      notice.save!(validate: false)
    end.to raise_error(ActiveRecord::StatementInvalid)
  end
end
