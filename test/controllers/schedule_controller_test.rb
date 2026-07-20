require "test_helper"

# The schedule is the coverage view (#244); the legacy grid is retired.
# Detailed behavior is covered in schedule_coverage_test, schedule_triage_test,
# and schedule_board_test — this file keeps the route smokes and the
# legacy-URL redirect.
class ScheduleControllerTest < ActionDispatch::IntegrationTest
  setup do
    @village = Village.create!(name: "Test Village", setup_complete: true)
    @village_admin = User.create!(
      email: "admin@example.com",
      password: "password123",
      password_confirmation: "password123"
    )
    @volunteer = User.create!(
      email: "volunteer@example.com",
      password: "password123",
      password_confirmation: "password123"
    )
    @conference_lead = User.create!(
      email: "lead@example.com",
      password: "password123",
      password_confirmation: "password123"
    )

    village_admin_role = Role.find_or_create_by!(name: Role::VILLAGE_ADMIN)
    UserRole.create!(user: @village_admin, role: village_admin_role)

    @conference = Conference.create!(
      village: @village,
      name: "Test Conference",
      start_date: Date.tomorrow,
      end_date: Date.tomorrow + 2.days,
      conference_hours_start: "09:00",
      conference_hours_end: "17:00"
    )

    ConferenceRole.create!(
      user: @conference_lead,
      conference: @conference,
      role_name: ConferenceRole::CONFERENCE_LEAD
    )

    @conference_program = ConferenceProgram.create!(
      conference: @conference,
      program: Program.create!(name: "Test Program", village: @village),
      day_schedules: { "0" => { "enabled" => true, "start" => "09:00", "end" => "11:00" } }
    )
  end

  test "schedule renders the coverage view for a volunteer" do
    sign_in @volunteer
    get conference_schedule_url(@conference)

    assert_response :success
    assert_select ".coverage-card", text: /Test Program/
    assert_select ".coverage-ribbon"
  end

  test "schedule renders for village admin and conference lead with the board link" do
    [ @village_admin, @conference_lead ].each do |manager|
      sign_in manager
      get conference_schedule_url(@conference)
      assert_response :success
      assert_select "a[href=?]", conference_schedule_board_path(@conference)
    end
  end

  test "volunteers get no board link" do
    sign_in @volunteer
    get conference_schedule_url(@conference)
    assert_select "a[href=?]", conference_schedule_board_path(@conference), count: 0
  end

  test "the old coverage URL redirects to the schedule, preserving filters" do
    sign_in @volunteer
    day = (@conference.start_date + 1.day).iso8601

    get conference_schedule_coverage_url(@conference, day: day, hide_full: "1")

    assert_redirected_to conference_schedule_path(@conference, day: day, hide_full: "1")
  end

  test "should redirect to login when not authenticated" do
    get conference_schedule_url(@conference)
    assert_redirected_to new_user_session_path
  end
end
