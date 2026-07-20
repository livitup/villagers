require "test_helper"

# Regression coverage for issue #225: editing a conference program's schedule
# (or the conference dates/hours) must not silently destroy volunteer signups
# for timeslots that still exist after the edit, and volunteers whose shifts
# genuinely disappear must be notified.
class TimeslotSignupPreservationTest < ActiveSupport::TestCase
  setup do
    @village = Village.create!(name: "Test Village", setup_complete: true)
    @conference = Conference.create!(
      name: "Test Conference",
      city: "Test City", state: "NV", country: "US",
      start_date: Date.today + 1.day,
      end_date: Date.today + 2.days,
      conference_hours_start: Time.zone.parse("2000-01-01 09:00"),
      conference_hours_end: Time.zone.parse("2000-01-01 17:00"),
      village: @village
    )
    @program = Program.create!(
      name: "Test Program",
      description: "A test program",
      village: @village
    )
    @conference_program = ConferenceProgram.create!(
      conference: @conference,
      program: @program,
      day_schedules: {
        "0" => { "enabled" => true, "start" => "09:00", "end" => "11:00" }
      }
    )
    @user = User.create!(
      email: "volunteer@example.com",
      password: "password123",
      password_confirmation: "password123"
    )
  end

  def timeslot_at(day_offset, hhmm)
    date = @conference.start_date + day_offset.days
    @conference_program.timeslots.find_by(start_time: Time.zone.parse("#{date} #{hhmm}"))
  end

  test "extending the schedule preserves signups on unchanged timeslots" do
    slot = timeslot_at(0, "09:00")
    VolunteerSignup.create!(user: @user, timeslot: slot)

    @conference_program.update!(
      day_schedules: { "0" => { "enabled" => true, "start" => "09:00", "end" => "12:00" } }
    )

    assert VolunteerSignup.exists?(user: @user, timeslot: timeslot_at(0, "09:00")),
      "signup on an unchanged timeslot should survive a schedule edit"
  end

  test "editing one day's schedule preserves signups on other unchanged days" do
    @conference_program.update!(
      day_schedules: {
        "0" => { "enabled" => true, "start" => "09:00", "end" => "11:00" },
        "1" => { "enabled" => true, "start" => "09:00", "end" => "11:00" }
      }
    )
    day1_slot = timeslot_at(1, "09:00")
    VolunteerSignup.create!(user: @user, timeslot: day1_slot)

    # Change only day 0's times
    @conference_program.update!(
      day_schedules: {
        "0" => { "enabled" => true, "start" => "13:00", "end" => "15:00" },
        "1" => { "enabled" => true, "start" => "09:00", "end" => "11:00" }
      }
    )

    assert VolunteerSignup.exists?(user: @user, timeslot: timeslot_at(1, "09:00")),
      "editing one day must not wipe signups on other days"
  end

  test "removing a timeslot destroys its signup but notifies the volunteer" do
    slot = timeslot_at(0, "10:30")
    VolunteerSignup.create!(user: @user, timeslot: slot)
    slot_id = slot.id

    @conference_program.update!(
      day_schedules: { "0" => { "enabled" => true, "start" => "09:00", "end" => "10:00" } }
    )

    assert_not VolunteerSignup.exists?(timeslot_id: slot_id),
      "signup on a removed timeslot should be gone"
    assert @user.notifications.where(notification_type: Notification::SHIFT_CANCELLED).exists?,
      "volunteer must be notified when their shift is removed by a schedule edit"
  end

  test "changing conference hours preserves signups on surviving timeslots" do
    slot = timeslot_at(0, "09:00")
    VolunteerSignup.create!(user: @user, timeslot: slot)

    # Widen conference hours; day_schedules use explicit times so the 09:00
    # slot survives. This exercises the Conference-level regeneration path.
    @conference.update!(conference_hours_end: Time.zone.parse("2000-01-01 20:00"))

    assert VolunteerSignup.exists?(user: @user, timeslot: timeslot_at(0, "09:00")),
      "conference-level regeneration must preserve signups on surviving timeslots"
  end
end
