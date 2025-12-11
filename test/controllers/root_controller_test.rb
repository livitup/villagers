require "test_helper"

class RootControllerTest < ActionDispatch::IntegrationTest
  def setup
    @village = Village.create!(name: "Test Village", setup_complete: true)
  end

  test "should get root when setup is complete" do
    get root_url
    assert_response :success
  end

  test "should redirect root to setup when setup is not complete" do
    Village.destroy_all
    get root_url
    assert_redirected_to setup_url
  end

  test "should get root when signed in" do
    user = User.create!(
      email: "user@example.com",
      password: "password123",
      password_confirmation: "password123"
    )
    sign_in user
    get root_url
    assert_response :success
  end

  test "should show conference lead dashboard card when user is conference lead" do
    conference = Conference.create!(
      name: "Test Conference",
      village: @village,
      start_date: Date.tomorrow,
      end_date: Date.tomorrow + 3.days
    )
    user = User.create!(
      email: "lead@example.com",
      password: "password123",
      password_confirmation: "password123"
    )
    ConferenceRole.create!(
      user: user,
      conference: conference,
      role_name: ConferenceRole::CONFERENCE_LEAD
    )

    sign_in user
    get root_url

    assert_response :success
    assert_select ".card-header", text: /My Conferences/
    assert_select ".card-body", text: /Test Conference/
  end

  test "should not show conference lead dashboard card when user is not a conference lead" do
    user = User.create!(
      email: "volunteer@example.com",
      password: "password123",
      password_confirmation: "password123"
    )

    sign_in user
    get root_url

    assert_response :success
    assert_select ".card-header", text: /My Conferences/, count: 0
  end

  test "should show multiple conferences when user is lead of multiple conferences" do
    conference1 = Conference.create!(
      name: "Conference Alpha",
      village: @village,
      start_date: Date.tomorrow,
      end_date: Date.tomorrow + 3.days
    )
    conference2 = Conference.create!(
      name: "Conference Beta",
      village: @village,
      start_date: Date.tomorrow + 7.days,
      end_date: Date.tomorrow + 10.days
    )
    user = User.create!(
      email: "multlead@example.com",
      password: "password123",
      password_confirmation: "password123"
    )
    ConferenceRole.create!(user: user, conference: conference1, role_name: ConferenceRole::CONFERENCE_LEAD)
    ConferenceRole.create!(user: user, conference: conference2, role_name: ConferenceRole::CONFERENCE_LEAD)

    sign_in user
    get root_url

    assert_response :success
    assert_select ".card-body", text: /Conference Alpha/
    assert_select ".card-body", text: /Conference Beta/
  end

  test "should not show conference lead card for unauthenticated users" do
    get root_url

    assert_response :success
    assert_select ".card-header", text: /My Conferences/, count: 0
  end
end
