# Delivers one reminder row exactly once as far as the database can tell.
#
# Guards, checked at execution time (not at enqueue time, because state
# changes between scheduling and delivery):
# - already sent -> skip silently (makes retries and duplicate runs safe);
# - student has since registered -> skip;
# - notice is no longer published -> skip;
# - deadline has passed -> skip (a late-running reminder is worse than none).
#
# On delivery failure, failed_at/error_message are recorded and the error
# is re-raised so Sidekiq retries with backoff.
#
# Honest limitation: this guards duplicate reminder ROWS and duplicate
# delivery attempts, but it cannot guarantee exactly-once EMAIL delivery.
# If the worker crashes after the mailer sends but before sent_at is
# recorded, a retry can send the email a second time. See README.
class ReminderDeliveryJob < ApplicationJob
  queue_as :default

  def perform(reminder_id)
    reminder = Reminder.find_by(id: reminder_id)
    return if reminder.nil? || reminder.sent_at.present?
    return if Registration.exists?(user: reminder.user, notice: reminder.notice)

    notice = reminder.notice
    return unless notice.published?
    return if notice.registration_deadline.present? && notice.registration_deadline.past?

    mailer = reminder.kind == "publication" ? NoticeMailer.publication_notification(reminder) : NoticeMailer.reminder(reminder)
    mailer.deliver_now
    reminder.update!(sent_at: Time.current, failed_at: nil, error_message: nil)
  rescue StandardError => e
    reminder&.update!(failed_at: Time.current, error_message: "#{e.class}: #{e.message}") if reminder&.persisted?
    raise
  end
end
