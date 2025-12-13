require "test_helper"

class UserTest < ActiveSupport::TestCase
  setup do
    @village = Village.create!(name: "Test Village", setup_complete: true)
    @user = User.create!(email: "test@example.com", password: "password123", password_confirmation: "password123")
    @program = Program.create!(name: "Test Program", description: "Test", village: @village)
  end

  # Program lead tests
  test "user can have program roles" do
    role = ProgramRole.create!(user: @user, program: @program, role_name: ProgramRole::PROGRAM_LEAD)
    assert_includes @user.program_roles, role
  end

  test "program_lead? returns true when user is a program lead" do
    ProgramRole.create!(user: @user, program: @program, role_name: ProgramRole::PROGRAM_LEAD)
    assert @user.program_lead?(@program)
  end

  test "program_lead? returns false when user is not a program lead" do
    assert_not @user.program_lead?(@program)
  end

  test "can_manage_program? returns true for village admin" do
    admin_role = Role.create!(name: Role::VILLAGE_ADMIN)
    UserRole.create!(user: @user, role: admin_role)
    assert @user.can_manage_program?(@program)
  end

  test "can_manage_program? returns true for program lead" do
    ProgramRole.create!(user: @user, program: @program, role_name: ProgramRole::PROGRAM_LEAD)
    assert @user.can_manage_program?(@program)
  end

  test "can_manage_program? returns true for conference lead of conference-specific program" do
    conference = Conference.create!(
      name: "Test Conference",
      village: @village,
      start_date: Date.tomorrow,
      end_date: Date.tomorrow + 3.days
    )
    conference_program = Program.create!(
      name: "Conference Program",
      village: @village,
      conference: conference
    )
    ConferenceRole.create!(user: @user, conference: conference, role_name: ConferenceRole::CONFERENCE_LEAD)
    assert @user.can_manage_program?(conference_program)
  end

  test "can_manage_program? returns false for regular user" do
    assert_not @user.can_manage_program?(@program)
  end

  test "led_programs returns programs where user is a lead" do
    program2 = Program.create!(name: "Another Program", description: "Test", village: @village)
    ProgramRole.create!(user: @user, program: @program, role_name: ProgramRole::PROGRAM_LEAD)

    assert_includes @user.led_programs, @program
    assert_not_includes @user.led_programs, program2
  end

  test "deleting user deletes associated program roles" do
    ProgramRole.create!(user: @user, program: @program, role_name: ProgramRole::PROGRAM_LEAD)

    assert_difference "ProgramRole.count", -1 do
      @user.destroy
    end
  end
end
