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

  # Claim Ham Exams 9:00–10:00 from its card, landing on the conflict modal
  # (the caller has arranged an overlapping shift elsewhere).
  def claim_ham_exams_window
    within "#activity-#{@cp.id}" do
      click_expecting first(".coverage-ribbon .tick.bare"),
                      "[data-coverage-ribbon-target='claimPanel']:not([hidden])"
      click_expecting find("[data-coverage-ribbon-target='lengthOptions'] button", text: "1h", exact_text: true),
                      text: "Cover 9:00 AM"
    end
    click_expecting within("#activity-#{@cp.id}") { find("button:not([disabled])", text: /\ACover 9:00 AM/) },
                    ".swap-conflict-modal", wait: 10
  end

  test "claiming a window from the ribbon" do
    login_as @volunteer
    visit conference_schedule_path(@conference)
    assert_selector "[data-coverage-ribbon-ready]"

    # Tap the first tick, pick 1 hour, claim.
    click_expecting first(".coverage-ribbon .tick.bare"),
                    "[data-coverage-ribbon-target='claimPanel']:not([hidden])"
    click_expecting find("[data-coverage-ribbon-target='lengthOptions'] button", text: "1h", exact_text: true),
                    text: "Cover 9:00 AM"

    # The form POST + redirect can outlast the default Capybara wait, so wait
    # on the flash with a submit-sized window.
    click_expecting find("button:not([disabled])", text: /\ACover 9:00 AM/),
                    text: "Successfully signed up for 4 shifts", wait: 10
    assert_current_path conference_schedule_path(@conference, day: @conference.start_date.iso8601)
    assert_selector ".tick.covered", count: 4
    assert_selector ".tick.mine", count: 4
    assert_selector ".my-shifts", text: /9:00 AM\s*–\s*10:00 AM/
  end

  test "length options are scoped to the hole" do
    # Cover 09:30 onward, leaving only a 30-minute hole at the front.
    @cp.timeslots.order(:start_time).offset(2).each { |slot| slot.update_column(:current_volunteers_count, 1) }

    login_as @volunteer
    visit conference_schedule_path(@conference)
    assert_selector "[data-coverage-ribbon-ready]"

    click_expecting first(".coverage-ribbon .tick.bare"),
                    "[data-coverage-ribbon-target='claimPanel']:not([hidden])"
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
    visit conference_schedule_path(@conference)

    day2 = @conference.start_date + 1.day
    within(".triage-list") { assert_text "1:00 PM" }
    click_expecting find(".triage-list a", text: "Cover"), "[data-current-day='#{day2.iso8601}']"
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
    visit conference_schedule_path(@conference)
    assert_selector ".coverage-card", count: 2

    click_expecting find_link("Hide full activities"), ".coverage-card", count: 1
    assert_no_text "Front Desk"

    click_expecting find_link("Show full activities"), ".coverage-card", count: 2
  end

  test "I'm around chips scope the triage list" do
    @cp.update!(day_schedules: {
      "0" => { "enabled" => true, "start" => "09:00", "end" => "11:00" },
      "1" => { "enabled" => true, "start" => "09:00", "end" => "11:00" }
    })

    login_as @volunteer
    visit conference_schedule_path(@conference)
    assert_selector ".triage-strip", count: 2

    day2 = @conference.start_date + 1.day
    chip = within(".card", text: "Where you're needed") { find_link(day2.strftime("%a")) }
    click_expecting chip, ".triage-strip", count: 1
  end

  test "claiming over an existing shift offers swap-or-keep and swaps" do
    # I'm on Front Desk 9:00–9:30; claiming Ham Exams 9:00–10:00 conflicts.
    front_desk = ConferenceProgram.create!(
      conference: @conference,
      program: Program.create!(name: "Front Desk", village: @village),
      day_schedules: { "0" => { "enabled" => true, "start" => "09:00", "end" => "10:00" } }
    )
    front_desk.timeslots.order(:start_time).first(2).each do |slot|
      VolunteerSignup.create!(user: @volunteer, timeslot: slot)
    end

    login_as @volunteer
    visit conference_schedule_path(@conference)
    assert_selector "[data-coverage-ribbon-ready]"

    claim_ham_exams_window

    # The conflict modal explains the clash instead of a green "0 shifts".
    # The two conflicting slots are contiguous, so they present as one shift.
    within ".swap-conflict-modal" do
      assert_text "Front Desk"
      assert_text(/9:00 AM\s*–\s*9:30 AM/)
    end
    click_expecting within(".swap-conflict-modal") { find_button("Cancel conflicting shift and sign up") },
                    text: "Cancelled 2 conflicting shifts", wait: 10

    assert_text "Successfully signed up for 4 shifts"
    assert_equal 4, @volunteer.volunteer_signups.count
    assert_equal [ @cp.id ], @volunteer.volunteer_signups.joins(:timeslot)
                                       .distinct.pluck(:conference_program_id)
  end

  test "keeping the current shifts from the conflict modal changes nothing" do
    front_desk = ConferenceProgram.create!(
      conference: @conference,
      program: Program.create!(name: "Front Desk", village: @village),
      day_schedules: { "0" => { "enabled" => true, "start" => "09:00", "end" => "10:00" } }
    )
    front_desk.timeslots.order(:start_time).first(2).each do |slot|
      VolunteerSignup.create!(user: @volunteer, timeslot: slot)
    end

    login_as @volunteer
    visit conference_schedule_path(@conference)
    assert_selector "[data-coverage-ribbon-ready]"

    claim_ham_exams_window

    click_expecting within(".swap-conflict-modal") { find_link("Keep my current shifts") },
                    gone: ".swap-conflict-modal"
    assert_equal 2, @volunteer.volunteer_signups.count
    assert_equal front_desk.timeslots.order(:start_time).first(2).map(&:id).sort,
                 @volunteer.volunteer_signups.pluck(:timeslot_id).sort
  end

  test "switching days re-renders the stack" do
    @cp.update!(day_schedules: {
      "0" => { "enabled" => true, "start" => "09:00", "end" => "11:00" },
      "1" => { "enabled" => true, "start" => "13:00", "end" => "14:00" }
    })

    login_as @volunteer
    visit conference_schedule_path(@conference)
    assert_selector ".coverage-ribbon .tick", count: 8

    day2 = @conference.start_date + 1.day
    click_expecting find_link(day2.strftime("%a %-m/%-d")), "[data-current-day='#{day2.iso8601}']"
    assert_selector ".coverage-ribbon .tick", count: 4
  end
end
