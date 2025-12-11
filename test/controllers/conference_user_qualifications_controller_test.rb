require "test_helper"

class ConferenceUserQualificationsControllerTest < ActionDispatch::IntegrationTest
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

    @qualification = ConferenceQualification.create!(
      name: "Test Qualification",
      description: "A test qualification",
      conference: @conference
    )
  end

  test "should grant qualification to user" do
    sign_in @conference_lead
    assert_difference("ConferenceUserQualification.count") do
      post conference_conference_user_qualifications_url(@conference), params: {
        user_id: @volunteer.id,
        conference_qualification_id: @qualification.id
      }
    end
    assert_redirected_to conference_conference_qualification_url(@conference, @qualification)
  end

  test "should not duplicate qualification grant" do
    ConferenceUserQualification.create!(
      user: @volunteer,
      conference_qualification: @qualification
    )

    sign_in @conference_lead
    assert_no_difference("ConferenceUserQualification.count") do
      post conference_conference_user_qualifications_url(@conference), params: {
        user_id: @volunteer.id,
        conference_qualification_id: @qualification.id
      }
    end
  end

  test "should revoke qualification from user" do
    user_qual = ConferenceUserQualification.create!(
      user: @volunteer,
      conference_qualification: @qualification
    )

    sign_in @conference_lead
    assert_difference("ConferenceUserQualification.count", -1) do
      delete conference_conference_user_qualification_url(@conference, user_qual)
    end
    assert_redirected_to conference_conference_qualification_url(@conference, @qualification)
  end

  test "volunteer cannot grant qualifications" do
    sign_in @volunteer
    assert_no_difference("ConferenceUserQualification.count") do
      post conference_conference_user_qualifications_url(@conference), params: {
        user_id: @volunteer.id,
        conference_qualification_id: @qualification.id
      }
    end
    assert_redirected_to root_path
  end
end
