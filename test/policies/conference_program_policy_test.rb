require "test_helper"

class ConferenceProgramPolicyTest < ActiveSupport::TestCase
  setup do
    @village = Village.create!(name: "Test Village", setup_complete: true)
    @conference = Conference.create!(
      name: "Test Conference",
      city: "Test City", state: "NV", country: "US",
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
      email: "admin2@example.com",
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

    @other_conference = Conference.create!(
      name: "Other Conference",
      city: "Other City", state: "CA", country: "US",
      start_date: Date.today + 10.days,
      end_date: Date.today + 12.days,
      conference_hours_start: Time.parse("09:00"),
      conference_hours_end: Time.parse("17:00"),
      village: @village
    )
    @other_lead = User.create!(
      email: "otherlead@example.com",
      password: "password123",
      password_confirmation: "password123"
    )
    ConferenceRole.create!(
      user: @other_lead,
      conference: @other_conference,
      role_name: ConferenceRole::CONFERENCE_LEAD
    )
  end

  test "village admin can manage conference programs" do
    policy = ConferenceProgramPolicy.new(@village_admin, @conference_program)
    assert policy.index?
    assert policy.show?
    assert policy.create?
    assert policy.update?
    assert policy.destroy?
  end

  test "conference lead can manage their conference programs" do
    policy = ConferenceProgramPolicy.new(@conference_lead, @conference_program)
    assert policy.index?
    assert policy.show?
    assert policy.create?
    assert policy.update?
    assert policy.destroy?
  end

  test "conference admin can manage their conference programs" do
    policy = ConferenceProgramPolicy.new(@conference_admin, @conference_program)
    assert policy.index?
    assert policy.show?
    assert policy.create?
    assert policy.update?
    assert policy.destroy?
  end

  test "volunteer cannot manage conference programs" do
    policy = ConferenceProgramPolicy.new(@volunteer, @conference_program)
    assert_not policy.index?
    assert_not policy.show?
    assert_not policy.create?
    assert_not policy.update?
    assert_not policy.destroy?
  end

  test "conference lead cannot manage other conference programs" do
    other_cp = ConferenceProgram.create!(
      conference: @other_conference,
      program: @program,
      public_description: "Other"
    )
    policy = ConferenceProgramPolicy.new(@conference_lead, other_cp)
    assert_not policy.index?
    assert_not policy.show?
    assert_not policy.create?
    assert_not policy.update?
    assert_not policy.destroy?
  end

  test "anonymous user cannot manage conference programs" do
    policy = ConferenceProgramPolicy.new(nil, @conference_program)
    assert_not policy.index?
    assert_not policy.show?
    assert_not policy.create?
    assert_not policy.update?
    assert_not policy.destroy?
  end
end
