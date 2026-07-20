require "test_helper"

class ApplicationHelperTest < ActionView::TestCase
  test "display_name_with_callsign appends the callsign when present" do
    user = User.new(email: "ray@example.com", handle: "Radio Ray", callsign: "W1AW")
    assert_equal "Radio Ray (W1AW)", display_name_with_callsign(user)
  end

  test "display_name_with_callsign is just the Display Name without a callsign" do
    user = User.new(email: "ray@example.com", handle: "Radio Ray")
    assert_equal "Radio Ray", display_name_with_callsign(user)
  end
end
