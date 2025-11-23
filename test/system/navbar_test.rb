require "application_system_test_case"

class NavbarTest < ApplicationSystemTestCase
  test "navbar shows village name when setup is complete" do
    Village.create!(name: "Ham Radio Village", setup_complete: true)

    visit root_path

    assert_text "Ham Radio Village"
  end

  test "navbar shows default name when setup is not complete" do
    visit root_path

    assert_text "Villagers"
  end

  test "navbar shows login and sign up when not signed in" do
    visit root_path

    assert_link "Login"
    assert_link "Sign Up"
    assert_no_link "Logout"
    assert_no_link "Profile"
  end

  test "navbar shows profile and logout when signed in" do
    user = User.create!(
      email: "user@example.com",
      password: "password123",
      password_confirmation: "password123"
    )

    sign_in user
    visit root_path

    assert_link "Profile"
    assert_link "Logout"
    assert_no_link "Login"
    assert_no_link "Sign Up"
  end

  test "navbar is responsive on mobile" do
    visit root_path

    # Check that navbar toggler exists (may not be visible on desktop)
    assert_selector ".navbar-toggler", visible: :all
    assert_selector "#navbarNav.collapse"
  end
end

