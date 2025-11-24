require "test_helper"

class RootControllerTest < ActionDispatch::IntegrationTest
  test "should get root when setup is complete" do
    Village.create!(name: "Test Village", setup_complete: true)
    get root_url
    assert_response :success
  end

  test "should redirect root to setup when setup is not complete" do
    Village.destroy_all
    get root_url
    assert_redirected_to setup_url
  end

  test "should get root when signed in" do
    Village.create!(name: "Test Village", setup_complete: true)
    user = User.create!(
      email: "user@example.com",
      password: "password123",
      password_confirmation: "password123"
    )
    sign_in user
    get root_url
    assert_response :success
  end
end
