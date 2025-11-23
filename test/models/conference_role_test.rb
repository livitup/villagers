require "test_helper"

class ConferenceRoleTest < ActiveSupport::TestCase
  setup do
    @village = Village.create!(name: "Test Village", setup_complete: true)
    @user = User.create!(
      email: "user@example.com",
      password: "password123",
      password_confirmation: "password123"
    )
    @conference = Conference.create!(
      village: @village,
      name: "Test Conference",
      start_date: Date.today,
      end_date: Date.tomorrow
    )
  end

  test "should create conference role" do
    conference_role = ConferenceRole.new(
      user: @user,
      conference: @conference,
      role_name: ConferenceRole::CONFERENCE_LEAD
    )
    assert conference_role.save
  end

  test "should not allow invalid role name" do
    conference_role = ConferenceRole.new(
      user: @user,
      conference: @conference,
      role_name: "invalid_role"
    )
    assert_not conference_role.valid?
    assert_includes conference_role.errors[:role_name], "is not included in the list"
  end

  test "should not allow duplicate conference role" do
    ConferenceRole.create!(
      user: @user,
      conference: @conference,
      role_name: ConferenceRole::CONFERENCE_LEAD
    )
    duplicate = ConferenceRole.new(
      user: @user,
      conference: @conference,
      role_name: ConferenceRole::CONFERENCE_LEAD
    )
    assert_not duplicate.valid?
  end
end
