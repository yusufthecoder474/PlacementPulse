class NoticeMailer < ApplicationMailer
  # @param reminder [Reminder] the reminder row being delivered
  def publication_notification(reminder)
    @reminder = reminder
    @notice = reminder.notice
    @user = reminder.user
    mail(to: @user.email, subject: subject_line("New placement opportunity"))
  end

  def reminder(reminder)
    @reminder = reminder
    @notice = reminder.notice
    @user = reminder.user
    kind_label = reminder.kind == "reminder_24h" ? "24 hours" : "2 hours"
    mail(to: @user.email, subject: subject_line("Registration closes in #{kind_label}"))
  end

  private

  def subject_line(prefix)
    deadline = @notice.registration_deadline&.in_time_zone("Asia/Kolkata")&.strftime("%d %b %Y, %I:%M %p")
    "#{prefix}: #{@notice.company}#{deadline ? " — registration deadline #{deadline}" : ''}"
  end
end
