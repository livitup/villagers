require "test_helper"

class LeaderboardControllerTest < ActionDispatch::IntegrationTest
  setup do
    @village = Village.create!(name: "Test Village", setup_complete: true)
    @conference = Conference.create!(
      name: "Test Conference",
      city: "Test City", state: "NV", country: "US",
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
    @top_volunteer = User.create!(
      email: "top@example.com",
      password: "password123",
      password_confirmation: "password123",
      name: "Top Volunteer"
    )
    # Create signups for leaderboard
    VolunteerSignup.create!(user: @top_volunteer, timeslot: @cp.timeslots.first)
    VolunteerSignup.create!(user: @top_volunteer, timeslot: @cp.timeslots.second)
    VolunteerSignup.create!(user: @user, timeslot: @cp.timeslots.third)
  end

  test "should get index when signed in" do
    sign_in @user
    get leaderboard_index_url
    assert_response :success
  end

  test "should redirect to login when not signed in" do
    get leaderboard_index_url
    assert_redirected_to new_user_session_path
  end

  test "index displays top volunteers" do
    sign_in @user
    get leaderboard_index_url
    assert_response :success
    assert_select "table" do
      assert_select "tr", minimum: 2 # header + at least one row
    end
  end

  test "should get conference leaderboard" do
    sign_in @user
    get conference_leaderboard_url(@conference)
    assert_response :success
  end

  test "conference leaderboard displays volunteers for that conference" do
    sign_in @user
    get conference_leaderboard_url(@conference)
    assert_response :success
    assert_match @top_volunteer.name, response.body
  end
end
