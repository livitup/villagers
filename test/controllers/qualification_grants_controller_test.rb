require "test_helper"

class QualificationGrantsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @village = Village.create!(name: "Test Village", setup_complete: true)
    @conference = Conference.create!(
      village: @village, name: "Test Conference",
      start_date: Date.tomorrow, end_date: Date.tomorrow + 2.days
    )
    @foobar = Qualification.create!(village: @village, name: "Foobar", description: "Can foo")
    @bazzer = Qualification.create!(village: @village, name: "Bazzer", description: "Can baz")

    @village_admin = User.create!(email: "admin@example.com", password: "password123", password_confirmation: "password123")
    UserRole.create!(user: @village_admin, role: Role.find_or_create_by!(name: Role::VILLAGE_ADMIN))

    @delegate = User.create!(email: "delegate@example.com", password: "password123", password_confirmation: "password123")
    QualificationAssignmentDelegation.create!(user: @delegate, qualification: @foobar, conference: @conference)

    @volunteer = User.create!(email: "volunteer@example.com", password: "password123", password_confirmation: "password123")
    @recipient = User.create!(email: "recipient@example.com", password: "password123", password_confirmation: "password123")
  end

  def grants_url
    conference_qualification_grants_url(@conference)
  end

  # --- index visibility ---
  test "a manager can view the assign page" do
    sign_in @village_admin
    get grants_url
    assert_response :success
  end

  test "a delegate can view the assign page" do
    sign_in @delegate
    get grants_url
    assert_response :success
  end

  test "a user with no delegation cannot view the assign page" do
    sign_in @volunteer
    get grants_url
    assert_redirected_to root_path
  end

  # --- granting ---
  test "a manager can grant any qualification" do
    sign_in @village_admin
    assert_difference("UserQualification.count", 1) do
      post grants_url, params: { user_id: @recipient.id, qualification_id: @bazzer.id }
    end
    assert @recipient.has_qualification?(@bazzer)
  end

  test "a delegate can grant their delegated qualification" do
    sign_in @delegate
    assert_difference("UserQualification.count", 1) do
      post grants_url, params: { user_id: @recipient.id, qualification_id: @foobar.id }
    end
    assert @recipient.has_qualification?(@foobar)
  end

  test "a delegate cannot grant a non-delegated qualification" do
    sign_in @delegate
    assert_no_difference("UserQualification.count") do
      post grants_url, params: { user_id: @recipient.id, qualification_id: @bazzer.id }
    end
    assert_redirected_to root_path
    assert_not @recipient.has_qualification?(@bazzer)
  end

  # --- revoking ---
  test "a delegate can revoke a qualification they can assign" do
    uq = UserQualification.create!(user: @recipient, qualification: @foobar)
    sign_in @delegate
    assert_difference("UserQualification.count", -1) do
      delete conference_qualification_grant_url(@conference, uq)
    end
  end

  test "a delegate cannot revoke a non-delegated qualification" do
    uq = UserQualification.create!(user: @recipient, qualification: @bazzer)
    sign_in @delegate
    assert_no_difference("UserQualification.count") do
      delete conference_qualification_grant_url(@conference, uq)
    end
    assert_redirected_to root_path
  end

  test "unauthenticated requests redirect to sign-in" do
    post grants_url, params: { user_id: @recipient.id, qualification_id: @foobar.id }
    assert_redirected_to new_user_session_path
  end
end
