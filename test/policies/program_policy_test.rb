require "test_helper"

class ProgramPolicyTest < ActiveSupport::TestCase
  setup do
    @village = Village.create!(name: "Test Village", setup_complete: true)
    @conference = Conference.create!(
      name: "Test Conference",
      village: @village,
      start_date: Date.tomorrow,
      end_date: Date.tomorrow + 3.days
    )

    @village_admin = User.create!(
      email: "admin@example.com",
      password: "password123",
      password_confirmation: "password123"
    )
    village_admin_role = Role.find_or_create_by!(name: Role::VILLAGE_ADMIN)
    UserRole.create!(user: @village_admin, role: village_admin_role)

    @conference_lead = User.create!(
      email: "lead@example.com",
      password: "password123",
      password_confirmation: "password123"
    )
    ConferenceRole.create!(
      user: @conference_lead,
      conference: @conference,
      role_name: ConferenceRole::CONFERENCE_LEAD
    )

    @conference_admin = User.create!(
      email: "confadmin@example.com",
      password: "password123",
      password_confirmation: "password123"
    )
    ConferenceRole.create!(
      user: @conference_admin,
      conference: @conference,
      role_name: ConferenceRole::CONFERENCE_ADMIN
    )

    @volunteer = User.create!(
      email: "volunteer@example.com",
      password: "password123",
      password_confirmation: "password123"
    )

    @program_lead = User.create!(
      email: "programlead@example.com",
      password: "password123",
      password_confirmation: "password123"
    )

    @village_program = Program.create!(name: "Village Program", village: @village)
    @conference_program = Program.create!(name: "Conference Program", village: @village, conference: @conference)

    # Assign program lead to village program
    ProgramRole.create!(user: @program_lead, program: @village_program, role_name: ProgramRole::PROGRAM_LEAD)
  end

  # Village-level program tests
  test "village admin can create village-level programs" do
    policy = ProgramPolicy.new(@village_admin, Program.new(village: @village))
    assert policy.create?
  end

  test "conference lead cannot create village-level programs" do
    policy = ProgramPolicy.new(@conference_lead, Program.new(village: @village))
    assert_not policy.create?
  end

  test "volunteer cannot create village-level programs" do
    policy = ProgramPolicy.new(@volunteer, Program.new(village: @village))
    assert_not policy.create?
  end

  test "village admin can update village-level programs" do
    policy = ProgramPolicy.new(@village_admin, @village_program)
    assert policy.update?
  end

  test "conference lead cannot update village-level programs" do
    policy = ProgramPolicy.new(@conference_lead, @village_program)
    assert_not policy.update?
  end

  test "village admin can destroy village-level programs" do
    policy = ProgramPolicy.new(@village_admin, @village_program)
    assert policy.destroy?
  end

  test "conference lead cannot destroy village-level programs" do
    policy = ProgramPolicy.new(@conference_lead, @village_program)
    assert_not policy.destroy?
  end

  # Conference-specific program tests
  test "conference lead can create conference-specific programs for their conference" do
    policy = ProgramPolicy.new(@conference_lead, Program.new(village: @village, conference: @conference))
    assert policy.create?
  end

  test "conference admin can create conference-specific programs for their conference" do
    policy = ProgramPolicy.new(@conference_admin, Program.new(village: @village, conference: @conference))
    assert policy.create?
  end

  test "conference lead cannot create programs for other conferences" do
    other_conference = Conference.create!(
      name: "Other Conference",
      village: @village,
      start_date: Date.tomorrow + 10.days,
      end_date: Date.tomorrow + 13.days
    )
    policy = ProgramPolicy.new(@conference_lead, Program.new(village: @village, conference: other_conference))
    assert_not policy.create?
  end

  test "conference lead can update their conference-specific programs" do
    policy = ProgramPolicy.new(@conference_lead, @conference_program)
    assert policy.update?
  end

  test "conference admin can update their conference-specific programs" do
    policy = ProgramPolicy.new(@conference_admin, @conference_program)
    assert policy.update?
  end

  test "conference lead cannot update programs for other conferences" do
    other_conference = Conference.create!(
      name: "Other Conference",
      village: @village,
      start_date: Date.tomorrow + 10.days,
      end_date: Date.tomorrow + 13.days
    )
    other_program = Program.create!(name: "Other Program", village: @village, conference: other_conference)
    policy = ProgramPolicy.new(@conference_lead, other_program)
    assert_not policy.update?
  end

  test "conference lead can destroy their conference-specific programs" do
    policy = ProgramPolicy.new(@conference_lead, @conference_program)
    assert policy.destroy?
  end

  test "village admin can manage conference-specific programs" do
    policy = ProgramPolicy.new(@village_admin, @conference_program)
    assert policy.create?
    assert policy.update?
    assert policy.destroy?
  end

  test "volunteer cannot create conference-specific programs" do
    policy = ProgramPolicy.new(@volunteer, Program.new(village: @village, conference: @conference))
    assert_not policy.create?
  end

  # Program lead tests
  test "program lead can update their assigned program" do
    policy = ProgramPolicy.new(@program_lead, @village_program)
    assert policy.update?
  end

  test "program lead cannot update programs they don't lead" do
    other_program = Program.create!(name: "Other Village Program", village: @village)
    policy = ProgramPolicy.new(@program_lead, other_program)
    assert_not policy.update?
  end

  test "program lead cannot destroy their assigned program" do
    # Only village admins can destroy village-level programs
    policy = ProgramPolicy.new(@program_lead, @village_program)
    assert_not policy.destroy?
  end

  test "program lead cannot create new programs" do
    policy = ProgramPolicy.new(@program_lead, Program.new(village: @village))
    assert_not policy.create?
  end

  test "program lead can update conference-specific program they lead" do
    ProgramRole.create!(user: @program_lead, program: @conference_program, role_name: ProgramRole::PROGRAM_LEAD)
    policy = ProgramPolicy.new(@program_lead, @conference_program)
    assert policy.update?
  end
end
