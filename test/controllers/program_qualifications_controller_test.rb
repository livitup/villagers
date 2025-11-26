require "test_helper"

class ProgramQualificationsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @village = Village.create!(name: "Test Village", setup_complete: true)
    @village_admin = User.create!(
      email: "admin@example.com",
      password: "password123",
      password_confirmation: "password123"
    )
    village_admin_role = Role.find_or_create_by!(name: Role::VILLAGE_ADMIN)
    UserRole.find_or_create_by!(user: @village_admin, role: village_admin_role)
    @village_admin.reload

    @volunteer = User.create!(
      email: "volunteer@example.com",
      password: "password123",
      password_confirmation: "password123"
    )

    @program = Program.create!(
      name: "Test Program",
      description: "A test program",
      village: @village
    )

    @qualification = Qualification.create!(
      name: "Test Qualification",
      description: "A test qualification",
      village: @village
    )
  end

  def sign_in_user(user)
    post user_session_path, params: {
      user: {
        email: user.email,
        password: "password123"
      }
    }
  end

  test "village admin can add qualification requirement to program" do
    sign_in_user(@village_admin)
    assert_difference("ProgramQualification.count") do
      post program_program_qualifications_url(@program), params: {
        qualification_id: @qualification.id
      }
    end
    assert_redirected_to program_url(@program)
    assert @program.reload.qualifications.include?(@qualification)
  end

  test "village admin can remove qualification requirement from program" do
    program_qualification = ProgramQualification.create!(
      program: @program,
      qualification: @qualification
    )
    sign_in_user(@village_admin)
    assert_difference("ProgramQualification.count", -1) do
      delete program_program_qualification_url(@program, program_qualification)
    end
    assert_redirected_to program_url(@program)
    assert_not @program.reload.qualifications.include?(@qualification)
  end

  test "volunteer cannot add qualification requirement to program" do
    sign_in_user(@volunteer)
    assert_no_difference("ProgramQualification.count") do
      post program_program_qualifications_url(@program), params: {
        qualification_id: @qualification.id
      }
    end
    assert_redirected_to root_path
  end

  test "volunteer cannot remove qualification requirement from program" do
    program_qualification = ProgramQualification.create!(
      program: @program,
      qualification: @qualification
    )
    sign_in_user(@volunteer)
    assert_no_difference("ProgramQualification.count") do
      delete program_program_qualification_url(@program, program_qualification)
    end
    assert_redirected_to root_path
  end
end
