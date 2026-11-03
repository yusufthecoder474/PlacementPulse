# Action Mailer delivery configuration. No credentials are hardcoded here.
# - test:        Rails' :test delivery (emails accumulate in
#                ActionMailer::Base.deliveries; nothing is sent).
# - development: file delivery to tmp/mails, unless SMTP_* env vars are set.
# - production:  SMTP from env vars.
unless Rails.env.test?
  if ENV["SMTP_ADDRESS"].present?
    ActionMailer::Base.delivery_method = :smtp
    ActionMailer::Base.smtp_settings = {
      address: ENV.fetch("SMTP_ADDRESS"),
      port: ENV.fetch("SMTP_PORT", "587").to_i,
      user_name: ENV["SMTP_USERNAME"],
      password: ENV["SMTP_PASSWORD"],
      domain: ENV["SMTP_DOMAIN"],
      authentication: ENV["SMTP_USERNAME"].present? ? "plain" : nil,
      enable_starttls_auto: true
    }
  elsif Rails.env.development?
    ActionMailer::Base.delivery_method = :file
    ActionMailer::Base.file_settings = { location: Rails.root.join("tmp/mails") }
  else
    ActionMailer::Base.delivery_method = :smtp
    ActionMailer::Base.smtp_settings = {
      address: ENV.fetch("SMTP_ADDRESS", "localhost"),
      port: ENV.fetch("SMTP_PORT", "25").to_i,
      user_name: ENV["SMTP_USERNAME"],
      password: ENV["SMTP_PASSWORD"]
    }
  end
end
