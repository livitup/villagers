require "test_helper"

class ProgramRolesControllerTest < ActionDispatch::IntegrationTest
  setup do
    @village = Village.create!(name: "Test Village", setup_complete: true)
    @program = Program.create!(name: "Test Program", description: "Test", village: @village)

    @village_admin = User.create!(
      email: "admin@example.com",
      password: "password123",
      password_confirmation: "password123"
    )
    village_admin_role = Role.find_or_create_by!(name: Role::VILLAGE_ADMIN)
    UserRole.create!(user: @village_admin, role: village_admin_role)

    @program_lead = User.create!(
      email: "lead@example.com",
      password: "password123",
      password_confirmation: "password123"
    )

    @volunteer = User.create!(
      email: "volunteer@example.com",
      password: "password123",
      password_confirmation: "password123"
    )

    @new_lead = User.create!(
      email: "newlead@example.com",
      password: "password123",
      password_confirmation: "password123"
    )
  end

  test "village admin can add program lead" do
    sign_in @village_admin
    assert_difference "ProgramRole.count", 1 do
      post program_program_roles_path(@program), params: { user_id: @new_lead.id }
    end
    assert_redirected_to @program
    assert @new_lead.program_lead?(@program)
  end

  test "village admin can remove program lead" do
    ProgramRole.create!(user: @program_lead, program: @program, role_name: ProgramRole::PROGRAM_LEAD)
    sign_in @village_admin

    assert_difference "ProgramRole.count", -1 do
      delete program_program_role_path(@program, @program.program_roles.first)
    end
    assert_redirected_to @program
  end

  test "program lead can add another program lead" do
    ProgramRole.create!(user: @program_lead, program: @program, role_name: ProgramRole::PROGRAM_LEAD)
    sign_in @program_lead

    assert_difference "ProgramRole.count", 1 do
      post program_program_roles_path(@program), params: { user_id: @new_lead.id }
    end
    assert_redirected_to @program
  end

  test "program lead can remove another program lead" do
    role1 = ProgramRole.create!(user: @program_lead, program: @program, role_name: ProgramRole::PROGRAM_LEAD)
    role2 = ProgramRole.create!(user: @new_lead, program: @program, role_name: ProgramRole::PROGRAM_LEAD)
    sign_in @program_lead

    assert_difference "ProgramRole.count", -1 do
      delete program_program_role_path(@program, role2)
    end
    assert_redirected_to @program
  end

  test "volunteer cannot add program lead" do
    sign_in @volunteer
    assert_no_difference "ProgramRole.count" do
      post program_program_roles_path(@program), params: { user_id: @new_lead.id }
    end
    assert_redirected_to root_path
  end

  test "volunteer cannot remove program lead" do
    role = ProgramRole.create!(user: @program_lead, program: @program, role_name: ProgramRole::PROGRAM_LEAD)
    sign_in @volunteer

    assert_no_difference "ProgramRole.count" do
      delete program_program_role_path(@program, role)
    end
    assert_redirected_to root_path
  end

  test "adding duplicate program lead does not create new record" do
    ProgramRole.create!(user: @new_lead, program: @program, role_name: ProgramRole::PROGRAM_LEAD)
    sign_in @village_admin

    assert_no_difference "ProgramRole.count" do
      post program_program_roles_path(@program), params: { user_id: @new_lead.id }
    end
    assert_redirected_to @program
  end
end
