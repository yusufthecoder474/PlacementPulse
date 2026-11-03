# Runs when a notice is published. For every student whose eligibility is
# "eligible" (recomputed here, not trusted from the request), it creates a
# publication reminder row and enqueues its delivery, then schedules the
# 24h/2h reminders through ReminderScheduler.
#
# Safe to run twice: reminder rows are find-or-created against the unique
# (user, notice, kind) index, so a duplicate publish creates no duplicate
# rows, and ReminderDeliveryJob skips rows that are already sent.
class PublishNotificationsJob < ApplicationJob
  queue_as :default

  def perform(notice_id)
    notice = Notice.find_by(id: notice_id)
    return unless notice&.published?

    User.where(role: "student").find_each do |student|
      next unless EligibilityChecker.call(user: student, notice: notice)[:status] == "eligible"

      reminder = ReminderScheduler.find_or_create_reminder(student, notice, "publication", Time.current)
      ReminderDeliveryJob.perform_later(reminder.id) if reminder.previously_new_record?
    end

    ReminderScheduler.schedule_for_notice(notice)
  end
end
