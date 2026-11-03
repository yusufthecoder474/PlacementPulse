require "rails_helper"

RSpec.describe ReminderDeliveryJob, type: :job do
  let(:student) { create(:user) }
  let(:notice) { create(:notice, :published, registration_deadline: 5.days.from_now) }
  let(:reminder) { create(:reminder, user: student, notice: notice) }

  it "delivers the email and records sent_at" do
    expect do
      described_class.perform_now(reminder.id)
    end.to change(ActionMailer::Base.deliveries, :count).by(1)

    expect(reminder.reload.sent_at).to be_present
    expect(ActionMailer::Base.deliveries.last.subject).to include("Acme Technologies")
  end

  it "does not resend on repeated execution" do
    described_class.perform_now(reminder.id)
    expect do
      described_class.perform_now(reminder.id)
    end.not_to change(ActionMailer::Base.deliveries, :count)
  end

  it "suppresses delivery when the student has registered" do
    create(:registration, user: student, notice: notice)
    expect do
      described_class.perform_now(reminder.id)
    end.not_to change(ActionMailer::Base.deliveries, :count)
    expect(reminder.reload.sent_at).to be_nil
  end

  it "skips delivery after the deadline has passed" do
    notice.update!(registration_deadline: 1.hour.ago)
    expect do
      described_class.perform_now(reminder.id)
    end.not_to change(ActionMailer::Base.deliveries, :count)
  end

  it "skips delivery when the notice is no longer published" do
    notice.update!(status: "draft")
    expect do
      described_class.perform_now(reminder.id)
    end.not_to change(ActionMailer::Base.deliveries, :count)
  end

  it "records a failure and re-raises so Sidekiq retries" do
    allow(NoticeMailer).to receive(:publication_notification).and_raise(StandardError, "SMTP down")

    expect do
      described_class.perform_now(reminder.id)
    end.to raise_error(StandardError, "SMTP down")

    reminder.reload
    expect(reminder.failed_at).to be_present
    expect(reminder.error_message).to include("SMTP down")
    expect(reminder.sent_at).to be_nil
  end
end
