require "test_helper"

class CustomProgramsControllerTest < ActionDispatch::IntegrationTest
  def setup
    @village = Village.create!(name: "Test Village", setup_complete: true)
    @conference = Conference.create!(
      name: "Test Conference",
      village: @village,
      start_date: Date.tomorrow,
      end_date: Date.tomorrow + 3.days
    )

    @village_admin = User.create!(
      email: "admin@example.com",
      password: "password123",
      password_confirmation: "password123"
    )
    village_admin_role = Role.find_or_create_by!(name: Role::VILLAGE_ADMIN)
    UserRole.create!(user: @village_admin, role: village_admin_role)

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

    @conference_program = Program.create!(
      name: "Conference Only Program",
      village: @village,
      conference: @conference
    )
  end

  test "requires authentication for new" do
    get new_conference_custom_program_path(@conference)
    # Pundit redirects to root_path when unauthorized
    assert_redirected_to root_path
  end

  test "conference lead can access new custom program form" do
    sign_in @conference_lead
    get new_conference_custom_program_path(@conference)
    assert_response :success
  end

  test "conference lead can create custom program" do
    sign_in @conference_lead
    assert_difference("Program.count") do
      post conference_custom_programs_path(@conference), params: {
        program: {
          name: "New Custom Program",
          description: "A program just for this conference",
          max_volunteers: 2
        }
      }
    end

    program = Program.last
    assert_equal @conference, program.conference
    assert program.conference_specific?
    assert_redirected_to conference_conference_programs_path(@conference)
  end

  test "volunteer cannot access new custom program form" do
    sign_in @volunteer
    get new_conference_custom_program_path(@conference)
    assert_redirected_to root_path
  end

  test "volunteer cannot create custom program" do
    sign_in @volunteer
    assert_no_difference("Program.count") do
      post conference_custom_programs_path(@conference), params: {
        program: {
          name: "Sneaky Program",
          max_volunteers: 1
        }
      }
    end
    assert_redirected_to root_path
  end

  test "conference lead can edit their conference-specific program" do
    sign_in @conference_lead
    get edit_conference_custom_program_path(@conference, @conference_program)
    assert_response :success
  end

  test "conference lead can update their conference-specific program" do
    sign_in @conference_lead
    patch conference_custom_program_path(@conference, @conference_program), params: {
      program: {
        name: "Updated Program Name"
      }
    }

    assert_redirected_to conference_conference_programs_path(@conference)
    @conference_program.reload
    assert_equal "Updated Program Name", @conference_program.name
  end

  test "conference lead can destroy their conference-specific program" do
    sign_in @conference_lead
    assert_difference("Program.count", -1) do
      delete conference_custom_program_path(@conference, @conference_program)
    end

    assert_redirected_to conference_conference_programs_path(@conference)
  end

  test "conference lead cannot access programs from other conferences" do
    other_conference = Conference.create!(
      name: "Other Conference",
      village: @village,
      start_date: Date.tomorrow + 10.days,
      end_date: Date.tomorrow + 13.days
    )
    other_program = Program.create!(
      name: "Other Program",
      village: @village,
      conference: other_conference
    )

    sign_in @conference_lead
    get edit_conference_custom_program_path(@conference, other_program)
    assert_redirected_to conference_conference_programs_path(@conference)
  end

  test "village admin can create custom program" do
    sign_in @village_admin
    assert_difference("Program.count") do
      post conference_custom_programs_path(@conference), params: {
        program: {
          name: "Admin Created Program",
          max_volunteers: 3
        }
      }
    end

    program = Program.last
    assert_equal @conference, program.conference
    assert_redirected_to conference_conference_programs_path(@conference)
  end
end
