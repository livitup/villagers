require "application_system_test_case"

class ConferenceProgramNewTest < ApplicationSystemTestCase
  setup do
    @village = Village.create!(name: "Test Village", setup_complete: true)
    @conference = Conference.create!(
      name: "Test Conference",
      village: @village,
      start_date: Date.tomorrow,
      end_date: Date.tomorrow + 2.days,
      conference_hours_start: Time.zone.parse("2000-01-01 09:00"),
      conference_hours_end: Time.zone.parse("2000-01-01 17:00")
    )
    @program = Program.create!(
      name: "Test Program",
      description: "This is the default program description that should auto-populate",
      village: @village,
      max_volunteers: 2
    )

    @village_admin = User.create!(
      email: "admin@example.com",
      password: "password123",
      password_confirmation: "password123"
    )
    village_admin_role = Role.find_or_create_by!(name: Role::VILLAGE_ADMIN)
    UserRole.create!(user: @village_admin, role: village_admin_role)
  end

  test "selecting a program auto-populates the description field" do
    sign_in @village_admin
    visit conference_new_conference_program_path(@conference)

    # Description should be empty initially
    assert_field "public_description", with: ""

    # Select the program from dropdown
    select @program.name, from: "program_select"

    # Description should now contain the program's default description
    assert_field "public_description", with: @program.description
  end

  test "description auto-populates when navigating with pre-selected program" do
    sign_in @village_admin
    visit conference_new_conference_program_path(@conference, program_id: @program.id)

    # Description should already be populated since program was pre-selected
    assert_field "public_description", with: @program.description
  end

  test "user can modify auto-populated description" do
    sign_in @village_admin
    visit conference_new_conference_program_path(@conference, program_id: @program.id)

    # Description should be pre-populated
    assert_field "public_description", with: @program.description

    # User modifies the description
    custom_description = "Custom conference-specific description"
    fill_in "public_description", with: custom_description

    # Verify the custom description is there
    assert_field "public_description", with: custom_description
  end
end
