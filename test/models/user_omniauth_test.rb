require "test_helper"

class UserOmniauthTest < ActiveSupport::TestCase
  def auth_hash(uid: "uid-1", email: "newcomer@example.com", name: "New Comer")
    OmniAuth::AuthHash.new(
      provider: "villager_oauth",
      uid: uid,
      info: { email: email, name: name }
    )
  end

  test "from_omniauth creates a new confirmed user when none exists" do
    assert_difference "User.count", 1 do
      user = User.from_omniauth(auth_hash)
      assert user.persisted?
      assert_equal "villager_oauth", user.provider
      assert_equal "uid-1", user.uid
      assert_equal "newcomer@example.com", user.email
      assert_equal "New Comer", user.handle
      assert user.confirmed?, "OAuth users should be auto-confirmed"
    end
  end

  test "from_omniauth returns the existing user matched by provider and uid" do
    existing = User.from_omniauth(auth_hash(uid: "uid-42", email: "stable@example.com"))

    assert_no_difference "User.count" do
      again = User.from_omniauth(auth_hash(uid: "uid-42", email: "changed@example.com"))
      assert_equal existing.id, again.id
    end
  end

  test "from_omniauth links to an existing account by email" do
    password_user = create_omniauth_password_user("link.me@example.com")

    assert_no_difference "User.count" do
      linked = User.from_omniauth(auth_hash(uid: "uid-link", email: "link.me@example.com"))
      assert_equal password_user.id, linked.id
      assert_equal "villager_oauth", linked.provider
      assert_equal "uid-link", linked.uid
    end
  end

  test "from_omniauth generates a usable random password for new users" do
    user = User.from_omniauth(auth_hash(uid: "uid-pw"))
    assert user.encrypted_password.present?
  end

  test "an oauth user is valid without a password" do
    user = User.new(
      email: "nopass@example.com",
      provider: "villager_oauth",
      uid: "uid-nopass"
    )
    assert user.valid?, user.errors.full_messages.to_sentence
  end

  test "a non-oauth user still requires a password" do
    user = User.new(email: "needspass@example.com")
    assert_not user.valid?
    assert user.errors[:password].any?
  end

  private

  def create_omniauth_password_user(email)
    user = User.new(email: email, password: "password123", password_confirmation: "password123")
    user.skip_confirmation!
    user.save!
    user
  end
end
