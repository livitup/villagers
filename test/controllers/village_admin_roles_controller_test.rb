require "test_helper"

# Granting/revoking the village admin role from the managed-user page (#263).
class VillageAdminRolesControllerTest < ActionDispatch::IntegrationTest
  setup do
    @village = Village.create!(name: "Test Village", setup_complete: true)
    @admin = create_user("admin@example.com")
    @admin_role = Role.find_or_create_by!(name: Role::VILLAGE_ADMIN)
    UserRole.create!(user: @admin, role: @admin_role)
    @volunteer = create_user("volunteer@example.com")
  end

  def create_user(email)
    user = User.new(email: email, password: "password123", password_confirmation: "password123")
    user.skip_confirmation!
    user.save!
    user
  end

  test "a village admin can grant the role" do
    sign_in @admin

    post managed_user_village_admin_role_path(@volunteer)

    assert_redirected_to managed_user_path(@volunteer)
    assert @volunteer.reload.village_admin?
    assert_match(/village admin/i, flash[:notice])
  end

  test "granting is idempotent for a user who already has the role" do
    UserRole.create!(user: @volunteer, role: @admin_role)
    sign_in @admin

    assert_no_difference "UserRole.count" do
      post managed_user_village_admin_role_path(@volunteer)
    end
    assert @volunteer.reload.village_admin?
  end

  test "a village admin can revoke the role from another admin" do
    UserRole.create!(user: @volunteer, role: @admin_role)
    sign_in @admin

    delete managed_user_village_admin_role_path(@volunteer)

    assert_redirected_to managed_user_path(@volunteer)
    assert_not @volunteer.reload.village_admin?
    assert @admin.reload.village_admin?, "the acting admin keeps their role"
  end

  test "revoking the last remaining village admin is blocked" do
    sign_in @admin

    delete managed_user_village_admin_role_path(@admin)

    assert @admin.reload.village_admin?, "the last admin must survive"
    assert_match(/last village admin/i, flash[:alert])
  end

  test "an admin may revoke their own role when another admin exists" do
    UserRole.create!(user: @volunteer, role: @admin_role)
    sign_in @admin

    delete managed_user_village_admin_role_path(@admin)

    assert_not @admin.reload.village_admin?
    assert @volunteer.reload.village_admin?
  end

  test "revoking from a user who is not an admin is a no-op with a notice" do
    sign_in @admin

    delete managed_user_village_admin_role_path(@volunteer)

    assert_redirected_to managed_user_path(@volunteer)
    assert_not @volunteer.reload.village_admin?
  end

  test "a non-admin cannot grant or revoke" do
    sign_in @volunteer

    post managed_user_village_admin_role_path(@volunteer)
    assert_redirected_to root_path
    assert_not @volunteer.reload.village_admin?

    delete managed_user_village_admin_role_path(@admin)
    assert_redirected_to root_path
    assert @admin.reload.village_admin?
  end

  test "unauthenticated users are sent to login" do
    post managed_user_village_admin_role_path(@volunteer)
    assert_redirected_to new_user_session_path

    delete managed_user_village_admin_role_path(@admin)
    assert_redirected_to new_user_session_path
  end

  # --- the controls on the managed-user page ---

  test "the user page offers Grant for a non-admin and Revoke for an admin" do
    sign_in @admin

    get managed_user_path(@volunteer)
    assert_select "form[action='#{managed_user_village_admin_role_path(@volunteer)}']" do
      assert_select "button", text: /make village admin/i
    end

    get managed_user_path(@admin)
    assert_select "form[action='#{managed_user_village_admin_role_path(@admin)}']" do
      assert_select "button", text: /revoke village admin/i
    end
  end
end
