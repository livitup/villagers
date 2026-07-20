require "test_helper"
# Not autoloaded until a Chrome driver boots, but we patch it at load time.
require "capybara/selenium/nodes/chrome_node"

# Chrome (149+) has a DevTools race: when a node is detached from the DOM
# between Capybara finding it and checking its visibility, chromedriver
# reports a generic UnknownError ("unhandled inspector error: ... Node with
# given id does not belong to the document") instead of a
# StaleElementReferenceError. Capybara auto-retries stale-element errors
# inside #synchronize (re-running the query and re-finding the node), but not
# UnknownError — so a routine, retryable race hard-errors the test instead.
# Re-raise it as the stale-element error it actually is. (Issue #234)
module RetryableStaleInspectorNode
  STALE_INSPECTOR_NODE = /Node with given id does not belong to the document/

  def visible?
    super
  rescue Selenium::WebDriver::Error::UnknownError => e
    raise unless e.message.match?(STALE_INSPECTOR_NODE)

    raise Selenium::WebDriver::Error::StaleElementReferenceError, e.message
  end
end
Capybara::Selenium::ChromeNode.prepend(RetryableStaleInspectorNode)

class ApplicationSystemTestCase < ActionDispatch::SystemTestCase
  # Use Chrome's modern headless mode. The legacy `:headless_chrome` mode
  # (--headless) has DOM/CDP inconsistencies on recent Chrome that intermittently
  # raise "Node with given id does not belong to the document" during Capybara
  # visibility checks. The extra flags stabilize Chrome in CI containers.
  driven_by :selenium, using: :chrome, screen_size: [ 1400, 1400 ] do |options|
    options.add_argument("--headless=new")
    options.add_argument("--no-sandbox")
    options.add_argument("--disable-dev-shm-usage")
    options.add_argument("--disable-gpu")
    # Escape hatch when selenium-manager picks the wrong local browser (e.g. a
    # stale "Chrome for Testing" install shadowing the real Chrome):
    #   CHROME_BINARY="/Applications/Google Chrome.app/Contents/MacOS/Google Chrome" bin/rails test:system
    options.binary = ENV["CHROME_BINARY"] if ENV["CHROME_BINARY"].present?
  end
end
