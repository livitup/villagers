require "application_system_test_case"

class ProfileQualificationsTest < ApplicationSystemTestCase
  setup do
    @village = Village.create!(name: "Test Village", setup_complete: true)
    @user = User.create!(
      email: "user@example.com",
      password: "password123",
      password_confirmation: "password123"
    )
    @qualification = Qualification.create!(
      name: "Licensed Amateur Radio Operator",
      description: "FCC license required",
      village: @village
    )
  end

  def login_as(user)
    visit new_user_session_path
    fill_in "Email", with: user.email
    fill_in "Password", with: "password123"
    find('input[type="submit"][value="Log in"]').click
    assert_text "Logout" # Wait for successful login
  end

  test "user sees their qualifications on profile page" do
    # Grant qualification to user
    UserQualification.create!(user: @user, qualification: @qualification)

    # Sign in and visit profile
    login_as @user
    visit edit_user_registration_path

    # Should see qualifications section
    assert_text "My Qualifications"
    assert_text "Licensed Amateur Radio Operator"
  end

  test "user sees message when they have no qualifications" do
    login_as @user
    visit edit_user_registration_path

    assert_text "My Qualifications"
    assert_text "You don't have any qualifications yet"
  end

  test "user with multiple qualifications sees all of them" do
    qual2 = Qualification.create!(
      name: "Volunteer Examiner",
      description: "VE certification",
      village: @village
    )
    UserQualification.create!(user: @user, qualification: @qualification)
    UserQualification.create!(user: @user, qualification: qual2)

    login_as @user
    visit edit_user_registration_path

    assert_text "Licensed Amateur Radio Operator"
    assert_text "Volunteer Examiner"
  end
end
