class NotificationMailerPreview < ActionMailer::Preview
  # Preview: http://localhost:3000/rails/mailers/notification_mailer/test_email
  def test_email
    user = User.first || User.new(email: "preview@example.com", handle: "Preview User")
    NotificationMailer.test_email(user)
  end

  # Preview: http://localhost:3000/rails/mailers/notification_mailer/notification_email
  def notification_email
    user = User.first || User.new(email: "preview@example.com", handle: "Preview User")

    NotificationMailer.notification_email(
      user: user,
      title: "Shift Signup Confirmed",
      body: "You've signed up for a Test Program shift at Test Conference on January 15, 2025 at 9:00 AM.",
      notification_type: "shift_signup"
    )
  end
end
