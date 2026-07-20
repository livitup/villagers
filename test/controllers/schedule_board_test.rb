require "test_helper"

# Admin coverage board (#243): every manageable activity x every conference
# day at a glance, with a manage panel (roster / add / remove / needed) wired
# to the #242 bulk endpoints.
class ScheduleBoardTest < ActionDispatch::IntegrationTest
  setup do
    @village = Village.create!(name: "Test Village", setup_complete: true)
    @conference = Conference.create!(
      village: @village,
      name: "Test Conference",
      start_date: Date.tomorrow,
      end_date: Date.tomorrow + 1.day,
      conference_hours_start: "09:00",
      conference_hours_end: "17:00"
    )
    @day1 = @conference.start_date
    @exams = ConferenceProgram.create!(
      conference: @conference,
      program: Program.create!(name: "Ham Exams", village: @village),
      day_schedules: {
        "0" => { "enabled" => true, "start" => "09:00", "end" => "11:00" },
        "1" => { "enabled" => true, "start" => "09:00", "end" => "10:00" }
      }
    )
    @desk = ConferenceProgram.create!(
      conference: @conference,
      program: Program.create!(name: "Front Desk", village: @village),
      day_schedules: { "0" => { "enabled" => true, "start" => "09:00", "end" => "10:00" } }
    )
    @desk.timeslots.each { |slot| slot.update_column(:current_volunteers_count, 1) }

    @admin = create_user("admin@example.com", handle: "Admin")
    UserRole.create!(user: @admin, role: Role.find_or_create_by!(name: Role::VILLAGE_ADMIN))
    @volunteer = create_user("volunteer@example.com", handle: "Radio Ray")
    @volunteer.update!(callsign: "W1AW")
  end

  def create_user(email, handle:)
    User.create!(email: email, password: "password123", password_confirmation: "password123", handle: handle)
  end

  test "board shows a row per activity and a cell per day with coverage states" do
    sign_in @admin
    get conference_schedule_board_path(@conference)

    assert_response :success
    assert_select ".board-row", 2
    assert_select ".board-row", text: /Ham Exams/
    assert_select ".board-row", text: /Front Desk/
    # Ham Exams: scheduled both days, bare both days. Front Desk: day 1 covered, day 2 not scheduled.
    assert_select ".board-cell .badge.text-bg-danger", 2
    assert_select ".board-cell .badge.text-bg-success", 1
    assert_match(/not scheduled/i, response.body)
  end

  test "each scheduled cell links to the manage panel for that activity and day" do
    sign_in @admin
    get conference_schedule_board_path(@conference)

    assert_select ".board-cell a[href=?]",
                  conference_schedule_board_path(@conference, manage: @exams.id, day: @day1.iso8601)
  end

  test "an activity lead sees only their activity's row" do
    lead = create_user("lead@example.com", handle: "Lead")
    ConferenceProgramRole.create!(user: lead, conference_program: @exams, role_name: ConferenceProgramRole::ACTIVITY_LEAD)
    sign_in lead

    get conference_schedule_board_path(@conference)

    assert_response :success
    assert_select ".board-row", 1
    assert_select ".board-row", text: /Ham Exams/
  end

  test "a plain volunteer is turned away" do
    sign_in @volunteer
    get conference_schedule_board_path(@conference)

    assert_response :redirect
  end

  test "the manage panel shows the roster as display names with ranged remove buttons" do
    slots = @exams.timeslots.where(start_time: @day1.in_time_zone.all_day).order(:start_time).to_a
    slots.first(3).each { |slot| VolunteerSignup.create!(user: @volunteer, timeslot: slot) }

    sign_in @admin
    get conference_schedule_board_path(@conference, manage: @exams.id, day: @day1.iso8601)

    assert_select ".manage-panel", text: /Radio Ray \(W1AW\)/
    assert_select ".manage-panel", text: /9:00 AM\s*–\s*9:45 AM/
    # Remove form posts the exact window of the range.
    assert_select ".manage-panel form input[name='start_timeslot_id'][value='#{slots.first.id}']"
    assert_select ".manage-panel form input[name='duration_minutes'][value='45']"
    refute_match @volunteer.email, css_select(".manage-panel").first.to_s
  end

  test "the manage panel's add form lists users by display name and offers the day's start times" do
    sign_in @admin
    get conference_schedule_board_path(@conference, manage: @exams.id, day: @day1.iso8601)

    assert_select ".manage-panel form[action=?]", bulk_add_volunteer_conference_timeslots_path(@conference)
    assert_select ".manage-panel select[name='user_id'] option", text: "Radio Ray (W1AW)"
    first_slot = @exams.timeslots.where(start_time: @day1.in_time_zone.all_day).order(:start_time).first
    assert_select ".manage-panel select[name='start_timeslot_id'] option[value='#{first_slot.id}']", text: /9:00 AM/
  end

  test "the manage panel carries the needed-today editor with the current value" do
    sign_in @admin
    get conference_schedule_board_path(@conference, manage: @exams.id, day: @day1.iso8601)

    assert_select ".manage-panel form[action=?]", bulk_update_capacity_conference_timeslots_path(@conference)
    assert_select ".manage-panel input[name='max_volunteers'][value='1']"
  end

  test "an activity lead cannot open the manage panel for someone else's activity" do
    lead = create_user("lead@example.com", handle: "Lead")
    ConferenceProgramRole.create!(user: lead, conference_program: @exams, role_name: ConferenceProgramRole::ACTIVITY_LEAD)
    sign_in lead

    get conference_schedule_board_path(@conference, manage: @desk.id, day: @day1.iso8601)

    assert_response :redirect
  end

  test "managers get a board link on the coverage view; volunteers do not" do
    sign_in @admin
    get conference_schedule_path(@conference)
    assert_select "a[href=?]", conference_schedule_board_path(@conference)

    sign_in @volunteer
    get conference_schedule_path(@conference)
    assert_select "a[href=?]", conference_schedule_board_path(@conference), count: 0
  end
end
