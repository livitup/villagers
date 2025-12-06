require "test_helper"

class VolunteerHistoryControllerTest < ActionDispatch::IntegrationTest
  setup do
    @village = Village.create!(name: "Test Village", setup_complete: true)
    @conference1 = Conference.create!(
      name: "Conference 2024",
      location: "Test Location",
      start_date: Date.today + 1.day,
      end_date: Date.today + 2.days,
      conference_hours_start: Time.zone.parse("2000-01-01 09:00"),
      conference_hours_end: Time.zone.parse("2000-01-01 17:00"),
      village: @village
    )
    @conference2 = Conference.create!(
      name: "Conference 2023",
      location: "Test Location 2",
      start_date: Date.today + 10.days,
      end_date: Date.today + 11.days,
      conference_hours_start: Time.zone.parse("2000-01-01 09:00"),
      conference_hours_end: Time.zone.parse("2000-01-01 17:00"),
      village: @village
    )
    @program = Program.create!(
      name: "Test Program",
      description: "A test program",
      village: @village
    )
    @cp1 = ConferenceProgram.create!(
      conference: @conference1,
      program: @program,
      day_schedules: {
        "0" => { "enabled" => true, "start" => "09:00", "end" => "10:00" }
      }
    )
    @cp2 = ConferenceProgram.create!(
      conference: @conference2,
      program: @program,
      day_schedules: {
        "0" => { "enabled" => true, "start" => "09:00", "end" => "10:00" }
      }
    )
    @user = User.create!(
      email: "volunteer@example.com",
      password: "password123",
      password_confirmation: "password123",
      name: "Test Volunteer"
    )
    # Create signups
    VolunteerSignup.create!(user: @user, timeslot: @cp1.timeslots.first)
    VolunteerSignup.create!(user: @user, timeslot: @cp1.timeslots.second)
    VolunteerSignup.create!(user: @user, timeslot: @cp2.timeslots.first)
  end

  test "should get index when signed in" do
    sign_in @user
    get volunteer_history_index_url
    assert_response :success
  end

  test "should redirect to login when not signed in" do
    get volunteer_history_index_url
    assert_redirected_to new_user_session_path
  end

  test "index displays user statistics" do
    sign_in @user
    get volunteer_history_index_url
    assert_response :success
    # Should display total shifts
    assert_match(/3/, response.body) # 3 total shifts
  end

  test "index displays conferences participated" do
    sign_in @user
    get volunteer_history_index_url
    assert_response :success
    assert_match @conference1.name, response.body
    assert_match @conference2.name, response.body
  end

  test "should get show for specific conference" do
    sign_in @user
    get volunteer_history_url(@conference1)
    assert_response :success
  end

  test "show displays shifts for specific conference" do
    sign_in @user
    get volunteer_history_url(@conference1)
    assert_response :success
    assert_match @conference1.name, response.body
    assert_match @program.name, response.body
  end
end
