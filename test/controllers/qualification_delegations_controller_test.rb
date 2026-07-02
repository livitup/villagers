require "test_helper"

class QualificationDelegationsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @village = Village.create!(name: "Test Village", setup_complete: true)
    @conference = Conference.create!(
      village: @village, name: "Test Conference",
      start_date: Date.tomorrow, end_date: Date.tomorrow + 2.days
    )
    @qualification = Qualification.create!(village: @village, name: "Foobar", description: "Can foo")

    @village_admin = User.create!(email: "admin@example.com", password: "password123", password_confirmation: "password123")
    UserRole.create!(user: @village_admin, role: Role.find_or_create_by!(name: Role::VILLAGE_ADMIN))

    @conference_lead = User.create!(email: "lead@example.com", password: "password123", password_confirmation: "password123")
    ConferenceRole.create!(user: @conference_lead, conference: @conference, role_name: ConferenceRole::CONFERENCE_LEAD)

    @volunteer = User.create!(email: "volunteer@example.com", password: "password123", password_confirmation: "password123")
    @candidate = User.create!(email: "candidate@example.com", password: "password123", password_confirmation: "password123")
  end

  def create_url
    conference_qualification_delegations_url(@conference)
  end

  test "conference lead can create a delegation" do
    sign_in @conference_lead
    assert_difference("QualificationAssignmentDelegation.count", 1) do
      post create_url, params: { user_id: @candidate.id, qualification_id: @qualification.id }
    end
    assert @candidate.can_assign_qualification?(@qualification, @conference)
  end

  test "village admin can create a delegation" do
    sign_in @village_admin
    assert_difference("QualificationAssignmentDelegation.count", 1) do
      post create_url, params: { user_id: @candidate.id, qualification_id: @qualification.id }
    end
  end

  test "a regular volunteer cannot create a delegation" do
    sign_in @volunteer
    assert_no_difference("QualificationAssignmentDelegation.count") do
      post create_url, params: { user_id: @candidate.id, qualification_id: @qualification.id }
    end
    assert_redirected_to root_path
  end

  test "a delegate cannot create further delegations" do
    QualificationAssignmentDelegation.create!(user: @volunteer, qualification: @qualification, conference: @conference)
    sign_in @volunteer
    assert_no_difference("QualificationAssignmentDelegation.count") do
      post create_url, params: { user_id: @candidate.id, qualification_id: @qualification.id }
    end
    assert_redirected_to root_path
  end

  test "conference lead can remove a delegation" do
    delegation = QualificationAssignmentDelegation.create!(user: @candidate, qualification: @qualification, conference: @conference)
    sign_in @conference_lead
    assert_difference("QualificationAssignmentDelegation.count", -1) do
      delete conference_qualification_delegation_url(@conference, delegation)
    end
  end

  test "unauthenticated requests redirect to sign-in" do
    assert_no_difference("QualificationAssignmentDelegation.count") do
      post create_url, params: { user_id: @candidate.id, qualification_id: @qualification.id }
    end
    assert_redirected_to new_user_session_path
  end
end
