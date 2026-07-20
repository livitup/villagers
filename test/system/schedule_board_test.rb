require "application_system_test_case"

# Admin coverage board end-to-end (#243): open a day's manage panel, set
# needed, add and remove a volunteer over a window.
class ScheduleBoardSystemTest < ApplicationSystemTestCase
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
    @cp = ConferenceProgram.create!(
      conference: @conference,
      program: Program.create!(name: "Ham Exams", village: @village),
      day_schedules: { "0" => { "enabled" => true, "start" => "09:00", "end" => "11:00" } }
    )
    @admin = User.create!(email: "admin@example.com", password: "password123",
                          password_confirmation: "password123", handle: "Admin")
    UserRole.create!(user: @admin, role: Role.find_or_create_by!(name: Role::VILLAGE_ADMIN))
    @volunteer = User.create!(email: "ray@example.com", password: "password123",
                              password_confirmation: "password123", handle: "Radio Ray", callsign: "W1AW")
  end

  def login_as(user)
    visit new_user_session_path
    fill_in "Email", with: user.email
    fill_in "Password", with: "password123"
    click_button "Log in"
    assert_text "Logout"
  end

  test "managing a day from the board: needed, add, remove" do
    login_as @admin
    visit conference_schedule_board_path(@conference)
    assert_selector ".board-row", count: 1

    # Open the day's manage panel.
    first(".board-cell a").click
    assert_selector ".manage-panel", text: "Ham Exams"

    # Raise needed to 2 for the day.
    fill_in "Needed today", with: 2
    click_button "Save"
    assert_text "Needed set to 2 for 8 slots"

    # Add Radio Ray 9:00-10:00.
    within ".manage-panel" do
      select "Radio Ray (W1AW)", from: "Who"
      select "9:00 AM", from: "From"
      select "1h", from: "For"
      click_button "Add to schedule"
    end
    assert_text "Radio Ray (W1AW) added 9:00 AM – 10:00 AM"
    within ".manage-panel" do
      assert_text "Radio Ray (W1AW)"
      assert_text(/9:00 AM\s*–\s*10:00 AM/)
    end

    # Remove the window again.
    within ".manage-panel" do
      accept_confirm { click_button "Remove" }
    end
    assert_text "Radio Ray (W1AW) removed from 4 slots"
    within ".manage-panel" do
      assert_text "No one is signed up yet"
    end
  end

  test "board reflects coverage states after management" do
    @cp.timeslots.each { |slot| slot.update_column(:current_volunteers_count, 1) }

    login_as @admin
    visit conference_schedule_board_path(@conference)

    assert_selector ".board-cell .badge.text-bg-success", count: 1
    assert_selector ".board-cell .tick.covered", count: 8
  end
end
