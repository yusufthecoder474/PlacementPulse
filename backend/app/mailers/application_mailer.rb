class ApplicationMailer < ActionMailer::Base
  default from: ENV.fetch("MAILER_FROM", "PlacementPulse <no-reply@placementpulse.local>")
  layout "mailer"
end
