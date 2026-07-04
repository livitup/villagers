require "test_helper"

# Covers the "one Display Name" refactor (#215): `handle` is the single Display
# Name, it's required but blank-safe (backfills from email), `display_name`
# is the accessor every view uses, and `callsign` exists as an optional field.
class UserDisplayNameTest < ActiveSupport::TestCase
  test "a blank handle backfills from the email so Display Name is never empty" do
    user = User.create!(email: "nohandle@example.com", password: "password123", password_confirmation: "password123")

    assert_equal "nohandle@example.com", user.handle
    assert_equal "nohandle@example.com", user.display_name
  end

  test "a chosen handle is kept as the Display Name" do
    user = User.create!(email: "chosen@example.com", password: "password123", password_confirmation: "password123", handle: "N0CALL")

    assert_equal "N0CALL", user.handle
    assert_equal "N0CALL", user.display_name
  end

  test "clearing the handle re-backfills from email instead of failing validation" do
    user = User.create!(email: "reclear@example.com", password: "password123", password_confirmation: "password123", handle: "Something")

    assert user.update(handle: "")
    assert_equal "reclear@example.com", user.reload.handle
  end

  test "handle is required (presence backstop)" do
    user = User.new(email: "x@example.com", password: "password123", password_confirmation: "password123")
    # ensure_display_name fills it, so a normally-built user is valid...
    assert user.valid?
    # ...but the presence validation still guards against a truly blank handle.
    user.handle = ""
    user.define_singleton_method(:ensure_display_name) { nil } # bypass the backfill
    assert_not user.valid?
    assert user.errors[:handle].any?
  end

  test "callsign is an optional attribute" do
    user = User.create!(email: "ham@example.com", password: "password123", password_confirmation: "password123", callsign: "W1AW")

    assert_equal "W1AW", user.callsign
    assert User.create!(email: "noham@example.com", password: "password123", password_confirmation: "password123").valid?
  end
end
