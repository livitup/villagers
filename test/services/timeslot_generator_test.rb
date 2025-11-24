require "test_helper"

class TimeslotGeneratorTest < ActiveSupport::TestCase
  setup do
    @village = Village.create!(name: "Test Village", setup_complete: true)
    # Use Time.zone.parse to create times in the application timezone
    @conference = Conference.create!(
      name: "Test Conference",
      location: "Test Location",
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
  end

  test "should generate timeslots for enabled days" do
    day_schedules = {
      "0" => { "enabled" => true, "start" => "09:00", "end" => "10:00" },
      "1" => { "enabled" => false }
    }
    @conference_program = ConferenceProgram.create!(
      conference: @conference,
      program: @program,
      day_schedules: day_schedules
    )

    # Should generate 4 timeslots (09:00, 09:15, 09:30, 09:45) for day 0
    assert_equal 4, @conference_program.timeslots.count
    assert_equal Time.zone.parse("#{@conference.start_date} 09:00"), @conference_program.timeslots.first.start_time
    assert_equal Time.zone.parse("#{@conference.start_date} 09:45"), @conference_program.timeslots.last.start_time
  end

  test "should not generate timeslots for disabled days" do
    day_schedules = {
      "0" => { "enabled" => false },
      "1" => { "enabled" => false }
    }
    @conference_program = ConferenceProgram.create!(
      conference: @conference,
      program: @program,
      day_schedules: day_schedules
    )

    assert_equal 0, @conference_program.timeslots.count
  end

  test "should generate timeslots with different schedules per day" do
    day_schedules = {
      "0" => { "enabled" => true, "start" => "09:00", "end" => "10:00" },
      "1" => { "enabled" => true, "start" => "10:00", "end" => "11:00" }
    }
    @conference_program = ConferenceProgram.create!(
      conference: @conference,
      program: @program,
      day_schedules: day_schedules
    )

    # Should generate 4 timeslots for day 0 and 4 for day 1
    assert_equal 8, @conference_program.timeslots.count
    day_0_timeslots = @conference_program.timeslots.where("start_time::date = ?", @conference.start_date)
    day_1_timeslots = @conference_program.timeslots.where("start_time::date = ?", @conference.end_date)
    assert_equal 4, day_0_timeslots.count
    assert_equal 4, day_1_timeslots.count
  end

  test "should use conference default hours when day schedule hours not specified" do
    day_schedules = {
      "0" => { "enabled" => true }
    }
    @conference_program = ConferenceProgram.create!(
      conference: @conference,
      program: @program,
      day_schedules: day_schedules
    )

    # Should use conference hours (09:00 to 17:00) = 8 hours = 32 timeslots
    assert_equal 32, @conference_program.timeslots.count
    first_timeslot = @conference_program.timeslots.order(:start_time).first
    assert_equal Time.zone.parse("#{@conference.start_date} 09:00"), first_timeslot.start_time
  end

  test "should generate 15-minute increments" do
    day_schedules = {
      "0" => { "enabled" => true, "start" => "09:00", "end" => "09:30" }
    }
    @conference_program = ConferenceProgram.create!(
      conference: @conference,
      program: @program,
      day_schedules: day_schedules
    )

    timeslots = @conference_program.timeslots.order(:start_time)
    assert_equal 2, timeslots.count
    assert_equal 15.minutes, timeslots[1].start_time - timeslots[0].start_time
  end

  test "should regenerate timeslots when day_schedules change" do
    day_schedules = {
      "0" => { "enabled" => true, "start" => "09:00", "end" => "10:00" }
    }
    @conference_program = ConferenceProgram.create!(
      conference: @conference,
      program: @program,
      day_schedules: day_schedules
    )

    assert_equal 4, @conference_program.timeslots.count

    # Update day_schedules
    new_schedules = {
      "0" => { "enabled" => true, "start" => "10:00", "end" => "11:00" }
    }
    @conference_program.update!(day_schedules: new_schedules)

    # Should have regenerated timeslots
    assert_equal 4, @conference_program.timeslots.count
    assert_equal Time.zone.parse("#{@conference.start_date} 10:00"), @conference_program.timeslots.order(:start_time).first.start_time
  end
end
