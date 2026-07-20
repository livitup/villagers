require "application_system_test_case"

# The coverage claim flow (#240): tap a tick in a hole, pick a block-snapped
# length scoped to that hole, claim the window through bulk_create.
class ScheduleCoverageSystemTest < ApplicationSystemTestCase
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
    @program = Program.create!(name: "Ham Exams", village: @village)
    @cp = ConferenceProgram.create!(
      conference: @conference,
      program: @program,
      # 09:00-11:00 -> a 2h day
      day_schedules: { "0" => { "enabled" => true, "start" => "09:00", "end" => "11:00" } }
    )
    @volunteer = User.create!(
      email: "volunteer@example.com",
      password: "password123",
      password_confirmation: "password123",
      handle: "Vol One"
    )
  end

  def login_as(user)
    visit new_user_session_path
    fill_in "Email", with: user.email
    fill_in "Password", with: "password123"
    click_button "Log in"
    assert_text "Logout"
  end

  test "claiming a window from the ribbon" do
    login_as @volunteer
    visit conference_schedule_coverage_path(@conference)
    assert_selector "[data-coverage-ribbon-ready]"

    # Tap the first tick, pick 1 hour, claim.
    first(".coverage-ribbon .tick.bare").click
    assert_selector "[data-coverage-ribbon-target='claimPanel']:not([hidden])"
    within "[data-coverage-ribbon-target='lengthOptions']" do
      find("button", text: "1h", exact_text: true).click
    end
    assert_selector "button:not([disabled])", text: /\ACover 9:00 AM/
    find("button", text: /\ACover 9:00 AM/).click

    # Back on the coverage view with the window claimed. Wait on the flash
    # first — the form POST + redirect can outlast the default Capybara wait.
    assert_text "Successfully signed up for 4 shifts", wait: 10
    assert_current_path conference_schedule_coverage_path(@conference, day: @conference.start_date.iso8601)
    assert_selector ".tick.covered", count: 4
    assert_selector ".tick.mine", count: 4
    assert_selector ".my-shifts", text: /9:00 AM\s*–\s*10:00 AM/
  end

  test "length options are scoped to the hole" do
    # Cover 09:30 onward, leaving only a 30-minute hole at the front.
    @cp.timeslots.order(:start_time).offset(2).each { |slot| slot.update_column(:current_volunteers_count, 1) }

    login_as @volunteer
    visit conference_schedule_coverage_path(@conference)
    assert_selector "[data-coverage-ribbon-ready]"

    first(".coverage-ribbon .tick.bare").click
    within "[data-coverage-ribbon-target='lengthOptions']" do
      assert_selector "button", count: 1
      assert_selector "button", text: "30m", exact_text: true
    end
  end

  test "triage Cover jumps to the gap on another day and pre-selects it" do
    @cp.update!(day_schedules: {
      "0" => { "enabled" => true, "start" => "09:00", "end" => "11:00" },
      "1" => { "enabled" => true, "start" => "13:00", "end" => "15:00" }
    })
    # Cover day 1 fully so the only triage gap is day 2's afternoon.
    @cp.timeslots.where(start_time: @conference.start_date.in_time_zone.all_day)
       .each { |slot| slot.update_column(:current_volunteers_count, 1) }

    login_as @volunteer
    visit conference_schedule_coverage_path(@conference)

    within ".triage-list" do
      assert_text "1:00 PM"
      click_link "Cover"
    end

    day2 = @conference.start_date + 1.day
    assert_selector "[data-current-day='#{day2.iso8601}']"
    # The gap arrived pre-selected: claim panel open, button armed at 1:00 PM.
    assert_selector "[data-coverage-ribbon-target='claimPanel']:not([hidden])"
    assert_selector "button:not([disabled])", text: /\ACover 1:00 PM/
  end

  test "hide-full toggle removes covered activities from the stack" do
    covered = ConferenceProgram.create!(
      conference: @conference,
      program: Program.create!(name: "Front Desk", village: @village),
      day_schedules: { "0" => { "enabled" => true, "start" => "09:00", "end" => "10:00" } }
    )
    covered.timeslots.each { |slot| slot.update_column(:current_volunteers_count, 1) }

    login_as @volunteer
    visit conference_schedule_coverage_path(@conference)
    assert_selector ".coverage-card", count: 2

    click_link "Hide full activities"
    assert_selector ".coverage-card", count: 1
    assert_no_text "Front Desk"

    click_link "Show full activities"
    assert_selector ".coverage-card", count: 2
  end

  test "I'm around chips scope the triage list" do
    @cp.update!(day_schedules: {
      "0" => { "enabled" => true, "start" => "09:00", "end" => "11:00" },
      "1" => { "enabled" => true, "start" => "09:00", "end" => "11:00" }
    })

    login_as @volunteer
    visit conference_schedule_coverage_path(@conference)
    assert_selector ".triage-strip", count: 2

    day2 = @conference.start_date + 1.day
    within ".card", text: "Where you're needed" do
      click_link day2.strftime("%a")
    end
    assert_selector ".triage-strip", count: 1
  end

  test "switching days re-renders the stack" do
    @cp.update!(day_schedules: {
      "0" => { "enabled" => true, "start" => "09:00", "end" => "11:00" },
      "1" => { "enabled" => true, "start" => "13:00", "end" => "14:00" }
    })

    login_as @volunteer
    visit conference_schedule_coverage_path(@conference)
    assert_selector ".coverage-ribbon .tick", count: 8

    day2 = @conference.start_date + 1.day
    click_link day2.strftime("%a %-m/%-d")
    assert_selector "[data-current-day='#{day2.iso8601}']"
    assert_selector ".coverage-ribbon .tick", count: 4
  end
end
