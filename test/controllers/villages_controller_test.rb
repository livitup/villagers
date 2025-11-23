require "test_helper"

class VillagesControllerTest < ActionDispatch::IntegrationTest
  setup do
    @village = Village.create!(name: "Test Village", setup_complete: true)
    @village_admin = User.create!(
      email: "admin@example.com",
      password: "password123",
      password_confirmation: "password123"
    )
    @volunteer = User.create!(
      email: "volunteer@example.com",
      password: "password123",
      password_confirmation: "password123"
    )

    # Make user a village admin
    village_admin_role = Role.create!(name: Role::VILLAGE_ADMIN)
    UserRole.create!(user: @village_admin, role: village_admin_role)
  end

  test "should get show as volunteer" do
    sign_in @volunteer
    get village_path
    assert_response :success
  end

  test "should get show as village admin" do
    sign_in @village_admin
    get village_path
    assert_response :success
  end

  test "should get edit as village admin" do
    sign_in @village_admin
    get edit_village_path
    assert_response :success
  end

  test "should not get edit as volunteer" do
    sign_in @volunteer
    get edit_village_path
    assert_redirected_to root_path
  end

  test "should update village as village admin" do
    sign_in @village_admin
    patch village_path, params: { village: { name: "Updated Village Name" } }
    assert_redirected_to village_path
    @village.reload
    assert_equal "Updated Village Name", @village.name
  end

  test "should not update village as volunteer" do
    sign_in @volunteer
    original_name = @village.name
    patch village_path, params: { village: { name: "Hacked Name" } }
    assert_redirected_to root_path
    @village.reload
    assert_equal original_name, @village.name
  end

  test "should redirect to setup if village does not exist" do
    Village.destroy_all
    sign_in @village_admin
    get village_path
    assert_redirected_to setup_path
  end
end
