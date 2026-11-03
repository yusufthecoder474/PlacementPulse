require "rails_helper"

RSpec.describe PublishNotificationsJob, type: :job do
  it "creates publication reminders only for eligible students" do
    eligible = create(:user)
    ineligible = create(:user, branch: "MECH")
    notice = create(:notice, :published, registration_deadline: 5.days.from_now)

    described_class.perform_now(notice.id)

    expect(Reminder.find_by(user: eligible, notice: notice, kind: "publication")).to be_present
    expect(Reminder.find_by(user: ineligible, notice: notice, kind: "publication")).to be_nil
  end

  it "schedules 24h and 2h reminders in the future" do
    student = create(:user)
    deadline = 5.days.from_now
    notice = create(:notice, :published, registration_deadline: deadline)

    described_class.perform_now(notice.id)

    expect(Reminder.find_by(user: student, notice: notice, kind: "reminder_24h").scheduled_at)
      .to be_within(1.minute).of(deadline - 24.hours)
    expect(Reminder.find_by(user: student, notice: notice, kind: "reminder_2h").scheduled_at)
      .to be_within(1.minute).of(deadline - 2.hours)
  end

  it "does not duplicate reminder rows on a duplicate publish" do
    create(:user)
    notice = create(:notice, :published, registration_deadline: 5.days.from_now)

    described_class.perform_now(notice.id)
    expect do
      described_class.perform_now(notice.id)
    end.not_to change(Reminder, :count)
  end

  it "does nothing for a draft notice" do
    create(:user)
    notice = create(:notice)
    described_class.perform_now(notice.id)
    expect(Reminder.count).to eq(0)
  end

  it "does not schedule reminders whose time is already in the past" do
    create(:user)
    notice = create(:notice, :published, registration_deadline: 1.hour.from_now)

    described_class.perform_now(notice.id)

    expect(Reminder.where(notice: notice, kind: "reminder_24h")).to be_empty
    expect(Reminder.where(notice: notice, kind: "reminder_2h")).to be_empty
    expect(Reminder.find_by(notice: notice, kind: "publication")).to be_present
  end
end

RSpec.describe ReminderScheduler, type: :service do
  it "replaces unsent reminders on deadline change but keeps sent ones" do
    student = create(:user)
    notice = create(:notice, :published, registration_deadline: 5.days.from_now)
    PublishNotificationsJob.perform_now(notice.id)

    sent = Reminder.find_by!(notice: notice, kind: "reminder_24h")
    sent.update!(sent_at: Time.current)
    old_unsent = Reminder.find_by!(notice: notice, kind: "reminder_2h")

    notice.update!(registration_deadline: 10.days.from_now)
    ReminderScheduler.reschedule_for_notice(notice)

    expect(Reminder.find_by(id: sent.id)).to be_present
    expect(Reminder.find_by(id: old_unsent.id)).to be_nil
    expect(Reminder.find_by(notice: notice, kind: "reminder_2h").scheduled_at)
      .to be_within(1.minute).of(10.days.from_now - 2.hours)
  end
end
