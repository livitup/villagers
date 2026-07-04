require "test_helper"

# Self-service profile editing (#216). The key property: a volunteer can edit
# their own Display Name, callsign, and contact methods WITHOUT entering a
# current password — OAuth users have a random password they don't know.
class ProfilesControllerTest < ActionDispatch::IntegrationTest
  setup do
    @village = Village.create!(name: "Test Village", setup_complete: true)
    @user = User.create!(
      email: "test@example.com",
      password: "password123",
      password_confirmation: "password123",
      handle: "oldhandle"
    )
    sign_in @user
  end

  test "updates profile fields without a current password" do
    patch profile_path, params: {
      user: {
        handle: "N0CALL Bob",
        callsign: "N0CALL",
        phone: "555-1234",
        twitter: "@bob",
        signal: "bob.99",
        discord: "bob#1234"
      }
    }

    assert_redirected_to edit_user_registration_path
    @user.reload
    assert_equal "N0CALL Bob", @user.handle
    assert_equal "N0CALL", @user.callsign
    assert_equal "555-1234", @user.phone
    assert_equal "@bob", @user.twitter
    assert_equal "bob.99", @user.signal
    assert_equal "bob#1234", @user.discord
  end

  test "works for an OAuth user who has no known password" do
    oauth_user = User.new(email: "oauth@example.com", provider: "villager_oauth", uid: "uid-x", handle: "prefilled")
    oauth_user.password = Devise.friendly_token[0, 32]
    oauth_user.skip_confirmation!
    oauth_user.save!
    sign_in oauth_user

    patch profile_path, params: { user: { handle: "Chosen Name", callsign: "W1AW" } }

    assert_redirected_to edit_user_registration_path
    oauth_user.reload
    assert_equal "Chosen Name", oauth_user.handle
    assert_equal "W1AW", oauth_user.callsign
  end

  test "does not let the profile form change the password" do
    original = @user.encrypted_password
    patch profile_path, params: { user: { handle: "x", password: "hackedpassword" } }

    @user.reload
    assert_equal original, @user.encrypted_password
  end

  test "does not let the profile form change the email" do
    patch profile_path, params: { user: { handle: "x", email: "hacked@example.com" } }

    assert_equal "test@example.com", @user.reload.email
  end

  test "a blank Display Name falls back to the email rather than erroring" do
    patch profile_path, params: { user: { handle: "" } }

    assert_redirected_to edit_user_registration_path
    assert_equal "test@example.com", @user.reload.handle
  end

  test "the registration edit page renders the self-service profile form" do
    get edit_user_registration_path
    assert_response :success
    assert_select "form[action=?]", profile_path
    assert_select "input[name='user[handle]']"
    assert_select "input[name='user[callsign]']"
    assert_select "input[name='user[discord]']"
  end

  test "requires authentication" do
    sign_out @user
    patch profile_path, params: { user: { handle: "x" } }
    assert_redirected_to new_user_session_path
  end

  # --- completion modal ---

  test "shows the completion modal for an incomplete profile on a normal page" do
    # @user has a personalized handle but no contact method -> incomplete.
    assert @user.needs_profile_completion?
    get root_path
    assert_select "#profileCompletionModal"
  end

  test "does not show the completion modal once the profile is complete" do
    @user.update!(discord: "bob#1234")
    get root_path
    assert_select "#profileCompletionModal", count: 0
  end

  test "does not show the completion modal on the profile edit page itself" do
    get edit_user_registration_path
    assert_select "#profileCompletionModal", count: 0
  end
end
