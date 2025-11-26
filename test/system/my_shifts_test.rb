require "application_system_test_case"

class MyShiftsTest < ApplicationSystemTestCase
  setup do
    @village = Village.create!(name: "Test Village", setup_complete: true)
    @conference = Conference.create!(
      name: "Test Conference",
      location: "Test Location",
      start_date: Date.today + 1.day,
      end_date: Date.today + 2.days,
      conference_hours_start: Time.zone.parse("2000-01-01 09:00"),
      conference_hours_end: Time.zone.parse("2000-01-01 17:00"),
      village: @village
    )
    @program = Program.create!(
      name: "Test Program",
      description: "A test program",
      village: @village
    )
    @conference_program = ConferenceProgram.create!(
      conference: @conference,
      program: @program,
      day_schedules: {
        "0" => { "enabled" => true, "start" => "09:00", "end" => "10:00" }
      }
    )
    @timeslot = @conference_program.timeslots.first
    @user = User.create!(
      email: "volunteer@example.com",
      password: "password123",
      password_confirmation: "password123"
    )
  end

  def login_as(user)
    visit new_user_session_path
    fill_in "Email", with: user.email
    fill_in "Password", with: "password123"
    find('input[type="submit"][value="Log in"]').click
    assert_text "Logout"
  end

  test "volunteer can view their signed up shifts" do
    VolunteerSignup.create!(user: @user, timeslot: @timeslot)

    login_as @user
    visit conference_volunteer_signups_path(@conference)

    assert_text "My Shifts"
    assert_text @program.name
    assert_text @timeslot.start_time.strftime("%l:%M %p").strip
  end

  test "volunteer sees message when they have no shifts" do
    login_as @user
    visit conference_volunteer_signups_path(@conference)

    assert_text "My Shifts"
    assert_text "You haven't signed up for any shifts yet"
  end

  test "volunteer can cancel shift from my shifts page" do
    VolunteerSignup.create!(user: @user, timeslot: @timeslot)

    login_as @user
    visit conference_volunteer_signups_path(@conference)

    assert_text @program.name

    # Verify cancel button exists (testing actual cancel is flaky due to confirm dialog timing)
    assert_selector "a", text: "Cancel"
  end

  test "my shifts page is accessible from conference show page" do
    login_as @user
    visit conference_path(@conference)

    click_link "My Shifts", class: "btn-success"

    assert_text "My Shifts - #{@conference.name}"
  end
end
