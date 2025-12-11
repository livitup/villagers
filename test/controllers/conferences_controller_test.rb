require "test_helper"

class ConferencesControllerTest < ActionDispatch::IntegrationTest
  setup do
    @village = Village.create!(name: "Test Village", setup_complete: true)
    @village_admin = User.create!(
      email: "admin@example.com",
      password: "password123",
      password_confirmation: "password123"
    )
    @volunteer = User.create!(
      email: "volunteer@example.com",
      password: "password123",
      password_confirmation: "password123"
    )
    @conference_lead = User.create!(
      email: "lead@example.com",
      password: "password123",
      password_confirmation: "password123"
    )

    # Make user a village admin
    village_admin_role = Role.create!(name: Role::VILLAGE_ADMIN)
    UserRole.create!(user: @village_admin, role: village_admin_role)

    @conference = Conference.create!(
      village: @village,
      name: "Test Conference",
      start_date: Date.today,
      end_date: Date.tomorrow
    )
  end

  test "should get index as volunteer" do
    sign_in @volunteer
    get conferences_url
    assert_response :success
  end

  test "should get index as village admin" do
    sign_in @village_admin
    get conferences_url
    assert_response :success
  end

  test "should get show as volunteer" do
    sign_in @volunteer
    get conference_url(@conference)
    assert_response :success
  end

  test "should get new as village admin" do
    sign_in @village_admin
    get new_conference_url
    assert_response :success
  end

  test "should not get new as volunteer" do
    sign_in @volunteer
    get new_conference_url
    assert_redirected_to root_path
  end

  test "should create conference as village admin" do
    sign_in @village_admin
    assert_difference("Conference.count") do
      post conferences_url, params: {
        conference: {
          name: "New Conference",
          country: "US",
          state: "NV",
          city: "Las Vegas",
          start_date: Date.today,
          end_date: Date.tomorrow,
          conference_hours_start: "09:00",
          conference_hours_end: "17:00"
        },
        conference_lead_id: @conference_lead.id
      }
    end

    assert_redirected_to conference_path(Conference.last)
    conference = Conference.last
    assert_equal "New Conference", conference.name
    assert_equal "Las Vegas", conference.city
    assert_equal "NV", conference.state
    assert_equal "US", conference.country
    assert conference.conference_roles.exists?(user: @conference_lead, role_name: ConferenceRole::CONFERENCE_LEAD)
  end

  test "should not create conference as volunteer" do
    sign_in @volunteer
    assert_no_difference("Conference.count") do
      post conferences_url, params: {
        conference: {
          name: "Hacked Conference",
          start_date: Date.today,
          end_date: Date.tomorrow
        }
      }
    end
    assert_redirected_to root_path
  end

  test "should get edit as village admin" do
    sign_in @village_admin
    get edit_conference_url(@conference)
    assert_response :success
  end

  test "should get edit as conference lead" do
    ConferenceRole.create!(
      user: @conference_lead,
      conference: @conference,
      role_name: ConferenceRole::CONFERENCE_LEAD
    )
    sign_in @conference_lead
    get edit_conference_url(@conference)
    assert_response :success
  end

  test "should not get edit as volunteer" do
    sign_in @volunteer
    get edit_conference_url(@conference)
    assert_redirected_to root_path
  end

  test "should update conference as village admin" do
    sign_in @village_admin
    patch conference_url(@conference), params: {
      conference: {
        name: "Updated Conference",
        country: "US",
        state: "CA",
        city: "San Francisco"
      }
    }
    assert_redirected_to @conference
    @conference.reload
    assert_equal "Updated Conference", @conference.name
    assert_equal "San Francisco", @conference.city
    assert_equal "CA", @conference.state
    assert_equal "US", @conference.country
  end

  test "should update conference lead" do
    sign_in @village_admin
    new_lead = User.create!(
      email: "newlead@example.com",
      password: "password123",
      password_confirmation: "password123"
    )
    patch conference_url(@conference), params: {
      conference: {
        name: @conference.name
      },
      conference_lead_id: new_lead.id
    }
    assert_redirected_to @conference
    assert @conference.conference_roles.exists?(user: new_lead, role_name: ConferenceRole::CONFERENCE_LEAD)
  end

  test "should destroy conference as village admin" do
    sign_in @village_admin
    assert_difference("Conference.count", -1) do
      delete conference_url(@conference)
    end
    assert_redirected_to conferences_path
  end

  test "should not destroy conference as volunteer" do
    sign_in @volunteer
    assert_no_difference("Conference.count") do
      delete conference_url(@conference)
    end
    assert_redirected_to root_path
  end
end
