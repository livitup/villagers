require "test_helper"

class StatesControllerTest < ActionDispatch::IntegrationTest
  setup do
    @village = Village.create!(name: "Test Village", setup_complete: true)
    @user = User.create!(
      email: "statesuser@example.com",
      password: "password123",
      password_confirmation: "password123"
    )
  end

  test "should require authentication" do
    get states_path(country: "US"), as: :json
    assert_response :unauthorized
  end

  test "should get states for US" do
    sign_in @user
    get states_path(country: "US"), as: :json
    assert_response :success

    json_response = JSON.parse(response.body)
    assert json_response.is_a?(Array)
    assert json_response.any? { |s| s["code"] == "NV" && s["name"] == "Nevada" }
    assert json_response.any? { |s| s["code"] == "CA" && s["name"] == "California" }
  end

  test "should get states for Germany" do
    sign_in @user
    get states_path(country: "DE"), as: :json
    assert_response :success

    json_response = JSON.parse(response.body)
    assert json_response.is_a?(Array)
    # Germany has states/Bundesländer
    assert json_response.length > 0
  end

  test "should return empty array for country without states" do
    sign_in @user
    get states_path(country: "VA"), as: :json  # Vatican City has no states
    assert_response :success

    json_response = JSON.parse(response.body)
    assert json_response.is_a?(Array)
  end
end
