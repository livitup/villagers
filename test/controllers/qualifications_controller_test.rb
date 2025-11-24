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
    @village_admin_role = Role.find_or_create_by!(name: Role::VILLAGE_ADMIN)
    UserRole.find_or_create_by!(user: @village_admin, role: @village_admin_role)
    @volunteer = User.create!(
      email: "volunteer@example.com",
      password: "password123",
      password_confirmation: "password123"
    )
  end

  test "should get index" do
    sign_in @volunteer
    get qualifications_url
    assert_response :success
  end

  test "should get new" do
    sign_in @village_admin
    get new_qualification_url
    assert_response :success
  end

  test "should create qualification" do
    sign_in @village_admin
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
    sign_in @volunteer
    get qualification_url(@qualification)
    assert_response :success
  end

  test "should get edit" do
    sign_in @village_admin
    get edit_qualification_url(@qualification)
    assert_response :success
  end

  test "should update qualification" do
    sign_in @village_admin
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
    sign_in @village_admin
    assert_difference("Qualification.count", -1) do
      delete qualification_url(@qualification)
    end

    assert_redirected_to qualifications_url
  end

  test "should not allow volunteers to create qualifications" do
    sign_in @volunteer
    assert_no_difference("Qualification.count") do
      post qualifications_url, params: {
        qualification: {
          name: "New Qualification",
          description: "A new qualification"
        }
      }
    end
    assert_response :forbidden
  end
end
