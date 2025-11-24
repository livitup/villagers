require "test_helper"

class UserPermissionsTest < ActiveSupport::TestCase
  setup do
    @village = Village.create!(name: "Test Village", setup_complete: true)
    @user = User.create!(
      email: "user@example.com",
      password: "password123",
      password_confirmation: "password123"
    )
    @conference1 = Conference.create!(
      village: @village,
      name: "Conference 1",
      start_date: Date.today,
      end_date: Date.tomorrow
    )
    @conference2 = Conference.create!(
      village: @village,
      name: "Conference 2",
      start_date: Date.today + 7,
      end_date: Date.tomorrow + 7
    )
  end

  test "global_roles returns user's role names" do
    assert_equal [], @user.global_roles

    village_admin_role = Role.create!(name: Role::VILLAGE_ADMIN)
    UserRole.create!(user: @user, role: village_admin_role)

    assert_equal [ Role::VILLAGE_ADMIN ], @user.global_roles
  end

  test "conference_lead_conferences returns conferences where user is lead" do
    assert_equal [], @user.conference_lead_conferences

    ConferenceRole.create!(
      user: @user,
      conference: @conference1,
      role_name: ConferenceRole::CONFERENCE_LEAD
    )

    assert_equal [ @conference1 ], @user.conference_lead_conferences
  end

  test "conference_admin_conferences returns conferences where user is admin" do
    assert_equal [], @user.conference_admin_conferences

    ConferenceRole.create!(
      user: @user,
      conference: @conference1,
      role_name: ConferenceRole::CONFERENCE_ADMIN
    )

    assert_equal [ @conference1 ], @user.conference_admin_conferences
  end

  test "conference_lead_conferences returns multiple conferences" do
    ConferenceRole.create!(
      user: @user,
      conference: @conference1,
      role_name: ConferenceRole::CONFERENCE_LEAD
    )
    ConferenceRole.create!(
      user: @user,
      conference: @conference2,
      role_name: ConferenceRole::CONFERENCE_LEAD
    )

    assert_equal 2, @user.conference_lead_conferences.count
    assert_includes @user.conference_lead_conferences, @conference1
    assert_includes @user.conference_lead_conferences, @conference2
  end
end
