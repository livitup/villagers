require "test_helper"

class SetupControllerTest < ActionDispatch::IntegrationTest
  test "should get show when setup is not complete" do
    get setup_url
    assert_response :success
  end

  test "should redirect from show when setup is complete" do
    Village.create!(name: "Test Village", setup_complete: true)
    get setup_url
    assert_redirected_to root_url
  end

  test "should create village and admin user on valid submission" do
    assert_difference -> { Village.count } => 1, -> { User.count } => 1 do
      post setup_url, params: {
        village: { name: "Ham Radio Village" },
        user: {
          email: "admin@example.com",
          password: "password123",
          password_confirmation: "password123"
        }
      }
    end

    village = Village.last
    assert_equal "Ham Radio Village", village.name
    assert village.setup_complete?

    user = User.last
    assert_equal "admin@example.com", user.email
    assert user.valid_password?("password123")
  end

  test "should not create village with invalid data" do
    assert_no_difference [ "Village.count", "User.count" ] do
      post setup_url, params: {
        village: { name: "" },
        user: {
          email: "invalid",
          password: "short",
          password_confirmation: "different"
        }
      }
    end

    assert_response :unprocessable_entity
  end

  test "should not allow setup when already complete" do
    Village.create!(name: "Existing Village", setup_complete: true)

    assert_no_difference [ "Village.count", "User.count" ] do
      post setup_url, params: {
        village: { name: "New Village" },
        user: {
          email: "admin@example.com",
          password: "password123",
          password_confirmation: "password123"
        }
      }
    end

    assert_redirected_to root_url
  end
end
