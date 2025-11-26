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

  test "max_volunteers can be nil to use program default" do
    cp = ConferenceProgram.new(
      conference: @conference,
      program: @program,
      max_volunteers: nil
    )
    assert cp.valid?
    assert_nil cp.max_volunteers
  end

  test "max_volunteers must be greater than 0 if set" do
    cp = ConferenceProgram.new(
      conference: @conference,
      program: @program,
      max_volunteers: 0
    )
    assert_not cp.valid?
    assert cp.errors[:max_volunteers].any?
  end

  test "max_volunteers can be set to any positive number" do
    cp = ConferenceProgram.new(
      conference: @conference,
      program: @program,
      max_volunteers: 5
    )
    assert cp.valid?
    assert_equal 5, cp.max_volunteers
  end

  test "effective_max_volunteers returns override when set" do
    cp = ConferenceProgram.new(
      conference: @conference,
      program: @program,
      max_volunteers: 5
    )
    assert_equal 5, cp.effective_max_volunteers
  end

  test "effective_max_volunteers falls back to program default" do
    @program.update!(max_volunteers: 3)
    cp = ConferenceProgram.new(
      conference: @conference,
      program: @program,
      max_volunteers: nil
    )
    assert_equal 3, cp.effective_max_volunteers
  end

  test "timeslots inherit effective_max_volunteers" do
    @program.update!(max_volunteers: 3)
    cp = ConferenceProgram.create!(
      conference: @conference,
      program: @program,
      max_volunteers: nil,
      day_schedules: {
        "0" => { "enabled" => true, "start" => "09:00", "end" => "10:00" }
      }
    )
    assert cp.timeslots.any?
    cp.timeslots.each do |timeslot|
      assert_equal 3, timeslot.max_volunteers
    end
  end

  test "timeslots use override when set" do
    @program.update!(max_volunteers: 3)
    cp = ConferenceProgram.create!(
      conference: @conference,
      program: @program,
      max_volunteers: 5,
      day_schedules: {
        "0" => { "enabled" => true, "start" => "09:00", "end" => "10:00" }
      }
    )
    assert cp.timeslots.any?
    cp.timeslots.each do |timeslot|
      assert_equal 5, timeslot.max_volunteers
    end
  end
end
