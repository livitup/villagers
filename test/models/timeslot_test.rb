require "test_helper"

class TimeslotTest < ActiveSupport::TestCase
  setup do
    @village = Village.create!(name: "Test Village", setup_complete: true)
    @conference = Conference.create!(
      name: "Test Conference",
      location: "Test Location",
      start_date: Date.today + 1.day,
      end_date: Date.today + 3.days,
      conference_hours_start: Time.parse("09:00"),
      conference_hours_end: Time.parse("17:00"),
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
      public_description: "Test description"
    )
  end

  test "should be valid with all required fields" do
    timeslot = Timeslot.new(
      conference_program: @conference_program,
      start_time: Time.zone.parse("#{@conference.start_date} 09:00"),
      max_volunteers: 5
    )
    assert timeslot.valid?
  end

  test "should require conference_program" do
    timeslot = Timeslot.new(
      start_time: Time.zone.parse("#{@conference.start_date} 09:00"),
      max_volunteers: 5
    )
    assert_not timeslot.valid?
    assert timeslot.errors[:conference_program].any?
  end

  test "should require start_time" do
    timeslot = Timeslot.new(
      conference_program: @conference_program,
      max_volunteers: 5
    )
    assert_not timeslot.valid?
    assert timeslot.errors[:start_time].any?
  end

  test "should calculate end_time as start_time plus 15 minutes" do
    start_time = Time.zone.parse("#{@conference.start_date} 09:00")
    timeslot = Timeslot.create!(
      conference_program: @conference_program,
      start_time: start_time,
      max_volunteers: 5
    )
    assert_equal start_time + 15.minutes, timeslot.end_time
  end

  test "should default max_volunteers to 1" do
    timeslot = Timeslot.new(
      conference_program: @conference_program,
      start_time: Time.zone.parse("#{@conference.start_date} 09:00")
    )
    assert_equal 1, timeslot.max_volunteers
  end

  test "should default current_volunteers_count to 0" do
    timeslot = Timeslot.new(
      conference_program: @conference_program,
      start_time: Time.zone.parse("#{@conference.start_date} 09:00")
    )
    assert_equal 0, timeslot.current_volunteers_count
  end

  test "should belong to conference_program" do
    timeslot = Timeslot.create!(
      conference_program: @conference_program,
      start_time: Time.zone.parse("#{@conference.start_date} 09:00"),
      max_volunteers: 5
    )
    assert_equal @conference_program, timeslot.conference_program
  end

  test "should belong to conference through conference_program" do
    timeslot = Timeslot.create!(
      conference_program: @conference_program,
      start_time: Time.zone.parse("#{@conference.start_date} 09:00"),
      max_volunteers: 5
    )
    assert_equal @conference, timeslot.conference
  end

  test "should belong to program through conference_program" do
    timeslot = Timeslot.create!(
      conference_program: @conference_program,
      start_time: Time.zone.parse("#{@conference.start_date} 09:00"),
      max_volunteers: 5
    )
    assert_equal @program, timeslot.program
  end
end
