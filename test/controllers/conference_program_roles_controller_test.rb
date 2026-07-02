require "test_helper"

class ConferenceProgramRolesControllerTest < ActionDispatch::IntegrationTest
  setup do
    @village = Village.create!(name: "Test Village", setup_complete: true)
    @village_admin = User.create!(email: "admin@example.com", password: "password123", password_confirmation: "password123")
    @conference_lead = User.create!(email: "lead@example.com", password: "password123", password_confirmation: "password123")
    @volunteer = User.create!(email: "volunteer@example.com", password: "password123", password_confirmation: "password123")
    @candidate = User.create!(email: "candidate@example.com", password: "password123", password_confirmation: "password123")

    UserRole.create!(user: @village_admin, role: Role.find_or_create_by!(name: Role::VILLAGE_ADMIN))

    @conference = Conference.create!(
      village: @village, name: "Test Conference",
      start_date: Date.tomorrow, end_date: Date.tomorrow + 2.days
    )
    ConferenceRole.create!(user: @conference_lead, conference: @conference, role_name: ConferenceRole::CONFERENCE_LEAD)

    @program = Program.create!(name: "Test Program", village: @village)
    @conference_program = ConferenceProgram.create!(conference: @conference, program: @program)
  end

  def assign_url
    conference_conference_program_conference_program_roles_url(@conference, @conference_program)
  end

  test "village admin can assign an activity lead" do
    sign_in @village_admin
    assert_difference("ConferenceProgramRole.count", 1) do
      post assign_url, params: { user_id: @candidate.id }
    end
    assert @candidate.activity_lead?(@conference_program)
  end

  test "conference lead can assign an activity lead" do
    sign_in @conference_lead
    assert_difference("ConferenceProgramRole.count", 1) do
      post assign_url, params: { user_id: @candidate.id }
    end
    assert @candidate.activity_lead?(@conference_program)
  end

  test "an existing activity lead can appoint a co-lead for the same activity" do
    ConferenceProgramRole.create!(user: @volunteer, conference_program: @conference_program, role_name: ConferenceProgramRole::ACTIVITY_LEAD)
    sign_in @volunteer
    assert_difference("ConferenceProgramRole.count", 1) do
      post assign_url, params: { user_id: @candidate.id }
    end
    assert @candidate.activity_lead?(@conference_program)
  end

  test "a regular volunteer cannot assign an activity lead" do
    sign_in @volunteer
    assert_no_difference("ConferenceProgramRole.count") do
      post assign_url, params: { user_id: @candidate.id }
    end
    assert_redirected_to root_path
    assert_not @candidate.activity_lead?(@conference_program)
  end

  test "an activity lead of another activity cannot assign a lead here" do
    other_program = Program.create!(name: "Other Program", village: @village)
    other_cp = ConferenceProgram.create!(conference: @conference, program: other_program)
    ConferenceProgramRole.create!(user: @volunteer, conference_program: other_cp, role_name: ConferenceProgramRole::ACTIVITY_LEAD)
    sign_in @volunteer
    assert_no_difference("ConferenceProgramRole.count") do
      post assign_url, params: { user_id: @candidate.id }
    end
    assert_redirected_to root_path
  end

  test "does not duplicate an existing activity lead" do
    ConferenceProgramRole.create!(user: @candidate, conference_program: @conference_program, role_name: ConferenceProgramRole::ACTIVITY_LEAD)
    sign_in @village_admin
    assert_no_difference("ConferenceProgramRole.count") do
      post assign_url, params: { user_id: @candidate.id }
    end
  end

  test "village admin can remove an activity lead" do
    role = ConferenceProgramRole.create!(user: @candidate, conference_program: @conference_program, role_name: ConferenceProgramRole::ACTIVITY_LEAD)
    sign_in @village_admin
    assert_difference("ConferenceProgramRole.count", -1) do
      delete conference_conference_program_conference_program_role_url(@conference, @conference_program, role)
    end
  end

  test "a regular volunteer cannot remove an activity lead" do
    role = ConferenceProgramRole.create!(user: @candidate, conference_program: @conference_program, role_name: ConferenceProgramRole::ACTIVITY_LEAD)
    sign_in @volunteer
    assert_no_difference("ConferenceProgramRole.count") do
      delete conference_conference_program_conference_program_role_url(@conference, @conference_program, role)
    end
    assert_redirected_to root_path
  end

  test "redirects to login when unauthenticated" do
    assert_no_difference("ConferenceProgramRole.count") do
      post assign_url, params: { user_id: @candidate.id }
    end
    assert_redirected_to new_user_session_path
  end
end
