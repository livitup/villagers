require "test_helper"

class CalendarControllerTest < ActionDispatch::IntegrationTest
  setup do
    @village = Village.create!(name: "Test Village", setup_complete: true)
    @conference = Conference.create!(
      name: "Test Conference",
      city: "Test City", state: "NV", country: "US",
      start_date: Date.today + 1.day,
      end_date: Date.today + 2.days,
      conference_hours_start: Time.zone.parse("2000-01-01 09:00"),
      conference_hours_end: Time.zone.parse("2000-01-01 17:00"),
      village: @village
    )
    @user = User.create!(
      email: "user@example.com",
      password: "password123",
      password_confirmation: "password123"
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

  test "should get calendar view" do
    sign_in_user(@user)
    get conference_calendar_path(@conference)
    assert_response :success
  end

  test "should require authentication" do
    get conference_calendar_path(@conference)
    assert_redirected_to new_user_session_path
  end
end
