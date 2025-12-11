require "test_helper"

class ConferenceQualificationsControllerTest < ActionDispatch::IntegrationTest
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
    @admin = User.create!(
      email: "admin@example.com",
      password: "password123",
      password_confirmation: "password123"
    )
    admin_role = Role.find_or_create_by!(name: Role::VILLAGE_ADMIN)
    UserRole.create!(user: @admin, role: admin_role)

    @conference_lead = User.create!(
      email: "lead@example.com",
      password: "password123",
      password_confirmation: "password123"
    )
    ConferenceRole.create!(
      user: @conference_lead,
      conference: @conference,
      role_name: ConferenceRole::CONFERENCE_LEAD
    )

    @volunteer = User.create!(
      email: "volunteer@example.com",
      password: "password123",
      password_confirmation: "password123"
    )

    @qualification = ConferenceQualification.create!(
      name: "Test Qualification",
      description: "A test qualification",
      conference: @conference
    )
  end

  test "should redirect to login when not signed in" do
    get conference_conference_qualifications_url(@conference)
    assert_redirected_to new_user_session_path
  end

  test "should get index for conference lead" do
    sign_in @conference_lead
    get conference_conference_qualifications_url(@conference)
    assert_response :success
  end

  test "should get index for village admin" do
    sign_in @admin
    get conference_conference_qualifications_url(@conference)
    assert_response :success
  end

  test "should redirect volunteer from index" do
    sign_in @volunteer
    get conference_conference_qualifications_url(@conference)
    assert_redirected_to root_path
  end

  test "should get new for conference lead" do
    sign_in @conference_lead
    get new_conference_conference_qualification_url(@conference)
    assert_response :success
  end

  test "should create qualification for conference lead" do
    sign_in @conference_lead
    assert_difference("ConferenceQualification.count") do
      post conference_conference_qualifications_url(@conference), params: {
        conference_qualification: {
          name: "New Qualification",
          description: "A new qualification"
        }
      }
    end
    assert_redirected_to conference_conference_qualification_url(@conference, ConferenceQualification.last)
  end

  test "should get edit for conference lead" do
    sign_in @conference_lead
    get edit_conference_conference_qualification_url(@conference, @qualification)
    assert_response :success
  end

  test "should update qualification for conference lead" do
    sign_in @conference_lead
    patch conference_conference_qualification_url(@conference, @qualification), params: {
      conference_qualification: {
        name: "Updated Name",
        description: "Updated description"
      }
    }
    assert_redirected_to conference_conference_qualification_url(@conference, @qualification)
    @qualification.reload
    assert_equal "Updated Name", @qualification.name
  end

  test "should destroy qualification for conference lead" do
    sign_in @conference_lead
    assert_difference("ConferenceQualification.count", -1) do
      delete conference_conference_qualification_url(@conference, @qualification)
    end
    assert_redirected_to conference_conference_qualifications_url(@conference)
  end
end
