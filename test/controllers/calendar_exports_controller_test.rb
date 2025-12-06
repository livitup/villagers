require "test_helper"

class CalendarExportsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @village = Village.create!(name: "Test Village", setup_complete: true)
    @conference = Conference.create!(
      name: "Test Conference 2024",
      location: "Las Vegas Convention Center",
      start_date: Date.today + 1.day,
      end_date: Date.today + 2.days,
      conference_hours_start: Time.zone.parse("2000-01-01 09:00"),
      conference_hours_end: Time.zone.parse("2000-01-01 17:00"),
      village: @village
    )
    @program = Program.create!(
      name: "Registration Desk",
      description: "Help with attendee registration",
      village: @village
    )
    @cp = ConferenceProgram.create!(
      conference: @conference,
      program: @program,
      day_schedules: {
        "0" => { "enabled" => true, "start" => "09:00", "end" => "12:00" }
      }
    )
    @user = User.create!(
      email: "volunteer@example.com",
      password: "password123",
      password_confirmation: "password123",
      name: "Test Volunteer"
    )
    # Create signups for the user
    VolunteerSignup.create!(user: @user, timeslot: @cp.timeslots.first)
    VolunteerSignup.create!(user: @user, timeslot: @cp.timeslots.second)
  end

  test "should redirect to login when not signed in" do
    get conference_calendar_export_url(@conference)
    assert_redirected_to new_user_session_path
  end

  test "should get calendar export for signed in user" do
    sign_in @user
    get conference_calendar_export_url(@conference)
    assert_response :success
  end

  test "should return ICS content type" do
    sign_in @user
    get conference_calendar_export_url(@conference)
    assert_equal "text/calendar", response.content_type
  end

  test "should have correct filename in content disposition" do
    sign_in @user
    get conference_calendar_export_url(@conference)
    assert_match(/filename="volunteer_shifts_test-conference-2024/, response.headers["Content-Disposition"])
    assert_match(/\.ics"/, response.headers["Content-Disposition"])
  end

  test "should include VCALENDAR header" do
    sign_in @user
    get conference_calendar_export_url(@conference)
    assert_match "BEGIN:VCALENDAR", response.body
    assert_match "END:VCALENDAR", response.body
  end

  test "should include VEVENT for each shift" do
    sign_in @user
    get conference_calendar_export_url(@conference)
    # Should have 2 events (2 signups)
    assert_equal 2, response.body.scan("BEGIN:VEVENT").count
  end

  test "should include program name in event summary" do
    sign_in @user
    get conference_calendar_export_url(@conference)
    assert_match "Registration Desk", response.body
  end

  test "should include conference location" do
    sign_in @user
    get conference_calendar_export_url(@conference)
    assert_match "Las Vegas Convention Center", response.body
  end

  test "should only include user's own shifts" do
    other_user = User.create!(
      email: "other@example.com",
      password: "password123",
      password_confirmation: "password123",
      name: "Other Volunteer"
    )
    VolunteerSignup.create!(user: other_user, timeslot: @cp.timeslots.third)

    sign_in @user
    get conference_calendar_export_url(@conference)
    # Should only have 2 events (user's 2 signups, not other_user's signup)
    assert_equal 2, response.body.scan("BEGIN:VEVENT").count
  end

  test "should return empty calendar when user has no shifts" do
    other_user = User.create!(
      email: "noshifts@example.com",
      password: "password123",
      password_confirmation: "password123",
      name: "No Shifts User"
    )

    sign_in other_user
    get conference_calendar_export_url(@conference)
    assert_response :success
    # Should have no events
    assert_equal 0, response.body.scan("BEGIN:VEVENT").count
  end
end
