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

  # Edit action tests
  test "should get edit as village admin" do
    sign_in_user(@village_admin)
    get edit_managed_user_url(@volunteer)
    assert_response :success
  end

  test "should not get edit as volunteer" do
    sign_in_user(@volunteer)
    get edit_managed_user_url(@village_admin)
    assert_redirected_to root_path
  end

  test "edit page should display user profile fields" do
    sign_in_user(@village_admin)
    get edit_managed_user_url(@volunteer)
    assert_response :success
    assert_select "input[name='user[name]']"
    assert_select "input[name='user[handle]']"
    assert_select "input[name='user[phone]']"
    assert_select "input[name='user[twitter]']"
    assert_select "input[name='user[signal]']"
    assert_select "input[name='user[discord]']"
  end

  test "edit page should not have password fields" do
    sign_in_user(@village_admin)
    get edit_managed_user_url(@volunteer)
    assert_response :success
    assert_select "input[name='user[password]']", count: 0
    assert_select "input[name='user[password_confirmation]']", count: 0
  end

  # Update action tests
  test "should update user as village admin" do
    sign_in_user(@village_admin)
    patch managed_user_url(@volunteer), params: {
      user: {
        name: "Updated Name",
        handle: "newhandle",
        phone: "555-1234",
        twitter: "@newtwitter",
        signal: "newsignal",
        discord: "newdiscord#1234"
      }
    }
    assert_redirected_to managed_user_path(@volunteer)

    @volunteer.reload
    assert_equal "Updated Name", @volunteer.name
    assert_equal "newhandle", @volunteer.handle
    assert_equal "555-1234", @volunteer.phone
    assert_equal "@newtwitter", @volunteer.twitter
    assert_equal "newsignal", @volunteer.signal
    assert_equal "newdiscord#1234", @volunteer.discord
  end

  test "should not update user as volunteer" do
    sign_in_user(@volunteer)
    original_name = @village_admin.name
    patch managed_user_url(@village_admin), params: {
      user: { name: "Hacked Name" }
    }
    assert_redirected_to root_path

    @village_admin.reload
    assert_equal original_name, @village_admin.name
  end

  test "update should not change user email" do
    sign_in_user(@village_admin)
    original_email = @volunteer.email
    patch managed_user_url(@volunteer), params: {
      user: { email: "hacked@example.com", name: "New Name" }
    }
    assert_redirected_to managed_user_path(@volunteer)

    @volunteer.reload
    assert_equal original_email, @volunteer.email
    assert_equal "New Name", @volunteer.name
  end

  test "update should not change user password" do
    sign_in_user(@village_admin)
    original_password = @volunteer.encrypted_password
    patch managed_user_url(@volunteer), params: {
      user: { password: "newpassword123", password_confirmation: "newpassword123", name: "New Name" }
    }
    assert_redirected_to managed_user_path(@volunteer)

    @volunteer.reload
    assert_equal original_password, @volunteer.encrypted_password
    assert_equal "New Name", @volunteer.name
  end

  test "show page should have edit link for village admin" do
    sign_in_user(@village_admin)
    get managed_user_url(@volunteer)
    assert_response :success
    assert_select "a[href=?]", edit_managed_user_path(@volunteer)
  end
end
