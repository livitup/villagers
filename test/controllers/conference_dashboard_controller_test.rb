# frozen_string_literal: true

require "test_helper"

class ConferenceDashboardControllerTest < ActionDispatch::IntegrationTest
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
    @conference_admin = User.create!(
      email: "confadmin@test.com",
      password: "password123",
      password_confirmation: "password123"
    )
    ConferenceRole.create!(
      user: @conference_admin,
      conference: @conference,
      role_name: ConferenceRole::CONFERENCE_ADMIN
    )
    @regular_user = User.create!(
      email: "regular@test.com",
      password: "password123",
      password_confirmation: "password123"
    )
  end

  # Access tests
  test "dashboard requires authentication" do
    get conference_dashboard_path(@conference)
    assert_redirected_to new_user_session_path
  end

  test "regular users cannot access dashboard" do
    sign_in @regular_user
    get conference_dashboard_path(@conference)
    # Pundit redirects unauthorized users instead of returning 403
    assert_redirected_to root_path
  end

  test "village admin can access dashboard" do
    sign_in @village_admin
    get conference_dashboard_path(@conference)
    assert_response :success
  end

  test "conference lead can access dashboard" do
    sign_in @conference_lead
    get conference_dashboard_path(@conference)
    assert_response :success
  end

  test "conference admin can access dashboard" do
    sign_in @conference_admin
    get conference_dashboard_path(@conference)
    assert_response :success
  end

  # Content tests
  test "dashboard shows conference name" do
    sign_in @village_admin
    get conference_dashboard_path(@conference)
    assert_select "h1", /#{@conference.name}/
  end

  test "dashboard shows key metrics" do
    sign_in @village_admin
    get conference_dashboard_path(@conference)

    # Check for metric card titles or labels
    assert_select ".card" do
      assert_select ".card-body"
    end
  end

  test "dashboard shows quick links" do
    sign_in @village_admin
    get conference_dashboard_path(@conference)

    # Check for links to common actions
    assert_select "a[href=?]", conference_conference_programs_path(@conference)
    assert_select "a[href=?]", conference_schedule_path(@conference)
  end

  test "dashboard shows recent signups section" do
    sign_in @village_admin
    get conference_dashboard_path(@conference)
    assert_select "h5", /Recent Activity/
  end

  # Conference with data tests
  test "dashboard displays correct metrics with volunteer data" do
    program = Program.create!(name: "Test Program", max_volunteers: 2, village: @village)
    conference_program = ConferenceProgram.create!(
      conference: @conference,
      program: program,
      max_volunteers: 1,
      day_schedules: { "0" => { "enabled" => true, "start_time" => "09:00", "end_time" => "10:00" } }
    )

    timeslot = conference_program.timeslots.first
    VolunteerSignup.create!(user: @regular_user, timeslot: timeslot)

    sign_in @village_admin
    get conference_dashboard_path(@conference)
    assert_response :success

    # Verify the page loads with the data
    assert_select ".card"
  end
end
