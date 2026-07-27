require "test_helper"

# Staffing timeline (#262): a horizontally-scrolling who-works-when view for
# conference managers and activity leads — one bar per contiguous volunteer
# shift, labeled with the volunteer's name and the activity.
class ScheduleTimelineTest < ActionDispatch::IntegrationTest
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
    @exams = ConferenceProgram.create!(
      conference: @conference,
      program: Program.create!(name: "Ham Exams", village: @village),
      day_schedules: { "0" => { "enabled" => true, "start" => "09:00", "end" => "11:00" } }
    )
    @desk = ConferenceProgram.create!(
      conference: @conference,
      program: Program.create!(name: "Front Desk", village: @village),
      day_schedules: { "0" => { "enabled" => true, "start" => "09:00", "end" => "11:00" } }
    )

    @admin = create_user("admin@example.com", handle: "Admin")
    UserRole.create!(user: @admin, role: Role.find_or_create_by!(name: Role::VILLAGE_ADMIN))
    @volunteer = create_user("ray@example.com", handle: "Radio Ray", callsign: "W1AW")
    @other_volunteer = create_user("sam@example.com", handle: "Sam")

    # Ray: Ham Exams 9:00-10:00 (4 slots -> one bar). Sam: Front Desk 9:30-10:00.
    @exams.timeslots.order(:start_time).first(4).each { |slot| VolunteerSignup.create!(user: @volunteer, timeslot: slot) }
    @desk.timeslots.order(:start_time).offset(2).first(2).each { |slot| VolunteerSignup.create!(user: @other_volunteer, timeslot: slot) }
  end

  def create_user(email, handle:, callsign: nil)
    user = User.new(email: email, password: "password123", password_confirmation: "password123",
                    handle: handle, callsign: callsign)
    user.skip_confirmation!
    user.save!
    user
  end

  test "a village admin sees one bar per contiguous shift with name and activity" do
    sign_in @admin
    get conference_schedule_timeline_path(@conference)

    assert_response :success
    assert_select ".timeline-bar", 2
    assert_select ".timeline-bar", text: /Radio Ray/ do
      assert_select ".badge", text: "Ham Exams"
    end
    assert_select ".timeline-bar", text: /Sam/ do
      assert_select ".badge", text: "Front Desk"
    end
  end

  test "a conference lead sees all activities" do
    lead = create_user("lead@example.com", handle: "Lead")
    ConferenceRole.create!(user: lead, conference: @conference, role_name: ConferenceRole::CONFERENCE_LEAD)
    sign_in lead

    get conference_schedule_timeline_path(@conference)

    assert_response :success
    assert_select ".timeline-bar", 2
  end

  test "an activity lead sees only their own activity's bars" do
    lead = create_user("activity-lead@example.com", handle: "Exams Lead")
    ConferenceProgramRole.create!(user: lead, conference_program: @exams,
                                  role_name: ConferenceProgramRole::ACTIVITY_LEAD)
    sign_in lead

    get conference_schedule_timeline_path(@conference)

    assert_response :success
    assert_select ".timeline-bar", 1
    assert_select ".timeline-bar", text: /Radio Ray/
    assert_select ".timeline-bar", text: /Sam/, count: 0
  end

  test "a plain volunteer is redirected away" do
    sign_in @volunteer
    get conference_schedule_timeline_path(@conference)

    assert_redirected_to conference_schedule_coverage_path(@conference)
  end

  test "unauthenticated users are sent to login" do
    get conference_schedule_timeline_path(@conference)
    assert_redirected_to new_user_session_path
  end

  test "the activity filter narrows to one activity" do
    sign_in @admin
    get conference_schedule_timeline_path(@conference, program_id: @desk.program_id)

    assert_select ".timeline-bar", 1
    assert_select ".timeline-bar", text: /Sam/
  end

  test "the time window filter keeps only overlapping bars" do
    sign_in @admin
    # 10:15-11:00 window: Ray (ends 10:00) and Sam (ends 10:00) both fall out.
    get conference_schedule_timeline_path(@conference, from: "10:15", to: "11:00")
    assert_select ".timeline-bar", 0

    # 9:45-10:30 overlaps both.
    get conference_schedule_timeline_path(@conference, from: "09:45", to: "10:30")
    assert_select ".timeline-bar", 2
  end

  test "the day param scopes the timeline" do
    sign_in @admin
    get conference_schedule_timeline_path(@conference, day: (@conference.start_date + 1.day).iso8601)

    assert_response :success
    assert_select ".timeline-bar", 0
  end

  test "bars link to the volunteer's profile" do
    sign_in @admin
    get conference_schedule_timeline_path(@conference)

    assert_select "a.timeline-bar[href='#{managed_user_path(@volunteer)}']", text: /Radio Ray/
    assert_select "a.timeline-bar[href='#{managed_user_path(@other_volunteer)}']", text: /Sam/
  end

  test "bars link to the volunteer's profile for activity leads too" do
    lead = create_user("activity-lead@example.com", handle: "Exams Lead")
    ConferenceProgramRole.create!(user: lead, conference_program: @exams,
                                  role_name: ConferenceProgramRole::ACTIVITY_LEAD)
    sign_in lead

    get conference_schedule_timeline_path(@conference)

    assert_select "a.timeline-bar[href='#{managed_user_path(@volunteer)}']"
  end

  test "managers get a link to the timeline from the schedule and the board" do
    sign_in @admin

    get conference_schedule_path(@conference)
    assert_select "a[href='#{conference_schedule_timeline_path(@conference)}']", text: /staffing timeline/i

    get conference_schedule_board_path(@conference)
    assert_select "a[href='#{conference_schedule_timeline_path(@conference)}']", text: /staffing timeline/i
  end

  test "plain volunteers get no timeline link on the schedule" do
    sign_in @volunteer
    get conference_schedule_path(@conference)

    assert_select "a[href='#{conference_schedule_timeline_path(@conference)}']", count: 0
  end
end
