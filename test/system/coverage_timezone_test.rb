require "application_system_test_case"

# Regression for #250: the Cover button's end label must be in the
# conference's (server) time zone, not the browser's. We force the browser
# into a far-away zone via CDP and assert the label still matches the
# server-rendered tick labels around it.
class CoverageTimezoneTest < ApplicationSystemTestCase
  setup do
    @village = Village.create!(name: "Test Village", setup_complete: true)
    @conference = Conference.create!(
      village: @village,
      name: "Test Conference",
      start_date: Date.tomorrow,
      end_date: Date.tomorrow,
      conference_hours_start: "09:00",
      conference_hours_end: "17:00",
      minimum_shift_duration: 30
    )
    ConferenceProgram.create!(
      conference: @conference,
      program: Program.create!(name: "Ham Exams", village: @village),
      day_schedules: { "0" => { "enabled" => true, "start" => "09:00", "end" => "11:00" } }
    )
    @volunteer = User.create!(email: "volunteer@example.com", password: "password123",
                              password_confirmation: "password123", handle: "Vol One")
  end

  test "the Cover label's end time matches the server zone regardless of the browser zone" do
    visit new_user_session_path
    # Put the browser 10 hours away from the app's UTC clock.
    page.driver.browser.execute_cdp("Emulation.setTimezoneOverride", timezoneId: "Pacific/Honolulu")

    fill_in "Email", with: @volunteer.email
    fill_in "Password", with: "password123"
    click_button "Log in"
    assert_text "Logout"

    visit conference_schedule_path(@conference)
    assert_selector "[data-coverage-ribbon-ready]"

    first(".coverage-ribbon .tick.bare").click
    within "[data-coverage-ribbon-target='lengthOptions']" do
      find("button", text: "1h", exact_text: true).click
    end

    # 9:00 AM + 1h = 10:00 AM in the conference's zone — never 11:00 PM
    # (Honolulu's rendering of 10:00 UTC).
    assert_selector "button:not([disabled])", text: "Cover 9:00 AM – 10:00 AM"
  end
end
