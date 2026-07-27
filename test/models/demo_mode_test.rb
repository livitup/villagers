require "test_helper"

class DemoModeTest < ActiveSupport::TestCase
  setup do
    @original_demo_mode = ENV["DEMO_MODE"]
    @original_banner_text = ENV["DEMO_BANNER_TEXT"]

    # Parallel test workers share the filesystem, so the real
    # tmp/demo_last_reset.txt would race across processes. Point DemoMode at a
    # per-process file for the duration of each test.
    @timestamp_file = Rails.root.join("tmp", "demo_last_reset_test_#{Process.pid}.txt")
    DemoMode.singleton_class.alias_method :original_timestamp_file_path, :timestamp_file_path
    file = @timestamp_file
    DemoMode.define_singleton_method(:timestamp_file_path) { file }
  end

  teardown do
    ENV["DEMO_MODE"] = @original_demo_mode
    ENV["DEMO_BANNER_TEXT"] = @original_banner_text

    DemoMode.singleton_class.alias_method :timestamp_file_path, :original_timestamp_file_path
    DemoMode.singleton_class.remove_method :original_timestamp_file_path
    File.delete(@timestamp_file) if File.exist?(@timestamp_file)
  end

  test "enabled? returns false by default" do
    ENV["DEMO_MODE"] = nil
    refute DemoMode.enabled?
  end

  test "enabled? returns true when DEMO_MODE is true" do
    ENV["DEMO_MODE"] = "true"
    assert DemoMode.enabled?
  end

  test "enabled? returns false when DEMO_MODE is false" do
    ENV["DEMO_MODE"] = "false"
    refute DemoMode.enabled?
  end

  test "disabled? is inverse of enabled?" do
    ENV["DEMO_MODE"] = "true"
    refute DemoMode.disabled?

    ENV["DEMO_MODE"] = "false"
    assert DemoMode.disabled?
  end

  test "protected_email? returns true for seed demo emails" do
    assert DemoMode.protected_email?("admin@example.com")
    assert DemoMode.protected_email?("coordinator@example.com")
    assert DemoMode.protected_email?("admin1@example.com")
    assert DemoMode.protected_email?("admin2@example.com")
    assert DemoMode.protected_email?("volunteer1@example.com")
    assert DemoMode.protected_email?("volunteer5@example.com")
  end

  test "protected_email? returns false for non-demo emails" do
    refute DemoMode.protected_email?("random@example.com")
    refute DemoMode.protected_email?("test@test.com")
  end

  test "protected_email? is case insensitive" do
    assert DemoMode.protected_email?("ADMIN@EXAMPLE.COM")
    assert DemoMode.protected_email?("Admin@Example.Com")
  end

  test "demo_credentials returns list of demo accounts" do
    credentials = DemoMode.demo_credentials

    assert credentials.is_a?(Array)
    assert credentials.any? { |c| c[:email] == "admin@example.com" }
    assert credentials.any? { |c| c[:role] == "Village Admin" }
    assert credentials.all? { |c| c[:password] == "password" }
  end

  test "banner_text returns configured text" do
    ENV["DEMO_BANNER_TEXT"] = "Custom Demo Text"
    assert_equal "Custom Demo Text", DemoMode.banner_text
  end

  test "banner_text returns default when not configured" do
    ENV["DEMO_BANNER_TEXT"] = nil
    assert_match(/Demo Mode/, DemoMode.banner_text)
    assert_match(/resets daily/i, DemoMode.banner_text)
  end

  # Timestamp file tests
  test "last_reset_time returns nil when no timestamp file exists" do
    File.delete(@timestamp_file) if File.exist?(@timestamp_file)
    assert_nil DemoMode.last_reset_time
  end

  test "last_reset_time returns time from timestamp file" do
    reset_time = Time.current.utc
    File.write(@timestamp_file, reset_time.iso8601)

    result = DemoMode.last_reset_time
    assert_in_delta reset_time.to_i, result.to_i, 1
  end

  test "record_reset! writes current time to timestamp file" do
    DemoMode.record_reset!

    assert File.exist?(@timestamp_file)
    recorded_time = Time.parse(File.read(@timestamp_file))
    assert_in_delta Time.current.to_i, recorded_time.to_i, 2
  end

  test "next_reset_time returns nil when no last reset recorded" do
    File.delete(@timestamp_file) if File.exist?(@timestamp_file)
    assert_nil DemoMode.next_reset_time
  end

  test "next_reset_time returns 24 hours after last reset" do
    reset_time = 12.hours.ago.utc
    File.write(@timestamp_file, reset_time.iso8601)

    next_reset = DemoMode.next_reset_time
    expected = reset_time + 24.hours

    assert_in_delta expected.to_i, next_reset.to_i, 1
  end

  test "time_until_reset returns nil when no last reset recorded" do
    File.delete(@timestamp_file) if File.exist?(@timestamp_file)
    assert_nil DemoMode.time_until_reset
  end

  test "time_until_reset returns positive duration when reset is in future" do
    reset_time = 1.hour.ago.utc
    File.write(@timestamp_file, reset_time.iso8601)

    time_left = DemoMode.time_until_reset
    assert time_left > 0
    assert time_left < 24.hours
  end

  test "formatted_time_until_reset returns nil when no reset scheduled" do
    File.delete(@timestamp_file) if File.exist?(@timestamp_file)
    assert_nil DemoMode.formatted_time_until_reset
  end

  test "formatted_time_until_reset returns readable string" do
    reset_time = 1.hour.ago.utc
    File.write(@timestamp_file, reset_time.iso8601)

    formatted = DemoMode.formatted_time_until_reset
    assert formatted.is_a?(String)
    assert formatted.match?(/\d+[hm]/)
  end

  test "timestamp_file_path returns path in tmp directory" do
    # setup stubs timestamp_file_path per test process; assert the real
    # implementation through the alias it preserved.
    assert_equal Rails.root.join("tmp", "demo_last_reset.txt").to_s, DemoMode.original_timestamp_file_path.to_s
  end
end
