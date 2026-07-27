require "test_helper"

class HealthControllerTest < ActionDispatch::IntegrationTest
  setup do
    @original_demo_mode = ENV["DEMO_MODE"]

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

    DemoMode.singleton_class.alias_method :timestamp_file_path, :original_timestamp_file_path
    DemoMode.singleton_class.remove_method :original_timestamp_file_path
    File.delete(@timestamp_file) if File.exist?(@timestamp_file)
  end

  test "health check returns 200" do
    get health_path

    assert_response :success
  end

  test "health check returns JSON" do
    get health_path, as: :json

    assert_response :success
    json = JSON.parse(response.body)
    assert json.key?("status")
    assert_equal "ok", json["status"]
  end

  test "health check includes demo mode status when enabled with reset recorded" do
    ENV["DEMO_MODE"] = "true"
    File.write(@timestamp_file, 1.hour.ago.utc.iso8601)

    get health_path, as: :json

    json = JSON.parse(response.body)
    assert json["demo_mode"]
    assert json.key?("next_reset")
    assert json.key?("time_until_reset")
  end

  test "health check shows demo mode without reset info when no reset recorded" do
    ENV["DEMO_MODE"] = "true"
    File.delete(@timestamp_file) if File.exist?(@timestamp_file)

    get health_path, as: :json

    json = JSON.parse(response.body)
    assert json["demo_mode"]
    assert_not json.key?("next_reset")
  end

  test "health check shows demo mode false when disabled" do
    ENV["DEMO_MODE"] = "false"

    get health_path, as: :json

    json = JSON.parse(response.body)
    assert_not json["demo_mode"]
    assert_nil json["next_reset"]
  end

  test "health check includes database connectivity" do
    get health_path, as: :json

    json = JSON.parse(response.body)
    assert json.key?("database")
  end
end
