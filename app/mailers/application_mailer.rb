class ApplicationMailer < ActionMailer::Base
  default from: -> { default_from_address }

  layout "mailer"

  private

  def default_from_address
    ENV.fetch("MAILER_FROM_ADDRESS", "notifications@example.com")
  end
end
