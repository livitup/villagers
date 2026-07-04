require "test_helper"

class NotificationMailerTest < ActionMailer::TestCase
  setup do
    # Create a village with email enabled for mailer tests
    Village.destroy_all
    @village = Village.create!(
      name: "Test Village",
      setup_complete: true,
      email_enabled: true,
      mailgun_api_key: "test-key",
      mailgun_domain: "test.mailgun.org"
    )

    @user = User.create!(
      email: "user@example.com",
      password: "password123",
      password_confirmation: "password123",
      handle: "Test User"
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

  test "notification_email sends to correct recipient" do
    email = NotificationMailer.notification_email(
      user: @user,
      title: "Test Title",
      body: "Test body",
      notification_type: Notification::SYSTEM
    )

    assert_equal [ @user.email ], email.to
  end

  test "notification_email has correct subject with village name" do
    email = NotificationMailer.notification_email(
      user: @user,
      title: "Test Title",
      body: "Test body",
      notification_type: Notification::SYSTEM
    )

    assert_equal "[#{@village.name}] Test Title", email.subject
  end

  test "notification_email body contains title and body" do
    email = NotificationMailer.notification_email(
      user: @user,
      title: "Test Title",
      body: "Test notification body content",
      notification_type: Notification::SYSTEM
    )

    assert_match "Test Title", email.html_part.body.to_s
    assert_match "Test notification body content", email.html_part.body.to_s
    assert_match "Test Title", email.text_part.body.to_s
    assert_match "Test notification body content", email.text_part.body.to_s
  end

  test "notification_email body contains user greeting" do
    email = NotificationMailer.notification_email(
      user: @user,
      title: "Test Title",
      body: "Test body",
      notification_type: Notification::SYSTEM
    )

    assert_match @user.display_name, email.html_part.body.to_s
    assert_match @user.display_name, email.text_part.body.to_s
  end

  test "notification_email uses email when user has no handle" do
    @user.update!(handle: "")
    email = NotificationMailer.notification_email(
      user: @user,
      title: "Test Title",
      body: "Test body",
      notification_type: Notification::SYSTEM
    )

    assert_match @user.email, email.html_part.body.to_s
    assert_match @user.email, email.text_part.body.to_s
  end
end
