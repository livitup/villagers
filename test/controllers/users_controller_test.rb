require "test_helper"

class UsersControllerTest < ActionDispatch::IntegrationTest
  setup do
    @village = Village.create!(name: "Test Village", setup_complete: true)
    @village_admin = User.create!(
      email: "admin@example.com",
      password: "password123",
      password_confirmation: "password123",
      name: "Admin User",
      handle: "admin"
    )
    village_admin_role = Role.find_or_create_by!(name: Role::VILLAGE_ADMIN)
    UserRole.find_or_create_by!(user: @village_admin, role: village_admin_role)
    @village_admin.reload

    @volunteer = User.create!(
      email: "volunteer@example.com",
      password: "password123",
      password_confirmation: "password123",
      name: "Volunteer User",
      handle: "volunteer"
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

  test "should get index as village admin" do
    sign_in_user(@village_admin)
    get managed_users_url
    assert_response :success
  end

  test "should not get index as volunteer" do
    sign_in_user(@volunteer)
    get managed_users_url
    assert_redirected_to root_path
  end

  test "should show user as village admin" do
    sign_in_user(@village_admin)
    get managed_user_url(@volunteer)
    assert_response :success
  end

  test "should not show user as volunteer" do
    sign_in_user(@volunteer)
    get managed_user_url(@village_admin)
    assert_redirected_to root_path
  end

  test "should display user qualifications on show page" do
    UserQualification.create!(user: @volunteer, qualification: @qualification)
    sign_in_user(@village_admin)
    get managed_user_url(@volunteer)
    assert_response :success
    assert_match @qualification.name, response.body
  end

  test "should list all users on index page" do
    sign_in_user(@village_admin)
    get managed_users_url
    assert_response :success
    assert_match @volunteer.email, response.body
    assert_match @village_admin.email, response.body
  end
end
