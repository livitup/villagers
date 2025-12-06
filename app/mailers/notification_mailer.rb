class NotificationMailer < ApplicationMailer
  def test_email(user)
    @user = user
    mail(
      to: user.email,
      subject: "Villagers Email Test"
    )
  end
end
