require "test_helper"

class VillagePolicyTest < ActiveSupport::TestCase
  setup do
    @village = Village.create!(name: "Test Village", setup_complete: true)
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

    village_admin_role = Role.create!(name: Role::VILLAGE_ADMIN)
    UserRole.create!(user: @village_admin, role: village_admin_role)
  end

  test "volunteer can view village" do
    assert VillagePolicy.new(@volunteer, @village).show?
  end

  test "volunteer cannot update village" do
    assert_not VillagePolicy.new(@volunteer, @village).update?
  end

  test "village admin can update village" do
    assert VillagePolicy.new(@village_admin, @village).update?
  end
end


