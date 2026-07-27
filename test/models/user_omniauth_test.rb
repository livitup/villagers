require "test_helper"

class UserOmniauthTest < ActiveSupport::TestCase
  def auth_hash(uid: "uid-1", email: "newcomer@example.com", name: "New Comer", **profile)
    OmniAuth::AuthHash.new(
      provider: "villager_oauth",
      uid: uid,
      info: { email: email, name: name, **profile }
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

  test "from_omniauth prefills the Display Name from the provider name" do
    user = User.from_omniauth(auth_hash(uid: "uid-name", name: "Radio Ray"))
    assert_equal "Radio Ray", user.handle
  end

  # --- profile sync (#260): the provider is the source of truth ---

  test "from_omniauth refreshes the handle from the provider on every login" do
    chosen = User.new(email: "chosen@example.com", password: "password123", password_confirmation: "password123", handle: "MyChosenName")
    chosen.skip_confirmation!
    chosen.save!

    # Same person signs in via OAuth (linked by email); the IdP is
    # authoritative (#260 product decision), so its name replaces the
    # locally-chosen Display Name.
    linked = User.from_omniauth(auth_hash(uid: "uid-chosen", email: "chosen@example.com", name: "Provider Name"))

    assert_equal chosen.id, linked.id
    assert_equal "Provider Name", linked.reload.handle
  end

  test "from_omniauth populates all mapped profile fields for a new user" do
    user = User.from_omniauth(auth_hash(
      uid: "uid-full",
      phone: "+1 555 0100",
      signal: "@newcomer.01",
      discord: "newcomer#1234",
      twitter: "@newcomer",
      callsign: "W1AW"
    ))

    assert_equal "+1 555 0100",  user.phone
    assert_equal "@newcomer.01", user.signal
    assert_equal "newcomer#1234", user.discord
    assert_equal "@newcomer",    user.twitter
    assert_equal "W1AW",         user.callsign
  end

  test "from_omniauth refreshes profile fields for a returning identity" do
    User.from_omniauth(auth_hash(uid: "uid-refresh", email: "refresh@example.com", phone: "+1 555 0100", callsign: "W1AW"))

    returning = User.from_omniauth(auth_hash(
      uid: "uid-refresh",
      email: "refresh@example.com",
      name: "Updated Name",
      phone: "+1 555 0199",
      callsign: "KD9XYZ"
    ))

    returning.reload
    assert_equal "Updated Name", returning.handle
    assert_equal "+1 555 0199",  returning.phone
    assert_equal "KD9XYZ",       returning.callsign
  end

  test "from_omniauth leaves fields untouched when the provider omits them" do
    user = User.from_omniauth(auth_hash(uid: "uid-keep", email: "keep@example.com", phone: "+1 555 0100"))
    user.update!(discord: "locally-set#1")

    again = User.from_omniauth(auth_hash(uid: "uid-keep", email: "keep@example.com", phone: nil, discord: nil))

    again.reload
    assert_equal "+1 555 0100",   again.phone,   "an absent value must not blank an existing field"
    assert_equal "locally-set#1", again.discord
  end

  test "from_omniauth falls back to the email when the provider sends no name" do
    user = User.from_omniauth(auth_hash(uid: "uid-noname", email: "noname@example.com", name: nil))
    assert_equal "noname@example.com", user.handle
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
