require "test_helper"

class ConferencePolicyTest < ActiveSupport::TestCase
  setup do
    @village = Village.create!(name: "Test Village", setup_complete: true)
    @conference = Conference.create!(
      village: @village,
      name: "Test Conference",
      start_date: Date.today,
      end_date: Date.tomorrow
    )
    @volunteer = User.create!(
      email: "volunteer@example.com",
      password: "password123",
      password_confirmation: "password123"
    )
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
      email: "conf_admin@example.com",
      password: "password123",
      password_confirmation: "password123"
    )

    # Assign roles
    village_admin_role = Role.create!(name: Role::VILLAGE_ADMIN)
    UserRole.create!(user: @village_admin, role: village_admin_role)

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
  end

  test "volunteer can view conferences" do
    assert ConferencePolicy.new(@volunteer, @conference).show?
    assert ConferencePolicy.new(@volunteer, Conference).index?
  end

  test "volunteer cannot create conferences" do
    assert_not ConferencePolicy.new(@volunteer, @conference).create?
  end

  test "village admin can create conferences" do
    assert ConferencePolicy.new(@village_admin, @conference).create?
  end

  test "village admin can update any conference" do
    assert ConferencePolicy.new(@village_admin, @conference).update?
  end

  test "conference lead can update their conference" do
    assert ConferencePolicy.new(@conference_lead, @conference).update?
  end

  test "conference admin can update their conference" do
    assert ConferencePolicy.new(@conference_admin, @conference).update?
  end

  test "volunteer cannot update conference" do
    assert_not ConferencePolicy.new(@volunteer, @conference).update?
  end

  test "village admin can destroy conferences" do
    assert ConferencePolicy.new(@village_admin, @conference).destroy?
  end

  test "conference lead cannot destroy conferences" do
    assert_not ConferencePolicy.new(@conference_lead, @conference).destroy?
  end
end
