require "test_helper"

# Chrome (149+) has a DevTools race: when a node is detached from the DOM
# between Capybara finding it and operating on it (a Turbo page swap during
# an assert_text, a re-render during a visibility check, ...), chromedriver
# reports a generic UnknownError ("unhandled inspector error: ... Node with
# given id does not belong to the document") instead of a
# StaleElementReferenceError. Capybara auto-retries stale-element errors
# inside #synchronize (re-running the query and re-finding the node), but not
# UnknownError — so a routine, retryable race hard-errors the test instead.
#
# Convert it at the single choke point every WebDriver command's error is
# classified through, so the fix covers find/text/click/visible?/etc. alike.
# (Issues #234, #237 — a visible?-only version of this missed the text path.)
module RetryableStaleInspectorNode
  STALE_INSPECTOR_NODE = /Node with given id does not belong to the document/

  def error
    ex = super
    return ex unless ex.is_a?(Selenium::WebDriver::Error::UnknownError) &&
                     ex.message.match?(STALE_INSPECTOR_NODE)

    Selenium::WebDriver::Error::StaleElementReferenceError.new(ex.message).tap do |stale|
      stale.set_backtrace(ex.backtrace) if ex.backtrace
    end
  end
end
Selenium::WebDriver::Remote::Response.prepend(RetryableStaleInspectorNode)

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
