require "test_helper"

class UserRoleTest < ActiveSupport::TestCase
  setup do
    @user = User.create!(
      email: "user@example.com",
      password: "password123",
      password_confirmation: "password123"
    )
    @role = Role.create!(name: Role::VILLAGE_ADMIN)
  end

  test "should create user role" do
    user_role = UserRole.new(user: @user, role: @role)
    assert user_role.save
  end

  test "should not allow duplicate user role" do
    UserRole.create!(user: @user, role: @role)
    duplicate = UserRole.new(user: @user, role: @role)
    assert_not duplicate.valid?
    assert_includes duplicate.errors[:user_id], "has already been taken"
  end
end
