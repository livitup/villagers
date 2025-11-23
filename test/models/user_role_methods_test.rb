require "test_helper"

class UserRoleMethodsTest < ActiveSupport::TestCase
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

  test "user should be volunteer if persisted" do
    assert @user.volunteer?
  end

  test "user should not be village admin by default" do
    assert_not @user.village_admin?
  end

  test "user should be village admin when role assigned" do
    role = Role.create!(name: Role::VILLAGE_ADMIN)
    UserRole.create!(user: @user, role: role)
    assert @user.village_admin?
  end

  test "user should not be conference lead by default" do
    assert_not @user.conference_lead?(@conference)
  end

  test "user should be conference lead when role assigned" do
    ConferenceRole.create!(
      user: @user,
      conference: @conference,
      role_name: ConferenceRole::CONFERENCE_LEAD
    )
    assert @user.conference_lead?(@conference)
  end

  test "user should be conference admin when role assigned" do
    ConferenceRole.create!(
      user: @user,
      conference: @conference,
      role_name: ConferenceRole::CONFERENCE_ADMIN
    )
    assert @user.conference_admin?(@conference)
  end

  test "user should be conference lead or admin" do
    ConferenceRole.create!(
      user: @user,
      conference: @conference,
      role_name: ConferenceRole::CONFERENCE_LEAD
    )
    assert @user.conference_lead_or_admin?(@conference)
  end

  test "village admin can manage any conference" do
    role = Role.create!(name: Role::VILLAGE_ADMIN)
    UserRole.create!(user: @user, role: role)
    assert @user.can_manage_conference?(@conference)
  end

  test "conference lead can manage their conference" do
    ConferenceRole.create!(
      user: @user,
      conference: @conference,
      role_name: ConferenceRole::CONFERENCE_LEAD
    )
    assert @user.can_manage_conference?(@conference)
  end

  test "conference admin can manage their conference" do
    ConferenceRole.create!(
      user: @user,
      conference: @conference,
      role_name: ConferenceRole::CONFERENCE_ADMIN
    )
    assert @user.can_manage_conference?(@conference)
  end

  test "regular user cannot manage conference" do
    assert_not @user.can_manage_conference?(@conference)
  end
end

