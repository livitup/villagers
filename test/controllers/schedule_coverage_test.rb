require "test_helper"

# Volunteer coverage view (#240): per-activity claim stack rendered from
# CoverageProjection, day-scoped, shipping alongside the legacy grid.
class ScheduleCoverageTest < ActionDispatch::IntegrationTest
  setup do
    @village = Village.create!(name: "Test Village", setup_complete: true)
    @conference = Conference.create!(
      village: @village,
      name: "Test Conference",
      start_date: Date.tomorrow,
      end_date: Date.tomorrow + 2.days,
      conference_hours_start: "09:00",
      conference_hours_end: "17:00",
      minimum_shift_duration: 30
    )
    @program = Program.create!(name: "Ham Exams", village: @village)
    @cp = ConferenceProgram.create!(
      conference: @conference,
      program: @program,
      day_schedules: {
        "0" => { "enabled" => true, "start" => "09:00", "end" => "11:00" },
        "1" => { "enabled" => true, "start" => "10:00", "end" => "12:00" }
      }
    )
    @volunteer = User.create!(
      email: "volunteer@example.com",
      password: "password123",
      password_confirmation: "password123",
      handle: "Vol One"
    )
    sign_in @volunteer
  end

  test "renders the claim stack with a card per activity scheduled that day" do
    get conference_schedule_path(@conference)

    assert_response :success
    assert_select ".coverage-card", 1
    assert_select ".coverage-card", text: /Ham Exams/
    assert_select ".coverage-ribbon .tick", 8
    assert_select ".tick.bare", 8
  end

  test "day defaults to the first conference day when today is outside the range" do
    get conference_schedule_path(@conference)

    assert_select "[data-current-day='#{@conference.start_date.iso8601}']"
  end

  test "day param selects that day's schedule and clamps out-of-range values" do
    day2 = @conference.start_date + 1.day
    get conference_schedule_path(@conference, day: day2.iso8601)
    assert_select "[data-current-day='#{day2.iso8601}']"
    assert_select ".coverage-ribbon .tick", 8   # 10:00-12:00

    get conference_schedule_path(@conference, day: "2001-01-01")
    assert_select "[data-current-day='#{@conference.start_date.iso8601}']"
  end

  test "a day with nothing scheduled says so" do
    day3 = @conference.start_date + 2.days
    get conference_schedule_path(@conference, day: day3.iso8601)

    assert_response :success
    assert_select ".coverage-card", 0
    assert_match(/nothing scheduled/i, response.body)
  end

  test "covered ticks render covered and my slots are marked mine" do
    slots = @cp.timeslots.order(:start_time).to_a
    slots[0].update_column(:current_volunteers_count, 1)
    VolunteerSignup.create!(user: @volunteer, timeslot: slots[1])

    get conference_schedule_path(@conference)

    assert_select ".tick.covered", 2   # the filled slot + my signup (counter cache)
    assert_select ".tick.mine", 1
  end

  test "my shifts for the day are listed as grouped ranges" do
    slots = @cp.timeslots.order(:start_time).to_a
    slots[0..2].each { |slot| VolunteerSignup.create!(user: @volunteer, timeslot: slot) }

    get conference_schedule_path(@conference)

    assert_select ".my-shifts", text: /Ham Exams/
    assert_select ".my-shifts", text: /9:00\s*AM\s*[-–]\s*9:45\s*AM/
  end

  test "an activity gated by a qualification I lack shows locked with no claim form" do
    qualification = Qualification.create!(name: "Licensed Ham", description: "License", village: @village)
    ProgramQualification.create!(program: @program, qualification: qualification)

    get conference_schedule_path(@conference)

    assert_select ".coverage-card .badge", text: /Licensed Ham/
    assert_select ".coverage-card form[action=?]", bulk_create_conference_volunteer_signups_path(@conference), count: 0
  end

  test "an activity gated by a qualification I hold is claimable" do
    qualification = Qualification.create!(name: "Licensed Ham", description: "License", village: @village)
    ProgramQualification.create!(program: @program, qualification: qualification)
    UserQualification.create!(user: @volunteer, qualification: qualification)

    get conference_schedule_path(@conference)

    assert_select ".coverage-card form[action=?]", bulk_create_conference_volunteer_signups_path(@conference)
  end

  test "claim form carries the conference block size and the 4h cap for the ribbon controller" do
    get conference_schedule_path(@conference)

    assert_select "[data-coverage-ribbon-block-minutes-value='30']"
    assert_select "[data-coverage-ribbon-cap-minutes-value='240']"
  end

  test "labels render in the conference's time zone, not the server default (#252)" do
    @conference.update!(time_zone: "Pacific Time (US & Canada)")

    get conference_schedule_path(@conference)

    assert_response :success
    # 09:00 wall clock in PDT is 16:00 UTC; labels must still read 9:00 AM.
    assert_match "9:00 AM", response.body
    refute_match "4:00 PM", response.body
  end

  test "requires authentication" do
    sign_out @volunteer
    get conference_schedule_path(@conference)
    assert_redirected_to new_user_session_path
  end

  test "bulk_create returns to the coverage view when asked" do
    start_slot = @cp.timeslots.order(:start_time).first

    post bulk_create_conference_volunteer_signups_path(@conference),
         params: { timeslot_id: start_slot.id, duration_minutes: 30,
                   return_to: "coverage", return_day: @conference.start_date.iso8601 }

    assert_redirected_to conference_schedule_path(@conference, day: @conference.start_date.iso8601)
    assert_equal 2, @volunteer.volunteer_signups.count
  end

  test "bulk_create keeps its default destinations without return_to" do
    start_slot = @cp.timeslots.order(:start_time).first

    post bulk_create_conference_volunteer_signups_path(@conference),
         params: { timeslot_id: start_slot.id, duration_minutes: 30 }
    assert_redirected_to conference_volunteer_signups_path(@conference)

    post bulk_create_conference_volunteer_signups_path(@conference),
         params: { timeslot_id: start_slot.id, duration_minutes: 20 }   # not a whole block
    assert_redirected_to conference_schedule_path(@conference)
  end

  test "bulk_create block-size errors also return to the coverage view when asked" do
    start_slot = @cp.timeslots.order(:start_time).first

    post bulk_create_conference_volunteer_signups_path(@conference),
         params: { timeslot_id: start_slot.id, duration_minutes: 20,
                   return_to: "coverage", return_day: @conference.start_date.iso8601 }

    assert_redirected_to conference_schedule_path(@conference, day: @conference.start_date.iso8601)
    assert_match(/blocks/, flash[:alert])
  end

  # --- swap confirmation modal (#267) ---

  def swap_conflict_setup
    @other_cp = ConferenceProgram.create!(
      conference: @conference,
      program: Program.create!(name: "Front Desk", village: @village),
      day_schedules: { "0" => { "enabled" => true, "start" => "09:00", "end" => "11:00" } }
    )
    # I'm on Front Desk 9:00–9:30; the swap target is Ham Exams 9:00–10:00.
    @other_cp.timeslots.order(:start_time).first(2).each do |slot|
      VolunteerSignup.create!(user: @volunteer, timeslot: slot)
    end
    @target_start = @cp.timeslots.order(:start_time).first
  end

  test "confirm_swap renders the conflict modal with swap and keep choices" do
    swap_conflict_setup

    get conference_schedule_path(@conference, day: @conference.start_date.iso8601,
                                              confirm_swap: @target_start.id, swap_minutes: 60)

    assert_response :success
    assert_select ".swap-conflict-modal" do
      assert_select "*", text: /Front Desk/
      assert_select "*", text: /Ham Exams/
      assert_select "*", text: /9:00 AM\s*–\s*9:30 AM/
      assert_select "form input[name=replace_conflicts][value='1']"
      assert_select "form input[name=timeslot_id][value='#{@target_start.id}']"
      assert_select "form input[name=duration_minutes][value='60']"
      assert_select "a", text: /keep/i
    end
  end

  test "confirm_swap without an actual conflict renders no modal" do
    get conference_schedule_path(@conference, day: @conference.start_date.iso8601,
                                              confirm_swap: @cp.timeslots.order(:start_time).first.id,
                                              swap_minutes: 60)

    assert_response :success
    assert_select ".swap-conflict-modal", 0
  end

  test "confirm_swap ignores a timeslot from another conference" do
    swap_conflict_setup
    foreign_conference = Conference.create!(
      village: @village, name: "Other Con",
      start_date: Date.tomorrow, end_date: Date.tomorrow + 1.day,
      conference_hours_start: "09:00", conference_hours_end: "17:00"
    )
    foreign_cp = ConferenceProgram.create!(
      conference: foreign_conference,
      program: Program.create!(name: "Foreign", village: @village),
      day_schedules: { "0" => { "enabled" => true, "start" => "09:00", "end" => "10:00" } }
    )

    get conference_schedule_path(@conference, day: @conference.start_date.iso8601,
                                              confirm_swap: foreign_cp.timeslots.first.id, swap_minutes: 60)

    assert_response :success
    assert_select ".swap-conflict-modal", 0
  end
end
