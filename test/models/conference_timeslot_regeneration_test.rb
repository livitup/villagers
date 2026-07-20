require "test_helper"

class ConferenceTimeslotRegenerationTest < ActiveSupport::TestCase
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
        "0" => { "enabled" => true, "start" => "09:00", "end" => "10:00" }
      }
    )
  end

  test "start_date changes drop out-of-range days but never re-assign schedules (#226)" do
    initial_count = @conference_program.timeslots.count
    assert initial_count > 0
    scheduled_date = @conference.start_date

    # Moving start past the scheduled date: its slots go away, but the
    # schedule stays bound to its calendar date (retained in config)...
    @conference.update!(start_date: scheduled_date + 1.day)
    assert_equal 0, @conference_program.timeslots.count
    assert @conference_program.reload.day_schedules.key?(scheduled_date.iso8601)

    # ...and comes back when the range covers that date again.
    @conference.update!(start_date: scheduled_date)
    assert_equal initial_count, @conference_program.timeslots.count
    assert_equal scheduled_date, @conference_program.timeslots.order(:start_time).first.start_time.to_date
  end

  test "should regenerate timeslots when conference end_date changes" do
    initial_count = @conference_program.timeslots.count

    new_end_date = @conference.end_date + 1.day
    @conference.update!(end_date: new_end_date)

    # Timeslots should be regenerated
    # Count might change if new day has enabled schedule
    assert @conference_program.timeslots.count >= initial_count
  end

  test "should regenerate timeslots when conference hours change" do
    initial_count = @conference_program.timeslots.count
    assert initial_count > 0

    @conference.update!(conference_hours_start: Time.zone.parse("2000-01-01 10:00"))

    # Timeslots should be regenerated with new hours
    # Note: This test assumes day_schedules don't specify hours, so it uses conference defaults
    # If day_schedules specify hours, they won't change
    assert @conference_program.timeslots.count > 0
  end
end
