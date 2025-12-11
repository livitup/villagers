require "test_helper"

class QualificationRemovalsControllerTest < ActionDispatch::IntegrationTest
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

    @global_qualification = Qualification.create!(
      name: "Global Qualification",
      description: "A global qualification",
      village: @village
    )
    # Give volunteer the global qualification
    UserQualification.create!(user: @volunteer, qualification: @global_qualification)
  end

  test "should get index showing users with removable qualifications" do
    sign_in @conference_lead
    get conference_qualification_removals_url(@conference)
    assert_response :success
  end

  test "should create removal for user's global qualification" do
    sign_in @conference_lead
    assert_difference("QualificationRemoval.count") do
      post conference_qualification_removals_url(@conference), params: {
        user_id: @volunteer.id,
        qualification_id: @global_qualification.id
      }
    end
    assert_redirected_to conference_qualification_removals_url(@conference)
  end

  test "should not duplicate removal" do
    QualificationRemoval.create!(
      user: @volunteer,
      qualification: @global_qualification,
      conference: @conference
    )

    sign_in @conference_lead
    assert_no_difference("QualificationRemoval.count") do
      post conference_qualification_removals_url(@conference), params: {
        user_id: @volunteer.id,
        qualification_id: @global_qualification.id
      }
    end
  end

  test "should destroy removal to restore qualification" do
    removal = QualificationRemoval.create!(
      user: @volunteer,
      qualification: @global_qualification,
      conference: @conference
    )

    sign_in @conference_lead
    assert_difference("QualificationRemoval.count", -1) do
      delete conference_qualification_removal_url(@conference, removal)
    end
    assert_redirected_to conference_qualification_removals_url(@conference)
  end

  test "volunteer cannot create removals" do
    sign_in @volunteer
    assert_no_difference("QualificationRemoval.count") do
      post conference_qualification_removals_url(@conference), params: {
        user_id: @volunteer.id,
        qualification_id: @global_qualification.id
      }
    end
    assert_redirected_to root_path
  end
end
