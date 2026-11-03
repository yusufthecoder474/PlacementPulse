# Creates (and, on deadline change, recreates) the 24h and 2h reminder
# rows for every currently eligible student of a published notice, and
# enqueues their delivery jobs at the scheduled times.
#
# Reminder rows are created with find-or-create against the unique
# (user, notice, kind) index, so calling this twice never duplicates rows.
# Only a newly created row gets a delivery job enqueued.
class ReminderScheduler
  REMINDER_OFFSETS = { "reminder_24h" => 24.hours, "reminder_2h" => 2.hours }.freeze

  def self.schedule_for_notice(notice)
    return unless notice.published? && notice.registration_deadline.present?

    User.where(role: "student").find_each do |student|
      next unless EligibilityChecker.call(user: student, notice: notice)[:status] == "eligible"

      REMINDER_OFFSETS.each do |kind, offset|
        at = notice.registration_deadline - offset
        next unless at.future?

        reminder = find_or_create_reminder(student, notice, kind, at)
        ReminderDeliveryJob.set(wait_until: at).perform_later(reminder.id) if reminder.previously_new_record?
      end
    end
  end

  # Deletes only unsent future-reminder rows (already-sent reminders are
  # history and must not be rewritten), then schedules fresh rows against
  # the notice's current deadline.
  def self.reschedule_for_notice(notice)
    notice.reminders.unsent.where(kind: REMINDER_OFFSETS.keys).delete_all
    schedule_for_notice(notice)
  end

  def self.find_or_create_reminder(student, notice, kind, at)
    Reminder.where(user: student, notice: notice, kind: kind).first_or_create do |reminder|
      reminder.scheduled_at = at
    end
  rescue ActiveRecord::RecordNotUnique
    # Two workers raced on the same row; the unique index kept one of them.
    Reminder.find_by!(user: student, notice: notice, kind: kind)
  end
end
