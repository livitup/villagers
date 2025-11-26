require "test_helper"

class UserQualificationsControllerTest < ActionDispatch::IntegrationTest
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

  test "village admin can grant qualification to user" do
    sign_in_user(@village_admin)
    assert_difference("UserQualification.count") do
      post managed_user_user_qualifications_url(@volunteer), params: {
        qualification_id: @qualification.id
      }
    end
    assert_redirected_to managed_user_url(@volunteer)
    assert @volunteer.reload.has_qualification?(@qualification)
  end

  test "village admin can remove qualification from user" do
    user_qualification = UserQualification.create!(
      user: @volunteer,
      qualification: @qualification
    )
    sign_in_user(@village_admin)
    assert_difference("UserQualification.count", -1) do
      delete managed_user_user_qualification_url(@volunteer, user_qualification)
    end
    assert_redirected_to managed_user_url(@volunteer)
    assert_not @volunteer.reload.has_qualification?(@qualification)
  end

  test "volunteer cannot grant qualification to user" do
    sign_in_user(@volunteer)
    assert_no_difference("UserQualification.count") do
      post managed_user_user_qualifications_url(@volunteer), params: {
        qualification_id: @qualification.id
      }
    end
    assert_redirected_to root_path
  end

  test "volunteer cannot remove qualification from user" do
    user_qualification = UserQualification.create!(
      user: @volunteer,
      qualification: @qualification
    )
    sign_in_user(@volunteer)
    assert_no_difference("UserQualification.count") do
      delete managed_user_user_qualification_url(@volunteer, user_qualification)
    end
    assert_redirected_to root_path
  end
end
