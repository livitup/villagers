require "test_helper"

# The ENV-driven userinfo field mappings of the VillagerOauth strategy (#260):
# every profile field is optional and only read when its OAUTH_*_FIELD mapping
# is configured.
class VillagerOauthStrategyTest < ActiveSupport::TestCase
  def strategy_with(userinfo)
    OmniAuth::Strategies::VillagerOauth.new(nil).tap do |strategy|
      strategy.instance_variable_set(:@raw_info, userinfo)
    end
  end

  test "info maps email and name by default" do
    info = strategy_with("email" => "vol@example.com", "name" => "Vol One").info

    assert_equal "vol@example.com", info[:email]
    assert_equal "Vol One", info[:name]
  end

  test "info maps the profile fields when their ENV mappings are configured" do
    with_env(
      "OAUTH_PHONE_FIELD" => "phone_number",
      "OAUTH_SIGNAL_FIELD" => "signal_handle",
      "OAUTH_DISCORD_FIELD" => "discord_tag",
      "OAUTH_TWITTER_FIELD" => "twitter_handle",
      "OAUTH_CALLSIGN_FIELD" => "ham_callsign"
    ) do
      info = strategy_with(
        "phone_number" => "+1 555 0100",
        "signal_handle" => "@vol.01",
        "discord_tag" => "vol#1234",
        "twitter_handle" => "@vol",
        "ham_callsign" => "W1AW"
      ).info

      assert_equal "+1 555 0100", info[:phone]
      assert_equal "@vol.01", info[:signal]
      assert_equal "vol#1234", info[:discord]
      assert_equal "@vol", info[:twitter]
      assert_equal "W1AW", info[:callsign]
    end
  end

  test "unconfigured profile fields are nil even when userinfo has likely keys" do
    with_env(
      "OAUTH_PHONE_FIELD" => nil,
      "OAUTH_SIGNAL_FIELD" => nil,
      "OAUTH_DISCORD_FIELD" => nil,
      "OAUTH_TWITTER_FIELD" => nil,
      "OAUTH_CALLSIGN_FIELD" => nil
    ) do
      info = strategy_with("phone" => "+1 555 0100", "callsign" => "W1AW").info

      assert_nil info[:phone]
      assert_nil info[:signal]
      assert_nil info[:discord]
      assert_nil info[:twitter]
      assert_nil info[:callsign]
    end
  end

  test "a configured mapping whose key is absent from userinfo yields nil" do
    with_env("OAUTH_PHONE_FIELD" => "phone_number") do
      assert_nil strategy_with("email" => "vol@example.com").info[:phone]
    end
  end
end
