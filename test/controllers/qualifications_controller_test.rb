require "test_helper"

class QualificationsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @village = Village.create!(name: "Test Village", setup_complete: true)
    @qualification = Qualification.create!(
      name: "Test Qualification",
      description: "A test qualification",
      village: @village
    )
    @village_admin = User.create!(
      email: "admin@example.com",
      password: "password123",
      password_confirmation: "password123"
    )
    village_admin_role = Role.find_or_create_by!(name: Role::VILLAGE_ADMIN)
    UserRole.find_or_create_by!(user: @village_admin, role: village_admin_role)
    @village_admin.reload # Reload to ensure associations are loaded
    @volunteer = User.create!(
      email: "volunteer@example.com",
      password: "password123",
      password_confirmation: "password123"
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

  test "should get index" do
    sign_in_user(@volunteer)
    get qualifications_url
    assert_response :success
  end

  test "should get new" do
    sign_in_user(@village_admin)
    get new_qualification_url
    assert_response :success
  end

  test "should create qualification" do
    sign_in_user(@village_admin)
    assert_difference("Qualification.count") do
      post qualifications_url, params: {
        qualification: {
          name: "New Qualification",
          description: "A new qualification"
        }
      }
    end

    assert_redirected_to qualification_url(Qualification.last)
  end

  test "should show qualification" do
    sign_in_user(@volunteer)
    get qualification_url(@qualification)
    assert_response :success
  end

  test "should get edit" do
    sign_in_user(@village_admin)
    get edit_qualification_url(@qualification)
    assert_response :success
  end

  test "should update qualification" do
    sign_in_user(@village_admin)
    patch qualification_url(@qualification), params: {
      qualification: {
        name: "Updated Qualification",
        description: "Updated description"
      }
    }
    assert_redirected_to qualification_url(@qualification)
    @qualification.reload
    assert_equal "Updated Qualification", @qualification.name
  end

  test "should destroy qualification" do
    sign_in_user(@village_admin)
    assert_difference("Qualification.count", -1) do
      delete qualification_url(@qualification)
    end

    assert_redirected_to qualifications_url
  end

  test "should not allow volunteers to create qualifications" do
    sign_in_user(@volunteer)
    assert_no_difference("Qualification.count") do
      post qualifications_url, params: {
        qualification: {
          name: "New Qualification",
          description: "A new qualification"
        }
      }
    end
    # Pundit redirects unauthorized users instead of returning 403
    assert_redirected_to root_path
  end
end
