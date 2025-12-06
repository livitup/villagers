require "test_helper"

class NotificationMailerTest < ActionMailer::TestCase
  setup do
    @user = User.create!(
      email: "user@example.com",
      password: "password123",
      password_confirmation: "password123",
      name: "Test User"
    )
  end

  test "test_email sends to correct recipient" do
    email = NotificationMailer.test_email(@user)

    assert_equal [ @user.email ], email.to
  end

  test "test_email has correct subject" do
    email = NotificationMailer.test_email(@user)

    assert_equal "Villagers Email Test", email.subject
  end

  test "test_email has correct from address" do
    email = NotificationMailer.test_email(@user)

    assert_includes email.from, "notifications@example.com"
  end

  test "test_email body contains user greeting" do
    email = NotificationMailer.test_email(@user)

    assert_match "Test User", email.html_part.body.to_s
    assert_match "Test User", email.text_part.body.to_s
  end

  test "test_email body contains confirmation message" do
    email = NotificationMailer.test_email(@user)

    assert_match "email delivery is working", email.html_part.body.to_s
    assert_match "email delivery is working", email.text_part.body.to_s
  end

  test "test_email is enqueued when delivered later" do
    assert_enqueued_emails 1 do
      NotificationMailer.test_email(@user).deliver_later
    end
  end

  test "test_email is delivered when deliver_now called" do
    assert_emails 1 do
      NotificationMailer.test_email(@user).deliver_now
    end
  end
end
