require "application_system_test_case"

class SetupTest < ApplicationSystemTestCase
  test "visiting the setup page when not configured" do
    visit setup_url

    assert_selector "h1", text: /setup/i
    assert_field "Village name"
    assert_field "Email"
    assert_field "Password"
    assert_field "Password confirmation"
  end

  test "completing setup wizard" do
    visit setup_url

    fill_in "Village name", with: "Ham Radio Village"
    fill_in "Email", with: "admin@example.com"
    fill_in "Password", with: "password123"
    fill_in "Password confirmation", with: "password123"

    click_on "Complete Setup"

    assert_text "Setup complete"
    assert_equal "Ham Radio Village", Village.last.name
    assert Village.last.setup_complete?
    assert_equal "admin@example.com", User.last.email
  end

  test "setup page redirects when already configured" do
    Village.create!(name: "Existing Village", setup_complete: true)

    visit setup_url

    assert_current_path root_path
  end
end

