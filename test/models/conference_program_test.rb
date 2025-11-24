require "test_helper"

class ConferenceProgramTest < ActiveSupport::TestCase
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
  end

  test "should be valid with all required fields" do
    cp = ConferenceProgram.new(
      conference: @conference,
      program: @program,
      public_description: "Conference-specific description"
    )
    assert cp.valid?
  end

  test "should require conference" do
    cp = ConferenceProgram.new(program: @program)
    assert_not cp.valid?
    assert cp.errors[:conference].any?
  end

  test "should require program" do
    cp = ConferenceProgram.new(conference: @conference)
    assert_not cp.valid?
    assert cp.errors[:program].any?
  end

  test "conference and program combination should be unique" do
    ConferenceProgram.create!(
      conference: @conference,
      program: @program,
      public_description: "First"
    )
    duplicate = ConferenceProgram.new(
      conference: @conference,
      program: @program,
      public_description: "Second"
    )
    assert_not duplicate.valid?
    assert duplicate.errors[:program].any?
  end

  test "should belong to conference" do
    cp = ConferenceProgram.create!(
      conference: @conference,
      program: @program,
      public_description: "Test"
    )
    assert_equal @conference, cp.conference
  end

  test "should belong to program" do
    cp = ConferenceProgram.create!(
      conference: @conference,
      program: @program,
      public_description: "Test"
    )
    assert_equal @program, cp.program
  end

  test "should store day schedules in jsonb" do
    schedules = {
      "0" => { "enabled" => true, "start" => "09:00", "end" => "17:00" },
      "1" => { "enabled" => true, "start" => "10:00", "end" => "18:00" },
      "2" => { "enabled" => false }
    }
    cp = ConferenceProgram.create!(
      conference: @conference,
      program: @program,
      public_description: "Test",
      day_schedules: schedules
    )
    assert_equal schedules, cp.day_schedules
  end

  test "day_schedules should default to empty hash" do
    cp = ConferenceProgram.new(
      conference: @conference,
      program: @program
    )
    assert_equal({}, cp.day_schedules)
  end
end
