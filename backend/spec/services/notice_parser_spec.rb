require "rails_helper"

# All notice texts below are SYNTHETIC fixtures invented for these tests.
RSpec.describe NoticeParser, type: :service do
  let(:well_formatted) do
    <<~NOTICE
      Company: Acme Technologies
      Category: Software Development Engineer
      Drive Date: 10 Feb 2027
      Eligible Branches: CSE, ECE, IT
      Minimum CGPA: 7.5
      Class X: 75%
      Class XII: 70%
      No standing arrears.
      CTC: 12 LPA
      Stipend: ₹30,000/month
      Registration deadline: 20 Jan 2027, 11:59 PM
      Register at: https://example.com/acme-register
      Location: Bengaluru
    NOTICE
  end

  it "extracts every field from a well-formatted notice" do
    result = described_class.call(well_formatted)
    parsed = result[:parsed]

    expect(parsed[:company]).to eq("Acme Technologies")
    expect(parsed[:category]).to eq("Software Development Engineer")
    expect(parsed[:drive_date]).to eq(Date.new(2027, 2, 10))
    expect(parsed[:eligible_branches]).to eq(%w[CSE ECE IT])
    expect(parsed[:minimum_cgpa]).to eq(7.5)
    expect(parsed[:minimum_class_x_percentage]).to eq(75.0)
    expect(parsed[:minimum_class_xii_percentage]).to eq(70.0)
    expect(parsed[:arrears_rule]).to eq("no_standing_arrears")
    expect(parsed[:ctc]).to eq("12 LPA")
    expect(parsed[:stipend]).to eq("₹30,000/month")
    expect(parsed[:registration_deadline]).to eq(Time.zone.local(2027, 1, 20, 23, 59))
    expect(parsed[:registration_url]).to eq("https://example.com/acme-register")
    expect(parsed[:location]).to eq("Bengaluru")
    expect(result[:uncertainties]).to be_empty
  end

  it "flags a missing CGPA instead of treating it as unrestricted" do
    text = well_formatted.gsub("Minimum CGPA: 7.5\n", "")
    result = described_class.call(text)

    expect(result[:parsed][:minimum_cgpa]).to be_nil
    expect(result[:uncertainties].map { |u| u[:field] }).to include("minimum_cgpa")
  end

  it "flags multiple distinct deadline dates and keeps the first" do
    text = well_formatted + "Note: registration deadline extended to 25 Jan 2027.\n"
    result = described_class.call(text)

    expect(result[:parsed][:registration_deadline]).to eq(Time.zone.local(2027, 1, 20, 23, 59))
    expect(result[:uncertainties].map { |u| u[:field] }).to include("registration_deadline")
  end

  it "treats a deadline date with no time as 23:59 Asia/Kolkata" do
    text = well_formatted.gsub("Registration deadline: 20 Jan 2027, 11:59 PM", "Registration deadline: 20 Jan 2027")
    result = described_class.call(text)

    expect(result[:parsed][:registration_deadline]).to eq(Time.zone.local(2027, 1, 20, 23, 59))
  end

  it "parses ISO and month-first date formats" do
    iso = well_formatted.gsub("Drive Date: 10 Feb 2027", "Drive Date: 2027-02-10")
    expect(described_class.call(iso)[:parsed][:drive_date]).to eq(Date.new(2027, 2, 10))

    us = well_formatted.gsub("Drive Date: 10 Feb 2027", "Drive Date: Feb 10, 2027")
    expect(described_class.call(us)[:parsed][:drive_date]).to eq(Date.new(2027, 2, 10))
  end

  it "expands 'all branches' to the full branch list" do
    text = well_formatted.gsub("Eligible Branches: CSE, ECE, IT", "Eligible Branches: All branches")
    expect(described_class.call(text)[:parsed][:eligible_branches]).to eq(NoticeParser::ALL_BRANCHES)
  end

  it "maps branch synonyms and flags unknown abbreviations" do
    text = well_formatted.gsub("Eligible Branches: CSE, ECE, IT",
                               "Eligible Branches: Computer Science and Engineering, ECE, XYZ")
    result = described_class.call(text)

    expect(result[:parsed][:eligible_branches]).to eq(%w[CSE ECE])
    expect(result[:uncertainties].map { |u| u[:field] }).to include("eligible_branches")
  end

  it "extracts multiple branches" do
    text = well_formatted.gsub("Eligible Branches: CSE, ECE, IT", "Eligible Branches: CSE, ECE, IT, MECH")
    expect(described_class.call(text)[:parsed][:eligible_branches]).to eq(%w[CSE ECE IT MECH])
  end

  it "assigns each percentage to the correct school level" do
    text = well_formatted.gsub("Class X: 75%\nClass XII: 70%", "Class X: 75%, Class XII: 70%")
    result = described_class.call(text)

    expect(result[:parsed][:minimum_class_x_percentage]).to eq(75.0)
    expect(result[:parsed][:minimum_class_xii_percentage]).to eq(70.0)
  end

  it "flags different percentages for different courses" do
    text = well_formatted.gsub("Class X: 75%", "For CSE, Class X: 75%\nFor ECE, Class X: 70%")
    result = described_class.call(text)

    expect(result[:uncertainties].map { |u| u[:field] }).to include("minimum_class_x_percentage")
  end

  it "parses arrears variants and flags unclear wording" do
    allowed = well_formatted.gsub("No standing arrears.", "Backlogs allowed.")
    expect(described_class.call(allowed)[:parsed][:arrears_rule]).to eq("standing_arrears_allowed")

    none = well_formatted.gsub("No standing arrears.", "No backlogs.")
    expect(described_class.call(none)[:parsed][:arrears_rule]).to eq("no_standing_arrears")

    unclear = well_formatted.gsub("No standing arrears.", "Backlog policy will be shared later.")
    result = described_class.call(unclear)
    expect(result[:parsed][:arrears_rule]).to be_nil
    expect(result[:uncertainties].map { |u| u[:field] }).to include("arrears_rule")
  end

  it "returns nil plus an uncertainty for a malformed registration URL" do
    text = well_formatted.gsub("Register at: https://example.com/acme-register", "Registration link: not-a-url")
    result = described_class.call(text)

    expect(result[:parsed][:registration_url]).to be_nil
    expect(result[:uncertainties].map { |u| u[:field] }).to include("registration_url")
  end

  it "still parses an expired deadline (downstream jobs, not the parser, skip it)" do
    text = well_formatted.gsub("Registration deadline: 20 Jan 2027, 11:59 PM", "Registration deadline: 20 Jan 2020, 11:59 PM")
    result = described_class.call(text)

    expect(result[:parsed][:registration_deadline]).to be < Time.current
    expect(result[:uncertainties].map { |u| u[:field] }).not_to include("registration_deadline")
  end

  it "returns uncertainties for empty and unexpected input" do
    empty = described_class.call("")
    # Every scalar field is nil; branches use [] as their "missing" value.
    expect(empty[:parsed].except(:eligible_branches).values.compact).to be_empty
    expect(empty[:parsed][:eligible_branches]).to eq([])
    expect(empty[:uncertainties]).not_to be_empty

    garbage = described_class.call("hello world, this is not a placement notice")
    expect(garbage[:parsed][:company]).to be_nil
    expect(garbage[:uncertainties]).not_to be_empty
  end
end
