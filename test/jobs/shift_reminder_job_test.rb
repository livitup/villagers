require "test_helper"

class ShiftReminderJobTest < ActiveJob::TestCase
  include ActionMailer::TestHelper

  setup do
    @village = Village.create!(
      name: "Test Village",
      setup_complete: true,
      email_enabled: true,
      mailgun_api_key: "test-key",
      mailgun_domain: "test.mailgun.org",
      reminder_hours_before: 24
    )
    @user = User.create!(
      email: "volunteer@example.com",
      password: "password123",
      password_confirmation: "password123",
      handle: "Test Volunteer"
    )
    @conference = Conference.create!(
      village: @village,
      name: "Test Conference",
      start_date: Date.tomorrow,
      end_date: Date.tomorrow + 2.days,
      conference_hours_start: "09:00",
      conference_hours_end: "17:00"
    )
    @program = Program.create!(name: "Test Program", village: @village)
    @conference_program = ConferenceProgram.create!(
      conference: @conference,
      program: @program
    )
  end

  test "sends reminder for shifts within reminder window" do
    # Create a timeslot 12 hours from now (within 24-hour window)
    timeslot = Timeslot.create!(
      conference_program: @conference_program,
      start_time: 12.hours.from_now,
      max_volunteers: 5
    )
    signup = VolunteerSignup.create!(user: @user, timeslot: timeslot)

    assert_emails 1 do
      ShiftReminderJob.perform_now
    end

    signup.reload
    assert_not_nil signup.reminder_sent_at
  end

  test "does not send reminder for shifts outside reminder window" do
    # Create a timeslot 36 hours from now (outside 24-hour window)
    timeslot = Timeslot.create!(
      conference_program: @conference_program,
      start_time: 36.hours.from_now,
      max_volunteers: 5
    )
    VolunteerSignup.create!(user: @user, timeslot: timeslot)

    assert_emails 0 do
      ShiftReminderJob.perform_now
    end
  end

  test "does not send reminder if already sent" do
    timeslot = Timeslot.create!(
      conference_program: @conference_program,
      start_time: 12.hours.from_now,
      max_volunteers: 5
    )
    VolunteerSignup.create!(
      user: @user,
      timeslot: timeslot,
      reminder_sent_at: 1.hour.ago
    )

    assert_emails 0 do
      ShiftReminderJob.perform_now
    end
  end

  test "does not send reminder for past shifts" do
    timeslot = Timeslot.create!(
      conference_program: @conference_program,
      start_time: 1.hour.ago,
      max_volunteers: 5
    )
    VolunteerSignup.create!(user: @user, timeslot: timeslot)

    assert_emails 0 do
      ShiftReminderJob.perform_now
    end
  end

  test "uses conference-specific reminder hours when set" do
    @conference.update!(reminder_hours_before: 6)

    # 8 hours from now - outside 6-hour window
    timeslot = Timeslot.create!(
      conference_program: @conference_program,
      start_time: 8.hours.from_now,
      max_volunteers: 5
    )
    VolunteerSignup.create!(user: @user, timeslot: timeslot)

    assert_emails 0 do
      ShiftReminderJob.perform_now
    end
  end

  test "sends single email for multiple consecutive timeslots" do
    # Create 4 consecutive 15-minute timeslots (1 hour shift)
    base_time = 12.hours.from_now
    4.times do |i|
      timeslot = Timeslot.create!(
        conference_program: @conference_program,
        start_time: base_time + (i * 15).minutes,
        max_volunteers: 5
      )
      VolunteerSignup.create!(user: @user, timeslot: timeslot)
    end

    # Should send only 1 email, not 4
    assert_emails 1 do
      ShiftReminderJob.perform_now
    end
  end

  test "does not send reminder when email is disabled" do
    @village.update!(email_enabled: false)

    timeslot = Timeslot.create!(
      conference_program: @conference_program,
      start_time: 12.hours.from_now,
      max_volunteers: 5
    )
    VolunteerSignup.create!(user: @user, timeslot: timeslot)

    assert_emails 0 do
      ShiftReminderJob.perform_now
    end
  end
end
