require "test_helper"

# Profile-completion signal (#218). A profile is "complete" when the volunteer
# has set a real Display Name (a handle that isn't just their email fallback)
# AND at least one contact method. Callsign is collected but NOT required.
class UserProfileCompletionTest < ActiveSupport::TestCase
  def build_user(**attrs)
    User.create!({ email: "vol@example.com", password: "password123", password_confirmation: "password123" }.merge(attrs))
  end

  test "a fresh account (handle backfilled to email, no contact) is incomplete" do
    user = build_user
    assert_equal user.email, user.handle
    assert_not user.profile_complete?
    assert user.needs_profile_completion?
  end

  test "a personalized Display Name plus a contact method is complete" do
    user = build_user(handle: "Radio Ray", discord: "ray#1234")
    assert user.profile_complete?
    assert_not user.needs_profile_completion?
  end

  test "a personalized Display Name with no contact method is incomplete" do
    user = build_user(handle: "Radio Ray")
    assert_not user.profile_complete?
  end

  test "a contact method but no personalized Display Name (handle == email) is incomplete" do
    user = build_user(phone: "555-1234")
    assert_not user.profile_complete?
  end

  test "any single contact method satisfies the contact requirement" do
    %i[phone signal discord twitter].each do |field|
      user = build_user(email: "#{field}@example.com", handle: "Name #{field}", field => "value")
      assert user.profile_complete?, "#{field} should count as a contact method"
    end
  end

  test "callsign is not required for completion" do
    user = build_user(handle: "Radio Ray", callsign: "W1AW")
    assert_not user.profile_complete?, "callsign alone is not a contact method"

    user.update!(discord: "ray#1234")
    assert user.profile_complete?
  end

  test "handle matching the email case-insensitively still counts as unset" do
    user = build_user(email: "Vol@Example.com", handle: "vol@example.com", discord: "x#1")
    assert_not user.profile_complete?
  end
end
