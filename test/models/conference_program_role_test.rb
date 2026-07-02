require "test_helper"

class ConferenceProgramRoleTest < ActiveSupport::TestCase
  setup do
    @village = Village.create!(name: "Test Village", setup_complete: true)
    @conference = Conference.create!(
      name: "Test Conference",
      city: "Test City", state: "NV", country: "US",
      start_date: Date.today + 1.day,
      end_date: Date.today + 3.days,
      village: @village
    )
    @program = Program.create!(name: "Test Program", description: "A test program", village: @village)
    @conference_program = ConferenceProgram.create!(conference: @conference, program: @program)
    @user = User.create!(email: "lead@example.com", password: "password123", password_confirmation: "password123")
  end

  test "is valid with an activity_lead role" do
    role = ConferenceProgramRole.new(
      user: @user, conference_program: @conference_program, role_name: ConferenceProgramRole::ACTIVITY_LEAD
    )
    assert role.valid?
  end

  test "rejects an unknown role_name" do
    role = ConferenceProgramRole.new(
      user: @user, conference_program: @conference_program, role_name: "wizard"
    )
    assert_not role.valid?
  end

  test "does not allow duplicate role for the same user and program" do
    ConferenceProgramRole.create!(
      user: @user, conference_program: @conference_program, role_name: ConferenceProgramRole::ACTIVITY_LEAD
    )
    dup = ConferenceProgramRole.new(
      user: @user, conference_program: @conference_program, role_name: ConferenceProgramRole::ACTIVITY_LEAD
    )
    assert_not dup.valid?
  end

  test "User#activity_lead? reflects the role" do
    assert_not @user.activity_lead?(@conference_program)
    ConferenceProgramRole.create!(
      user: @user, conference_program: @conference_program, role_name: ConferenceProgramRole::ACTIVITY_LEAD
    )
    assert @user.reload.activity_lead?(@conference_program)
  end

  test "User#can_manage_conference_program? is true for the activity lead and false otherwise" do
    other_program = Program.create!(name: "Other", description: "other", village: @village)
    other_cp = ConferenceProgram.create!(conference: @conference, program: other_program)

    ConferenceProgramRole.create!(
      user: @user, conference_program: @conference_program, role_name: ConferenceProgramRole::ACTIVITY_LEAD
    )

    assert @user.can_manage_conference_program?(@conference_program)
    assert_not @user.can_manage_conference_program?(other_cp)
  end

  test "ConferenceProgram#activity_leads lists assigned leads" do
    ConferenceProgramRole.create!(
      user: @user, conference_program: @conference_program, role_name: ConferenceProgramRole::ACTIVITY_LEAD
    )
    assert_includes @conference_program.activity_leads, @user
  end
end
