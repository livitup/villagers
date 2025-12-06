# frozen_string_literal: true

require "test_helper"

class ConferenceReportsControllerTest < ActionDispatch::IntegrationTest
  def setup
    @village = Village.create!(name: "Test Village", setup_complete: true)
    @conference = Conference.create!(
      name: "Test Conference",
      village: @village,
      start_date: Date.current,
      end_date: Date.current + 3.days,
      conference_hours_start: Time.zone.parse("2000-01-01 09:00"),
      conference_hours_end: Time.zone.parse("2000-01-01 17:00")
    )
    @program = Program.create!(name: "Test Program", max_volunteers: 2, village: @village)
    @conference_program = ConferenceProgram.create!(
      conference: @conference,
      program: @program,
      max_volunteers: 2,
      day_schedules: { "0" => { "enabled" => true, "start_time" => "09:00", "end_time" => "12:00" } }
    )

    @village_admin = User.create!(
      email: "admin@test.com",
      password: "password123",
      password_confirmation: "password123"
    )
    village_admin_role = Role.find_or_create_by!(name: Role::VILLAGE_ADMIN)
    UserRole.find_or_create_by!(user: @village_admin, role: village_admin_role)
    @village_admin.reload

    @conference_lead = User.create!(
      email: "lead@test.com",
      password: "password123",
      password_confirmation: "password123"
    )
    ConferenceRole.create!(
      user: @conference_lead,
      conference: @conference,
      role_name: ConferenceRole::CONFERENCE_LEAD
    )

    @regular_user = User.create!(
      email: "regular@test.com",
      password: "password123",
      password_confirmation: "password123"
    )
  end

  # Index (reports landing page)
  test "reports index requires authentication" do
    get conference_reports_path(@conference)
    assert_redirected_to new_user_session_path
  end

  test "regular users cannot access reports" do
    sign_in @regular_user
    get conference_reports_path(@conference)
    assert_redirected_to root_path
  end

  test "conference lead can access reports index" do
    sign_in @conference_lead
    get conference_reports_path(@conference)
    assert_response :success
  end

  test "village admin can access reports index" do
    sign_in @village_admin
    get conference_reports_path(@conference)
    assert_response :success
  end

  # Shift assignments report
  test "shift assignments report shows volunteers assigned to shifts" do
    timeslot = @conference_program.timeslots.first
    VolunteerSignup.create!(user: @regular_user, timeslot: timeslot)

    sign_in @village_admin
    get shift_assignments_conference_reports_path(@conference)
    assert_response :success
    assert_match @regular_user.email, response.body
  end

  test "shift assignments report can be exported as CSV" do
    timeslot = @conference_program.timeslots.first
    VolunteerSignup.create!(user: @regular_user, timeslot: timeslot)

    sign_in @village_admin
    get shift_assignments_conference_reports_path(@conference, format: :csv)
    assert_response :success
    assert_equal "text/csv", response.content_type.split(";").first
  end

  # Unmanned shifts report
  test "unmanned shifts report shows shifts below capacity" do
    sign_in @village_admin
    get unmanned_shifts_conference_reports_path(@conference)
    assert_response :success
  end

  test "unmanned shifts report can be exported as CSV" do
    sign_in @village_admin
    get unmanned_shifts_conference_reports_path(@conference, format: :csv)
    assert_response :success
    assert_equal "text/csv", response.content_type.split(";").first
  end

  # Filtering
  test "shift assignments can be filtered by program" do
    sign_in @village_admin
    get shift_assignments_conference_reports_path(@conference, program_id: @program.id)
    assert_response :success
  end

  test "shift assignments can be filtered by date" do
    sign_in @village_admin
    get shift_assignments_conference_reports_path(@conference, date: Date.current.to_s)
    assert_response :success
  end

  test "unmanned shifts can be filtered by program" do
    sign_in @village_admin
    get unmanned_shifts_conference_reports_path(@conference, program_id: @program.id)
    assert_response :success
  end

  test "unmanned shifts can be filtered by date" do
    sign_in @village_admin
    get unmanned_shifts_conference_reports_path(@conference, date: Date.current.to_s)
    assert_response :success
  end
end
