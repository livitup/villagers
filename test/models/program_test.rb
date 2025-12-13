require "test_helper"

class ProgramTest < ActiveSupport::TestCase
  setup do
    @village = Village.create!(name: "Test Village", setup_complete: true)
  end

  test "should be valid with valid attributes" do
    program = Program.new(
      name: "Ham Test",
      description: "Amateur radio license testing",
      village: @village
    )
    assert program.valid?
  end

  test "should require name" do
    program = Program.new(
      description: "Amateur radio license testing",
      village: @village
    )
    assert_not program.valid?
    assert_includes program.errors[:name], "can't be blank"
  end

  test "should require village" do
    program = Program.new(
      name: "Ham Test",
      description: "Amateur radio license testing"
    )
    assert_not program.valid?
    assert_includes program.errors[:village], "must exist"
  end

  test "should belong to village" do
    program = Program.create!(
      name: "Ham Test",
      description: "Amateur radio license testing",
      village: @village
    )
    assert_equal @village, program.village
  end

  test "description is optional" do
    program = Program.new(
      name: "Ham Test",
      village: @village
    )
    assert program.valid?
  end

  test "name must be unique within village" do
    Program.create!(
      name: "Ham Test",
      description: "Amateur radio license testing",
      village: @village
    )

    duplicate = Program.new(
      name: "Ham Test",
      description: "Another description",
      village: @village
    )
    assert_not duplicate.valid?
    assert_includes duplicate.errors[:name], "must be unique within the village"
  end

  test "same name can exist in different villages" do
    other_village = Village.create!(name: "Other Village", setup_complete: true)
    Program.create!(
      name: "Ham Test",
      description: "Amateur radio license testing",
      village: @village
    )

    program_in_other_village = Program.new(
      name: "Ham Test",
      description: "Amateur radio license testing",
      village: other_village
    )
    assert program_in_other_village.valid?
  end

  # Conference-specific program tests
  test "program can be conference-specific" do
    conference = Conference.create!(
      name: "Test Conference",
      village: @village,
      start_date: Date.tomorrow,
      end_date: Date.tomorrow + 3.days
    )
    program = Program.new(
      name: "Conference Only Program",
      village: @village,
      conference: conference
    )
    assert program.valid?
    assert_equal conference, program.conference
    assert program.conference_specific?
  end

  test "program without conference is village-level" do
    program = Program.new(
      name: "Village Level Program",
      village: @village
    )
    assert program.valid?
    assert_nil program.conference
    assert program.village_level?
    assert_not program.conference_specific?
  end

  test "village_level scope returns only programs without conference" do
    conference = Conference.create!(
      name: "Test Conference",
      village: @village,
      start_date: Date.tomorrow,
      end_date: Date.tomorrow + 3.days
    )
    village_program = Program.create!(name: "Village Program", village: @village)
    conference_program = Program.create!(name: "Conference Program", village: @village, conference: conference)

    village_programs = Program.village_level
    assert_includes village_programs, village_program
    assert_not_includes village_programs, conference_program
  end

  test "for_conference scope returns village-level and conference-specific programs" do
    conference = Conference.create!(
      name: "Test Conference",
      village: @village,
      start_date: Date.tomorrow,
      end_date: Date.tomorrow + 3.days
    )
    other_conference = Conference.create!(
      name: "Other Conference",
      village: @village,
      start_date: Date.tomorrow + 10.days,
      end_date: Date.tomorrow + 13.days
    )
    village_program = Program.create!(name: "Village Program", village: @village)
    conf_program = Program.create!(name: "Conference Program", village: @village, conference: conference)
    other_conf_program = Program.create!(name: "Other Conference Program", village: @village, conference: other_conference)

    available_programs = Program.for_conference(conference)
    assert_includes available_programs, village_program
    assert_includes available_programs, conf_program
    assert_not_includes available_programs, other_conf_program
  end

  test "same name can exist in village-level and conference-specific programs" do
    conference = Conference.create!(
      name: "Test Conference",
      village: @village,
      start_date: Date.tomorrow,
      end_date: Date.tomorrow + 3.days
    )
    Program.create!(name: "Ham Test", village: @village)

    conference_program = Program.new(
      name: "Ham Test",
      village: @village,
      conference: conference
    )
    assert conference_program.valid?
  end

  # Program lead tests
  test "program can have program roles" do
    program = Program.create!(name: "Test Program", village: @village)
    user = User.create!(email: "lead@example.com", password: "password123", password_confirmation: "password123")
    role = ProgramRole.create!(user: user, program: program, role_name: ProgramRole::PROGRAM_LEAD)

    assert_includes program.program_roles, role
  end

  test "program can have multiple leads" do
    program = Program.create!(name: "Test Program", village: @village)
    user1 = User.create!(email: "lead1@example.com", password: "password123", password_confirmation: "password123")
    user2 = User.create!(email: "lead2@example.com", password: "password123", password_confirmation: "password123")

    ProgramRole.create!(user: user1, program: program, role_name: ProgramRole::PROGRAM_LEAD)
    ProgramRole.create!(user: user2, program: program, role_name: ProgramRole::PROGRAM_LEAD)

    assert_equal 2, program.program_leads.count
    assert_includes program.program_leads, user1
    assert_includes program.program_leads, user2
  end

  test "deleting program deletes associated program roles" do
    program = Program.create!(name: "Test Program", village: @village)
    user = User.create!(email: "lead@example.com", password: "password123", password_confirmation: "password123")
    ProgramRole.create!(user: user, program: program, role_name: ProgramRole::PROGRAM_LEAD)

    assert_difference "ProgramRole.count", -1 do
      program.destroy
    end
  end
end
