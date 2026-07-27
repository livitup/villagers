require "application_system_test_case"

# The shift assignments report's optional profile columns (#261): toggling a
# checkbox applies immediately — no separate "Apply Filters" click needed.
class ShiftAssignmentsReportTest < ApplicationSystemTestCase
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
    cp = ConferenceProgram.create!(
      conference: @conference,
      program: Program.create!(name: "Ham Exams", village: @village),
      day_schedules: { "0" => { "enabled" => true, "start" => "09:00", "end" => "10:00" } }
    )
    @volunteer = User.create!(
      email: "ray@example.com", password: "password123", password_confirmation: "password123",
      handle: "Radio Ray", discord: "ray#1234", callsign: "W1AW"
    )
    VolunteerSignup.create!(user: @volunteer, timeslot: cp.timeslots.first)

    @admin = User.create!(email: "admin@example.com", password: "password123",
                          password_confirmation: "password123", handle: "Admin")
    UserRole.create!(user: @admin, role: Role.find_or_create_by!(name: Role::VILLAGE_ADMIN))
  end

  def login_as(user)
    visit new_user_session_path
    fill_in "Email", with: user.email
    fill_in "Password", with: "password123"
    click_button "Log in"
    assert_text "Logout"
  end

  test "checking an extra column applies it immediately" do
    login_as @admin
    visit shift_assignments_conference_reports_path(@conference)
    assert_selector "td", text: "Radio Ray"
    assert_no_selector "th", text: "Discord"

    # Submit-sized waits: a toggle both submits the form AND is un-done by the
    # helper's JS-fallback click, so a premature retry would revert it.
    click_expecting find("#column-discord"), "th", text: "Discord", wait: 10
    assert_selector "td", text: "ray#1234"

    # The Export CSV link follows the selection.
    assert_selector "a[href*='columns%5B%5D=discord']", text: "Export CSV"

    # Unchecking applies immediately too.
    click_expecting find("#column-discord"), "th", text: "Discord", count: 0, wait: 10
    assert_no_selector "td", text: "ray#1234"
  end
end
