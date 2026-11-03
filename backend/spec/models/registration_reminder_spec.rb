require "rails_helper"

RSpec.describe Registration, type: :model do
  it "enforces one registration per student per notice at the database level" do
    registration = create(:registration)
    duplicate = build(:registration, user: registration.user, notice: registration.notice)
    expect(duplicate).not_to be_valid
    expect do
      duplicate.save!(validate: false)
    end.to raise_error(ActiveRecord::RecordNotUnique)
  end
end

RSpec.describe Reminder, type: :model do
  it "enforces one reminder per student, notice, and kind at the database level" do
    reminder = create(:reminder)
    duplicate = build(:reminder, user: reminder.user, notice: reminder.notice, kind: reminder.kind)
    expect(duplicate).not_to be_valid
    expect do
      duplicate.save!(validate: false)
    end.to raise_error(ActiveRecord::RecordNotUnique)
  end

  it "rejects an unknown reminder kind" do
    expect(build(:reminder, kind: "weekly")).not_to be_valid
  end
end

RSpec.describe Session, type: :model do
  it "authenticates a token, and rejects expired and revoked sessions" do
    user = create(:user)
    session, token = Session.create_for(user)

    expect(Session.authenticate(token)).to eq(session)
    # The stored digest is not the token itself.
    expect(session.token_digest).not_to eq(token)

    session.update!(expires_at: 1.hour.ago)
    expect(Session.authenticate(token)).to be_nil

    _session2, token2 = Session.create_for(user)
    Session.find_by(token_digest: Session.digest(token2)).destroy
    expect(Session.authenticate(token2)).to be_nil
  end
end
