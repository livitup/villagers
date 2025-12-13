require "test_helper"

class ProgramRoleTest < ActiveSupport::TestCase
  setup do
    @village = Village.create!(name: "Test Village", setup_complete: true)
    @program = Program.create!(name: "Test Program", description: "Test", village: @village)
    @user = User.create!(email: "test@example.com", password: "password123", password_confirmation: "password123")
  end

  test "valid program role" do
    role = ProgramRole.new(user: @user, program: @program, role_name: ProgramRole::PROGRAM_LEAD)
    assert role.valid?
  end

  test "requires user" do
    role = ProgramRole.new(program: @program, role_name: ProgramRole::PROGRAM_LEAD)
    assert_not role.valid?
    assert_includes role.errors[:user], "must exist"
  end

  test "requires program" do
    role = ProgramRole.new(user: @user, role_name: ProgramRole::PROGRAM_LEAD)
    assert_not role.valid?
    assert_includes role.errors[:program], "must exist"
  end

  test "requires valid role_name" do
    role = ProgramRole.new(user: @user, program: @program, role_name: "invalid_role")
    assert_not role.valid?
    assert_includes role.errors[:role_name], "is not included in the list"
  end

  test "allows program_lead role_name" do
    role = ProgramRole.new(user: @user, program: @program, role_name: "program_lead")
    assert role.valid?
  end

  test "prevents duplicate user-program-role combinations" do
    ProgramRole.create!(user: @user, program: @program, role_name: ProgramRole::PROGRAM_LEAD)
    duplicate = ProgramRole.new(user: @user, program: @program, role_name: ProgramRole::PROGRAM_LEAD)
    assert_not duplicate.valid?
    assert_includes duplicate.errors[:user_id], "has already been taken"
  end

  test "allows same user to lead different programs" do
    program2 = Program.create!(name: "Another Program", description: "Test", village: @village)
    ProgramRole.create!(user: @user, program: @program, role_name: ProgramRole::PROGRAM_LEAD)
    role2 = ProgramRole.new(user: @user, program: program2, role_name: ProgramRole::PROGRAM_LEAD)
    assert role2.valid?
  end

  test "allows different users to lead same program" do
    user2 = User.create!(email: "other@example.com", password: "password123", password_confirmation: "password123")
    ProgramRole.create!(user: @user, program: @program, role_name: ProgramRole::PROGRAM_LEAD)
    role2 = ProgramRole.new(user: user2, program: @program, role_name: ProgramRole::PROGRAM_LEAD)
    assert role2.valid?
  end

  test "PROGRAM_LEAD constant is defined" do
    assert_equal "program_lead", ProgramRole::PROGRAM_LEAD
  end
end
