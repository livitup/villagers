require "test_helper"

# "Where you're needed" triage (#241): worst gaps across the conference,
# scoped by the volunteer's "I'm around" days, with hide-full and a Cover
# deep link that pre-selects the gap on the activity's card.
class ScheduleTriageTest < ActionDispatch::IntegrationTest
  setup do
    @village = Village.create!(name: "Test Village", setup_complete: true)
    @conference = Conference.create!(
      village: @village,
      name: "Test Conference",
      start_date: Date.tomorrow,
      end_date: Date.tomorrow + 1.day,
      conference_hours_start: "09:00",
      conference_hours_end: "17:00",
      minimum_shift_duration: 30
    )
    @day1 = @conference.start_date
    @day2 = @day1 + 1.day

    # Bare both days, 2h each day.
    @exams = ConferenceProgram.create!(
      conference: @conference,
      program: Program.create!(name: "Ham Exams", village: @village),
      day_schedules: {
        "0" => { "enabled" => true, "start" => "09:00", "end" => "11:00" },
        "1" => { "enabled" => true, "start" => "09:00", "end" => "11:00" }
      }
    )
    # Day 1 only, 1h, fully covered.
    @desk = ConferenceProgram.create!(
      conference: @conference,
      program: Program.create!(name: "Front Desk", village: @village),
      day_schedules: { "0" => { "enabled" => true, "start" => "09:00", "end" => "10:00" } }
    )
    @desk.timeslots.each { |slot| slot.update_column(:current_volunteers_count, 1) }

    @volunteer = User.create!(
      email: "volunteer@example.com",
      password: "password123",
      password_confirmation: "password123",
      handle: "Vol One"
    )
    sign_in @volunteer
  end

  test "triage lists uncovered gaps across all days, worst first, skipping covered activities" do
    get conference_schedule_path(@conference)

    assert_select ".triage-strip", 2                       # Ham Exams day1 + day2; Front Desk covered
    assert_select ".triage-strip", text: /Ham Exams/
    assert_select ".triage-strip", text: /2h uncovered/
    assert_select ".triage-strip", text: /Front Desk/, count: 0
  end

  test "I'm around day chips scope the triage to those days" do
    get conference_schedule_path(@conference, around: [ @day2.iso8601 ])

    assert_select ".triage-strip", 1
    assert_select ".triage-strip", text: Regexp.new(@day2.strftime("%a"))
  end

  test "the Cover link carries day, focus, and filters, anchored to the activity card" do
    get conference_schedule_path(@conference, around: [ @day2.iso8601 ])

    expected_focus = @exams.timeslots.where(start_time: @day2.in_time_zone.all_day).order(:start_time).first.id
    expected = conference_schedule_path(
      @conference, day: @day2.iso8601, around: [ @day2.iso8601 ], focus: expected_focus, anchor: "activity-#{@exams.id}"
    )
    assert_select ".triage-strip a.btn-primary[href=?]", expected
  end

  test "focus param arms the matching card's ribbon controller" do
    focus_slot = @exams.timeslots.order(:start_time).first

    get conference_schedule_path(@conference, focus: focus_slot.id)

    assert_select "#activity-#{@exams.id}[data-coverage-ribbon-focus-timeslot-id-value='#{focus_slot.id}']"
  end

  test "hide-full removes fully covered activities from the stack" do
    get conference_schedule_path(@conference)
    assert_select ".coverage-card", 2

    get conference_schedule_path(@conference, hide_full: "1")
    assert_select ".coverage-card", 1
    assert_select ".coverage-card", text: /Front Desk/, count: 0
  end

  test "day switcher links preserve around and hide_full params" do
    get conference_schedule_path(@conference, around: [ @day2.iso8601 ], hide_full: "1")

    expected = conference_schedule_path(@conference, day: @day2.iso8601, around: [ @day2.iso8601 ], hide_full: "1")
    assert_select ".btn-group[aria-label='Day'] a[href=?]", expected
  end

  test "a qualification-locked activity appears in triage without a Cover button" do
    qualification = Qualification.create!(name: "Licensed Ham", description: "License", village: @village)
    ProgramQualification.create!(program: @exams.program, qualification: qualification)

    get conference_schedule_path(@conference)

    assert_select ".triage-strip", text: /Ham Exams/
    assert_select ".triage-strip", text: /Licensed Ham/
    assert_select ".triage-strip a.btn-primary", count: 0
  end

  test "fully covered conference shows the all-covered message instead of triage" do
    @exams.timeslots.each { |slot| slot.update_column(:current_volunteers_count, 1) }

    get conference_schedule_path(@conference)

    assert_select ".triage-strip", 0
    assert_match(/covered everywhere/i, response.body)
  end
end
