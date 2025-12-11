require "test_helper"

class ConferenceProgramsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @village = Village.create!(name: "Test Village", setup_complete: true)
    @village_admin = User.create!(
      email: "admin@example.com",
      password: "password123",
      password_confirmation: "password123"
    )
    @conference_lead = User.create!(
      email: "lead@example.com",
      password: "password123",
      password_confirmation: "password123"
    )
    @conference_admin = User.create!(
      email: "admin2@example.com",
      password: "password123",
      password_confirmation: "password123"
    )
    @volunteer = User.create!(
      email: "volunteer@example.com",
      password: "password123",
      password_confirmation: "password123"
    )

    village_admin_role = Role.find_or_create_by!(name: Role::VILLAGE_ADMIN)
    UserRole.create!(user: @village_admin, role: village_admin_role)

    @conference = Conference.create!(
      village: @village,
      name: "Test Conference",
      city: "Test City", state: "NV", country: "US",
      start_date: Date.today + 1.day,
      end_date: Date.today + 3.days,
      conference_hours_start: Time.parse("09:00"),
      conference_hours_end: Time.parse("17:00")
    )

    ConferenceRole.create!(
      user: @conference_lead,
      conference: @conference,
      role_name: ConferenceRole::CONFERENCE_LEAD
    )

    ConferenceRole.create!(
      user: @conference_admin,
      conference: @conference,
      role_name: ConferenceRole::CONFERENCE_ADMIN
    )

    @program = Program.create!(
      name: "Test Program",
      description: "A test program",
      village: @village
    )

    @conference_program = ConferenceProgram.create!(
      conference: @conference,
      program: @program,
      public_description: "Conference-specific description"
    )
  end

  test "should get index as village admin" do
    sign_in @village_admin
    get conference_conference_programs_path(@conference)
    assert_response :success
  end

  test "should get index as conference lead" do
    sign_in @conference_lead
    get conference_conference_programs_path(@conference)
    assert_response :success
  end

  test "should get index as conference admin" do
    sign_in @conference_admin
    get conference_conference_programs_path(@conference)
    assert_response :success
  end

  test "should not get index as volunteer" do
    sign_in @volunteer
    get conference_conference_programs_path(@conference)
    assert_redirected_to root_path
  end

  test "should get new as village admin" do
    sign_in @village_admin
    get conference_new_conference_program_path(@conference)
    assert_response :success
  end

  test "should get new as conference lead" do
    sign_in @conference_lead
    get conference_new_conference_program_path(@conference)
    assert_response :success
  end

  test "should not get new as volunteer" do
    sign_in @volunteer
    get conference_new_conference_program_path(@conference)
    assert_redirected_to root_path
  end

  test "should create conference program as village admin" do
    new_program = Program.create!(
      name: "New Program",
      description: "Another program",
      village: @village
    )
    sign_in @village_admin
    assert_difference("ConferenceProgram.count") do
      post conference_conference_programs_path(@conference), params: {
        conference_program: {
          program_id: new_program.id,
          public_description: "New description"
        }
      }
    end
    assert_redirected_to conference_conference_programs_path(@conference)
  end

  test "should create conference program as conference lead" do
    new_program = Program.create!(
      name: "New Program 2",
      description: "Another program",
      village: @village
    )
    sign_in @conference_lead
    assert_difference("ConferenceProgram.count") do
      post conference_conference_programs_path(@conference), params: {
        conference_program: {
          program_id: new_program.id,
          public_description: "New description"
        }
      }
    end
    assert_redirected_to conference_conference_programs_path(@conference)
  end

  test "should not create conference program as volunteer" do
    new_program = Program.create!(
      name: "New Program 3",
      description: "Another program",
      village: @village
    )
    sign_in @volunteer
    assert_no_difference("ConferenceProgram.count") do
      post conference_conference_programs_path(@conference), params: {
        conference_program: {
          program_id: new_program.id,
          public_description: "New description"
        }
      }
    end
    assert_redirected_to root_path
  end

  test "should get edit as village admin" do
    sign_in @village_admin
    get edit_conference_conference_program_path(@conference, @conference_program)
    assert_response :success
  end

  test "should get edit as conference lead" do
    sign_in @conference_lead
    get edit_conference_conference_program_path(@conference, @conference_program)
    assert_response :success
  end

  test "should not get edit as volunteer" do
    sign_in @volunteer
    get edit_conference_conference_program_path(@conference, @conference_program)
    assert_redirected_to root_path
  end

  test "should update conference program as village admin" do
    sign_in @village_admin
    patch conference_conference_program_path(@conference, @conference_program), params: {
      conference_program: {
        public_description: "Updated description"
      }
    }
    assert_redirected_to conference_conference_programs_path(@conference)
    @conference_program.reload
    assert_equal "Updated description", @conference_program.public_description
  end

  test "should update conference program as conference lead" do
    sign_in @conference_lead
    patch conference_conference_program_path(@conference, @conference_program), params: {
      conference_program: {
        public_description: "Updated by lead"
      }
    }
    assert_redirected_to conference_conference_programs_path(@conference)
    @conference_program.reload
    assert_equal "Updated by lead", @conference_program.public_description
  end

  test "should not update conference program as volunteer" do
    sign_in @volunteer
    original_description = @conference_program.public_description
    patch conference_conference_program_path(@conference, @conference_program), params: {
      conference_program: {
        public_description: "Hacked description"
      }
    }
    assert_redirected_to root_path
    @conference_program.reload
    assert_equal original_description, @conference_program.public_description
  end

  test "should destroy conference program as village admin" do
    sign_in @village_admin
    assert_difference("ConferenceProgram.count", -1) do
      delete conference_conference_program_path(@conference, @conference_program)
    end
    assert_redirected_to conference_conference_programs_path(@conference)
  end

  test "should destroy conference program as conference lead" do
    sign_in @conference_lead
    assert_difference("ConferenceProgram.count", -1) do
      delete conference_conference_program_path(@conference, @conference_program)
    end
    assert_redirected_to conference_conference_programs_path(@conference)
  end

  test "should not destroy conference program as volunteer" do
    sign_in @volunteer
    assert_no_difference("ConferenceProgram.count") do
      delete conference_conference_program_path(@conference, @conference_program)
    end
    assert_redirected_to root_path
  end
end
