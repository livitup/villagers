require "test_helper"

class ProgramsControllerTest < ActionDispatch::IntegrationTest
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

    # Make user a village admin
    village_admin_role = Role.create!(name: Role::VILLAGE_ADMIN)
    UserRole.create!(user: @village_admin, role: village_admin_role)

    @program = Program.create!(
      village: @village,
      name: "Ham Test",
      description: "Amateur radio license testing"
    )
  end

  test "should get index as volunteer" do
    sign_in @volunteer
    get programs_url
    assert_response :success
  end

  test "should get index as village admin" do
    sign_in @village_admin
    get programs_url
    assert_response :success
  end

  test "should get show as volunteer" do
    sign_in @volunteer
    get program_url(@program)
    assert_response :success
  end

  test "should get show as village admin" do
    sign_in @village_admin
    get program_url(@program)
    assert_response :success
  end

  test "should not get new as volunteer" do
    sign_in @volunteer
    get new_program_url
    assert_redirected_to root_path
  end

  test "should get new as village admin" do
    sign_in @village_admin
    get new_program_url
    assert_response :success
  end

  test "should not create program as volunteer" do
    sign_in @volunteer
    assert_no_difference "Program.count" do
      post programs_url, params: {
        program: {
          name: "New Program",
          description: "New description",
          village_id: @village.id
        }
      }
    end
    assert_redirected_to root_path
  end

  test "should create program as village admin" do
    sign_in @village_admin
    assert_difference "Program.count", 1 do
      post programs_url, params: {
        program: {
          name: "New Program",
          description: "New description",
          village_id: @village.id
        }
      }
    end

    assert_redirected_to program_path(Program.last)
    assert_equal "New Program", Program.last.name
    assert_equal "New description", Program.last.description
  end

  test "should not update program as volunteer" do
    sign_in @volunteer
    patch program_url(@program), params: {
      program: {
        name: "Updated Name",
        description: "Updated description"
      }
    }
    assert_redirected_to root_path
    @program.reload
    assert_equal "Ham Test", @program.name
  end

  test "should update program as village admin" do
    sign_in @village_admin
    patch program_url(@program), params: {
      program: {
        name: "Updated Name",
        description: "Updated description"
      }
    }
    assert_redirected_to program_path(@program)
    @program.reload
    assert_equal "Updated Name", @program.name
    assert_equal "Updated description", @program.description
  end

  test "should not get edit as volunteer" do
    sign_in @volunteer
    get edit_program_url(@program)
    assert_redirected_to root_path
  end

  test "should get edit as village admin" do
    sign_in @village_admin
    get edit_program_url(@program)
    assert_response :success
  end

  test "should not destroy program as volunteer" do
    sign_in @volunteer
    assert_no_difference "Program.count" do
      delete program_url(@program)
    end
    assert_redirected_to root_path
  end

  test "should destroy program as village admin" do
    sign_in @village_admin
    assert_difference "Program.count", -1 do
      delete program_url(@program)
    end

    assert_redirected_to programs_path
  end

  test "should require name when creating program" do
    sign_in @village_admin
    assert_no_difference "Program.count" do
      post programs_url, params: {
        program: {
          description: "Description without name",
          village_id: @village.id
        }
      }
    end
    assert_response :unprocessable_entity
  end

  # Bulk capacity update tests
  test "affected_conferences returns JSON with open conferences" do
    sign_in @village_admin
    conference = Conference.create!(
      name: "Test Conference",
      village: @village,
      start_date: Date.tomorrow,
      end_date: Date.tomorrow + 2.days,
      conference_hours_start: Time.zone.parse("2000-01-01 09:00"),
      conference_hours_end: Time.zone.parse("2000-01-01 12:00")
    )
    conference_program = ConferenceProgram.create!(
      conference: conference,
      program: @program,
      day_schedules: { "0" => { "enabled" => true, "start" => "09:00", "end" => "10:00" } }
    )

    get affected_conferences_program_url(@program, new_max_volunteers: 5), as: :json

    assert_response :success
    json_response = JSON.parse(response.body)
    assert json_response["conferences"].any? { |c| c["conference_name"] == "Test Conference" }
  end

  test "affected_conferences excludes past conferences" do
    sign_in @village_admin
    past_conference = Conference.create!(
      name: "Past Conference",
      village: @village,
      start_date: Date.yesterday - 5.days,
      end_date: Date.yesterday,
      conference_hours_start: Time.zone.parse("2000-01-01 09:00"),
      conference_hours_end: Time.zone.parse("2000-01-01 12:00")
    )
    ConferenceProgram.create!(
      conference: past_conference,
      program: @program,
      day_schedules: { "0" => { "enabled" => true, "start" => "09:00", "end" => "10:00" } }
    )

    get affected_conferences_program_url(@program, new_max_volunteers: 5), as: :json

    assert_response :success
    json_response = JSON.parse(response.body)
    assert_not json_response["conferences"].any? { |c| c["conference_name"] == "Past Conference" }
  end

  test "affected_conferences requires authorization" do
    sign_in @volunteer
    get affected_conferences_program_url(@program, new_max_volunteers: 5), as: :json
    assert_redirected_to root_path
  end

  test "bulk_update_capacity enqueues jobs for selected conferences" do
    sign_in @village_admin
    conference = Conference.create!(
      name: "Test Conference",
      village: @village,
      start_date: Date.tomorrow,
      end_date: Date.tomorrow + 2.days,
      conference_hours_start: Time.zone.parse("2000-01-01 09:00"),
      conference_hours_end: Time.zone.parse("2000-01-01 12:00")
    )
    conference_program = ConferenceProgram.create!(
      conference: conference,
      program: @program,
      day_schedules: { "0" => { "enabled" => true, "start" => "09:00", "end" => "10:00" } }
    )

    assert_enqueued_with(job: UpdateTimeslotCapacityJob) do
      post bulk_update_capacity_program_url(@program),
           params: { new_max_volunteers: 5, conference_program_ids: [ conference_program.id ] },
           as: :json
    end

    assert_response :success
    json_response = JSON.parse(response.body)
    assert json_response["success"]
  end

  test "bulk_update_capacity requires authorization" do
    sign_in @volunteer
    post bulk_update_capacity_program_url(@program),
         params: { new_max_volunteers: 5, conference_program_ids: [] },
         as: :json
    assert_redirected_to root_path
  end
end
