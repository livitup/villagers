require "test_helper"

class AuthenticationTest < ActionDispatch::IntegrationTest
  test "should get new registration page" do
    get new_user_registration_path
    assert_response :success
  end

  test "should create new user with valid data" do
    assert_difference "User.count", 1 do
      post user_registration_path, params: {
        user: {
          email: "user@example.com",
          password: "password123",
          password_confirmation: "password123"
        }
      }
    end

    assert_redirected_to root_path
    user = User.find_by(email: "user@example.com")
    assert_not_nil user
    assert user.valid_password?("password123")
  end

  test "should not create user with invalid email" do
    assert_no_difference "User.count" do
      post user_registration_path, params: {
        user: {
          email: "invalid-email",
          password: "password123",
          password_confirmation: "password123"
        }
      }
    end

    assert_response :unprocessable_entity
  end

  test "should get new session page" do
    get new_user_session_path
    assert_response :success
  end

  test "should sign in with valid credentials" do
    user = User.create!(
      email: "user@example.com",
      password: "password123",
      password_confirmation: "password123"
    )

    post user_session_path, params: {
      user: {
        email: "user@example.com",
        password: "password123"
      }
    }

    assert_redirected_to root_path
  end

  test "should not sign in with invalid credentials" do
    post user_session_path, params: {
      user: {
        email: "wrong@example.com",
        password: "wrongpassword"
      }
    }

    assert_response :unprocessable_entity
  end

  test "should sign out" do
    user = User.create!(
      email: "user@example.com",
      password: "password123",
      password_confirmation: "password123"
    )
    sign_in user

    delete destroy_user_session_path

    assert_redirected_to root_path
  end

  test "should get password reset page" do
    get new_user_password_path
    assert_response :success
  end

  test "should send password reset email" do
    user = User.create!(
      email: "user@example.com",
      password: "password123",
      password_confirmation: "password123"
    )

    assert_emails 1 do
      post user_password_path, params: {
        user: { email: user.email }
      }
    end

    assert_redirected_to new_user_session_path
  end
end

