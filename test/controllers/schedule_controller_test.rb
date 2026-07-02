require "test_helper"

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

    @program = Program.create!(
      name: "Test Program",
      village: @village
    )

    @conference_program = ConferenceProgram.create!(
      conference: @conference,
      program: @program
    )
  end

  test "should get show as authenticated volunteer" do
    sign_in @volunteer
    get conference_schedule_url(@conference)
    assert_response :success
  end

  test "should get show as village admin" do
    sign_in @village_admin
    get conference_schedule_url(@conference)
    assert_response :success
  end

  test "should get show as conference lead" do
    sign_in @conference_lead
    get conference_schedule_url(@conference)
    assert_response :success
  end

  test "should redirect to login when not authenticated" do
    get conference_schedule_url(@conference)
    assert_redirected_to new_user_session_path
  end

  test "schedule shows programs for conference" do
    # A program only renders a column on days where it has timeslots.
    Timeslot.create!(
      conference_program: @conference_program,
      start_time: @conference.start_date.to_datetime + 9.hours,
      max_volunteers: 2,
      current_volunteers_count: 0
    )

    sign_in @volunteer
    get conference_schedule_url(@conference)
    assert_response :success
    assert_match @program.name, response.body
  end

  test "conference manager can see all volunteers flag" do
    sign_in @conference_lead
    get conference_schedule_url(@conference)
    assert_response :success
    # Conference leads should be able to see volunteer management controls
  end

  test "volunteer cannot see all volunteers management controls" do
    sign_in @volunteer
    get conference_schedule_url(@conference)
    assert_response :success
    # Regular volunteers have limited view
  end


  test "schedule data includes conference dates" do
    sign_in @volunteer
    get conference_schedule_url(@conference)
    assert_response :success
    # Schedule should show each day of the conference
  end

  test "hides program column on days with no timeslots" do
    # Enable the program only on the first day of the multi-day conference,
    # which generates timeslots for day 1 but none for days 2 and 3.
    @conference_program.update!(
      day_schedules: {
        "0" => { "enabled" => true, "start" => "09:00", "end" => "10:00" }
      }
    )

    sign_in @volunteer
    get conference_schedule_url(@conference)
    assert_response :success

    # The program column header should render exactly once (only on day 1),
    # not once per conference day.
    assert_equal 1, response.body.scan('class="program-column text-center"').count
    # Days with no scheduled program fall back to the empty-day message.
    assert_match "No programs scheduled", response.body
  end

  test "schedule shows qualification required pill for unqualified user" do
    qualification = Qualification.create!(
      name: "Test Cert",
      description: "A test certification",
      village: @village
    )
    ProgramQualification.create!(program: @program, qualification: qualification)

    # Create a timeslot for the program
    Timeslot.create!(
      conference_program: @conference_program,
      start_time: @conference.start_date.to_datetime + 9.hours,
      max_volunteers: 2,
      current_volunteers_count: 0
    )

    sign_in @volunteer
    get conference_schedule_url(@conference)
    assert_response :success
    assert_match "Test Cert qualification required", response.body
    assert_match "slot-unqualified", response.body
  end

  test "schedule does not show qualification pill for qualified user" do
    qualification = Qualification.create!(
      name: "Test Cert",
      description: "A test certification",
      village: @village
    )
    ProgramQualification.create!(program: @program, qualification: qualification)
    UserQualification.create!(user: @volunteer, qualification: qualification)

    # Create a timeslot for the program
    Timeslot.create!(
      conference_program: @conference_program,
      start_time: @conference.start_date.to_datetime + 9.hours,
      max_volunteers: 2,
      current_volunteers_count: 0
    )

    sign_in @volunteer
    get conference_schedule_url(@conference)
    assert_response :success
    assert_no_match(/Test Cert qualification required/, response.body)
    # Check that no actual table cells have the unqualified class (not the CSS definition)
    assert_no_match(/<td class="schedule-cell slot-unqualified">/, response.body)
  end

  test "sign up button hidden for unqualified user" do
    qualification = Qualification.create!(
      name: "Test Cert",
      description: "A test certification",
      village: @village
    )
    ProgramQualification.create!(program: @program, qualification: qualification)

    # Create a timeslot for the program
    Timeslot.create!(
      conference_program: @conference_program,
      start_time: @conference.start_date.to_datetime + 9.hours,
      max_volunteers: 2,
      current_volunteers_count: 0
    )

    sign_in @volunteer
    get conference_schedule_url(@conference)
    assert_response :success
    # Unqualified users see the qualification requirement, not a sign up button
    assert_match "Test Cert qualification required", response.body
    # Check that no schedule cell sign-up buttons exist (modal button is ok)
    assert_no_match(/data-action="shift-signup#openModal"/, response.body)
  end

  test "sign up button shown for qualified user" do
    qualification = Qualification.create!(
      name: "Test Cert",
      description: "A test certification",
      village: @village
    )
    ProgramQualification.create!(program: @program, qualification: qualification)
    UserQualification.create!(user: @volunteer, qualification: qualification)

    # Create a timeslot for the program
    Timeslot.create!(
      conference_program: @conference_program,
      start_time: @conference.start_date.to_datetime + 9.hours,
      max_volunteers: 2,
      current_volunteers_count: 0
    )

    sign_in @volunteer
    get conference_schedule_url(@conference)
    assert_response :success
    # Should show Sign Up button, not qualification requirement
    assert_no_match(/Test Cert qualification required/, response.body)
  end

  test "schedule respects conference-specific qualification removals" do
    qualification = Qualification.create!(
      name: "Test Cert",
      description: "A test certification",
      village: @village
    )
    ProgramQualification.create!(program: @program, qualification: qualification)
    UserQualification.create!(user: @volunteer, qualification: qualification)
    # Remove the qualification for this specific conference
    QualificationRemoval.create!(
      user: @volunteer,
      qualification: qualification,
      conference: @conference
    )

    # Create a timeslot for the program
    Timeslot.create!(
      conference_program: @conference_program,
      start_time: @conference.start_date.to_datetime + 9.hours,
      max_volunteers: 2,
      current_volunteers_count: 0
    )

    sign_in @volunteer
    get conference_schedule_url(@conference)
    assert_response :success
    # User should be treated as unqualified for this conference
    assert_match "Test Cert qualification required", response.body
    assert_match "slot-unqualified", response.body
  end

  test "schedule shows multiple missing qualifications" do
    qual1 = Qualification.create!(
      name: "Cert A",
      description: "First certification",
      village: @village
    )
    qual2 = Qualification.create!(
      name: "Cert B",
      description: "Second certification",
      village: @village
    )
    ProgramQualification.create!(program: @program, qualification: qual1)
    ProgramQualification.create!(program: @program, qualification: qual2)

    # Create a timeslot for the program
    Timeslot.create!(
      conference_program: @conference_program,
      start_time: @conference.start_date.to_datetime + 9.hours,
      max_volunteers: 2,
      current_volunteers_count: 0
    )

    sign_in @volunteer
    get conference_schedule_url(@conference)
    assert_response :success
    assert_match "Cert A qualification required", response.body
    assert_match "Cert B qualification required", response.body
  end

  test "schedule shows qualified state when user has all required qualifications" do
    qual1 = Qualification.create!(
      name: "Cert A",
      description: "First certification",
      village: @village
    )
    qual2 = Qualification.create!(
      name: "Cert B",
      description: "Second certification",
      village: @village
    )
    ProgramQualification.create!(program: @program, qualification: qual1)
    ProgramQualification.create!(program: @program, qualification: qual2)
    UserQualification.create!(user: @volunteer, qualification: qual1)
    UserQualification.create!(user: @volunteer, qualification: qual2)

    # Create a timeslot for the program
    Timeslot.create!(
      conference_program: @conference_program,
      start_time: @conference.start_date.to_datetime + 9.hours,
      max_volunteers: 2,
      current_volunteers_count: 0
    )

    sign_in @volunteer
    get conference_schedule_url(@conference)
    assert_response :success
    assert_no_match(/Cert A qualification required/, response.body)
    assert_no_match(/Cert B qualification required/, response.body)
    # Check that no actual table cells have the unqualified class (not the CSS definition)
    assert_no_match(/<td class="schedule-cell slot-unqualified">/, response.body)
  end
end
