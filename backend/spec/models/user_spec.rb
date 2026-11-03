require "rails_helper"

RSpec.describe User, type: :model do
  it "hashes the password and never stores it in plaintext" do
    user = create(:user, password: "password1234")
    expect(user.password_digest).not_to eq("password1234")
    expect(user.authenticate("password1234")).to eq(user)
    expect(user.authenticate("wrong")).to be(false)
  end

  it "rejects an invalid role" do
    user = build(:user, role: "admin")
    expect(user).not_to be_valid
  end

  it "rejects a CGPA outside 0..10" do
    expect(build(:user, cgpa: 10.5)).not_to be_valid
    expect(build(:user, cgpa: -0.1)).not_to be_valid
  end

  it "rejects percentages outside 0..100" do
    expect(build(:user, class_x_percentage: 101)).not_to be_valid
  end

  it "enforces case-insensitive email uniqueness in the database" do
    create(:user, email: "Student@Example.com")
    duplicate = build(:user, email: "student@example.com")
    expect(duplicate).not_to be_valid

    # The lower() unique index is the backstop if validations are bypassed.
    expect do
      duplicate.save!(validate: false)
    end.to raise_error(ActiveRecord::RecordNotUnique)
  end
end
