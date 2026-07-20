require "test_helper"

# Per-conference time zones (#252). Wall-clock schedules are interpreted in
# the conference's zone, and changing the zone on a live conference slides
# every slot's instant while keeping ids, signups, and wall-clock times —
# with zero cancellation notifications.
class ConferenceTimeZoneTest < ActiveSupport::TestCase
  PACIFIC = "Pacific Time (US & Canada)".freeze

  setup do
    @village = Village.create!(name: "Test Village", setup_complete: true)
    @day = Date.new(2026, 8, 5)   # summer: PDT (-07:00)
    @conference = Conference.create!(
      village: @village,
      name: "Test Conference",
      start_date: @day,
      end_date: @day + 1.day,
      conference_hours_start: "09:00",
      conference_hours_end: "17:00"
    )
    @program = Program.create!(name: "Ham Exams", village: @village)
  end

  def create_cp(conference = @conference)
    ConferenceProgram.create!(
      conference: conference,
      program: @program,
      day_schedules: { @day.iso8601 => { "enabled" => true, "start" => "09:00", "end" => "11:00" } }
    )
  end

  test "time_zone defaults to UTC and validates against known zones" do
    assert_equal "UTC", @conference.time_zone
    assert_equal "Etc/UTC", @conference.tz.tzinfo.identifier

    @conference.time_zone = "Not A Zone"
    assert_not @conference.valid?
    assert @conference.errors[:time_zone].any?
  end

  test "schedule wall times are interpreted in the conference's zone" do
    @conference.update!(time_zone: PACIFIC)
    cp = create_cp

    first = cp.timeslots.order(:start_time).first
    assert_equal "2026-08-05T09:00:00-07:00", first.start_time.in_time_zone(PACIFIC).iso8601
    assert_equal "2026-08-05T16:00:00Z", first.start_time.utc.iso8601, "09:00 PDT is 16:00 UTC"
  end

  test "DST is honored per date" do
    winter_day = Date.new(2026, 12, 5)
    conference = Conference.create!(
      village: @village, name: "Winter Conference", time_zone: PACIFIC,
      start_date: winter_day, end_date: winter_day,
      conference_hours_start: "09:00", conference_hours_end: "17:00"
    )
    cp = ConferenceProgram.create!(
      conference: conference,
      program: Program.create!(name: "Winter Program", village: @village),
      day_schedules: { winter_day.iso8601 => { "enabled" => true, "start" => "09:00", "end" => "10:00" } }
    )

    assert_equal "2026-12-05T17:00:00Z", cp.timeslots.order(:start_time).first.start_time.utc.iso8601,
                 "09:00 PST (winter) is 17:00 UTC"
  end

  test "setting the zone on a live conference slides slots in place: ids, signups, wall clock all preserved, no notifications" do
    cp = create_cp   # generated under UTC
    volunteer = User.create!(email: "vol@example.com", password: "password123",
                             password_confirmation: "password123", handle: "Vol One")
    slots_before = cp.timeslots.order(:start_time).to_a
    signup = VolunteerSignup.create!(user: volunteer, timeslot: slots_before[2])
    utc_instants = slots_before.map { |slot| slot.start_time.utc.iso8601 }

    assert_no_difference [ "Notification.count", "VolunteerSignup.count" ] do
      @conference.update!(time_zone: PACIFIC)
    end

    slots_after = cp.timeslots.order(:start_time).to_a
    assert_equal slots_before.map(&:id), slots_after.map(&:id), "same rows, slid in place"
    assert VolunteerSignup.exists?(id: signup.id)
    assert_equal [ "09:00" ] + [ nil ] * 0, [ slots_after.first.start_time.in_time_zone(PACIFIC).strftime("%H:%M") ],
                 "wall clock preserved in the new zone"
    assert_not_equal utc_instants, slots_after.map { |slot| slot.start_time.utc.iso8601 },
                     "absolute instants shifted"
    assert_equal 7 * 3600, slots_after.first.start_time.utc.to_i - Time.utc(2026, 8, 5, 9).to_i,
                 "shifted by exactly the PDT offset"
    assert_equal slots_after.first.start_time + 15.minutes, slots_after.first.end_time, "end_time slid too"
  end

  test "reminder windows key off the true instant in the conference's zone" do
    @village.update!(email_enabled: true, mailgun_api_key: "test-key", mailgun_domain: "test.mailgun.org")
    @conference.update!(time_zone: PACIFIC, reminder_hours_before: 24)
    cp = create_cp
    volunteer = User.create!(email: "vol@example.com", password: "password123",
                             password_confirmation: "password123", handle: "Vol One")
    slot = cp.timeslots.order(:start_time).first   # 2026-08-05 09:00 PDT = 16:00 UTC
    signup = VolunteerSignup.create!(user: volunteer, timeslot: slot)

    # 25h before the true instant: outside the 24h window — no reminder.
    travel_to Time.utc(2026, 8, 4, 15, 0) do
      ShiftReminderJob.perform_now
      assert_nil signup.reload.reminder_sent_at
    end

    # Under UTC-wall-clock interpretation the shift would "start" at 09:00 UTC
    # and a reminder would already have fired by 23:00 UTC the day before.
    # With the zone honored, 23h before the real 16:00 UTC start is inside
    # the window — the reminder fires exactly relative to the true instant.
    travel_to Time.utc(2026, 8, 4, 17, 0) do
      ShiftReminderJob.perform_now
      assert_not_nil signup.reload.reminder_sent_at
    end
  end

  test "changing between two non-UTC zones also slides in place" do
    @conference.update!(time_zone: PACIFIC)
    cp = create_cp
    ids = cp.timeslots.order(:start_time).pluck(:id)

    assert_no_difference "Notification.count" do
      @conference.update!(time_zone: "Eastern Time (US & Canada)")
    end

    slots = cp.timeslots.order(:start_time).to_a
    assert_equal ids, slots.map(&:id)
    assert_equal "09:00", slots.first.start_time.in_time_zone("Eastern Time (US & Canada)").strftime("%H:%M")
  end
end
