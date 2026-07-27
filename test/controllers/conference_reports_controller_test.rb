require "test_helper"

class ConferenceReportsControllerTest < ActionDispatch::IntegrationTest
  setup do
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

  # Optional profile columns (#261)
  test "shift assignments CSV includes requested profile columns" do
    @regular_user.update!(handle: "Radio Ray", callsign: "W1AW", discord: "ray#1234", signal: "@ray.01")
    VolunteerSignup.create!(user: @regular_user, timeslot: @conference_program.timeslots.first)

    sign_in @village_admin
    get shift_assignments_conference_reports_path(@conference, format: :csv, columns: [ "discord", "callsign", "signal" ])

    # Columns render in canonical order regardless of param order.
    header, row = response.body.lines.first(2)
    assert_match(/Callsign,Signal,Discord/, header)
    refute_match(/Phone/, header)
    assert_match(/W1AW,@ray.01,ray#1234/, row)
  end

  test "shift assignments CSV keeps its default columns when none are requested" do
    VolunteerSignup.create!(user: @regular_user, timeslot: @conference_program.timeslots.first)

    sign_in @village_admin
    get shift_assignments_conference_reports_path(@conference, format: :csv)

    header = response.body.lines.first
    assert_match(/Date,Time,Program,Volunteer Name,Volunteer Email/, header)
    refute_match(/Callsign|Phone|Twitter|Signal|Discord/, header)
  end

  test "shift assignments ignores unknown column names" do
    VolunteerSignup.create!(user: @regular_user, timeslot: @conference_program.timeslots.first)

    sign_in @village_admin
    get shift_assignments_conference_reports_path(@conference, format: :csv, columns: [ "encrypted_password", "callsign" ])

    header = response.body.lines.first
    assert_match(/Callsign/, header)
    refute_match(/password/i, header)
  end

  test "shift assignments HTML table shows the selected profile columns" do
    @regular_user.update!(phone: "+1 555 0100", twitter: "@ray")
    VolunteerSignup.create!(user: @regular_user, timeslot: @conference_program.timeslots.first)

    sign_in @village_admin
    get shift_assignments_conference_reports_path(@conference, columns: [ "phone", "twitter" ])

    assert_response :success
    assert_select "th", text: "Phone"
    assert_select "th", text: "Twitter"
    assert_select "td", text: "+1 555 0100"
    assert_select "td", text: "@ray"
    assert_select "th", text: "Callsign", count: 0
  end

  test "shift assignments Export CSV link carries the selected columns" do
    sign_in @village_admin
    get shift_assignments_conference_reports_path(@conference, columns: [ "discord" ])

    assert_select "a[href*='columns%5B%5D=discord']", text: "Export CSV"
  end

  # Unmanned shifts report
  test "unmanned shifts report shows shifts below capacity" do
    sign_in @village_admin
    get unmanned_shifts_conference_reports_path(@conference)
    assert_response :success
  end

  test "unmanned shifts keys off min_volunteers, not max" do
    at_min   = @conference_program.timeslots.order(:start_time).first
    below    = @conference_program.timeslots.order(:start_time).second
    at_min.update!(min_volunteers: 1, max_volunteers: 2, current_volunteers_count: 1)
    below.update!(min_volunteers: 2, max_volunteers: 2, current_volunteers_count: 1)
    @conference_program.timeslots.where.not(id: [ at_min.id, below.id ])
                       .update_all(min_volunteers: 1, current_volunteers_count: 1)

    sign_in @village_admin
    get unmanned_shifts_conference_reports_path(@conference, format: :csv)

    lines = response.body.lines
    assert_equal 2, lines.size, "only the below-min shift should be listed:\n#{response.body}"
    assert_includes lines.last, below.start_time.strftime("%H:%M")
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
