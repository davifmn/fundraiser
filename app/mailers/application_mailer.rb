class ApplicationMailer < ActionMailer::Base
  default from: ENV.fetch("MAIL_FROM", "Fundraiser <donations@example.org>")
  layout "mailer"
  helper ApplicationHelper
end
