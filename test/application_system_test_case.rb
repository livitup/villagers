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
  # Chrome 150's other click hazard (sibling of the stale-inspector race
  # above, see #241): after the first Turbo Drive body swap of a session,
  # chromedriver's native click dispatch goes dead — every further click is
  # silently dropped (no error, no event) even though the element is visible
  # and correctly positioned. JS-dispatched clicks are unaffected. So: click
  # natively once, and if the expected effect doesn't appear, re-dispatch the
  # click through JS and wait again. Keep `wait` generous for clicks that
  # submit forms, so a slow in-flight POST isn't double-submitted.
  def click_expecting(element, effect_selector = nil, text: nil, count: nil, gone: nil, wait: 3)
    element.click
    return if click_effect?(effect_selector, text: text, count: count, gone: gone, wait: wait)

    page.execute_script("arguments[0].click()", element)
    return if click_effect?(effect_selector, text: text, count: count, gone: gone, wait: wait)

    flunk "expected #{(effect_selector || text || "#{gone} to disappear").inspect} after clicking #{element.inspect}"
  end

  private

  # Effect forms: a selector (optionally narrowed by text:/count:), bare
  # text: (page-wide), or gone: (selector must disappear).
  def click_effect?(effect_selector, text:, count:, gone:, wait:)
    if effect_selector
      options = { wait: wait }
      options[:count] = count if count
      options[:text] = text if text
      page.has_selector?(effect_selector, **options)
    elsif gone
      page.has_no_selector?(gone, wait: wait)
    else
      page.has_text?(text, wait: wait)
    end
  end

  # Use Chrome's modern headless mode. The legacy `:headless_chrome` mode
  # (--headless) has DOM/CDP inconsistencies on recent Chrome that intermittently
  # raise "Node with given id does not belong to the document" during Capybara
  # visibility checks. The extra flags stabilize Chrome in CI containers.
  driven_by :selenium, using: :chrome, screen_size: [ 1400, 1400 ] do |options|
    options.add_argument("--headless=new")
    options.add_argument("--no-sandbox")
    options.add_argument("--disable-dev-shm-usage")
    options.add_argument("--disable-gpu")
    options.add_argument("--force-device-scale-factor=1")
    # Escape hatch when selenium-manager picks the wrong local browser (e.g. a
    # stale "Chrome for Testing" install shadowing the real Chrome):
    #   CHROME_BINARY="/Applications/Google Chrome.app/Contents/MacOS/Google Chrome" bin/rails test:system
    options.binary = ENV["CHROME_BINARY"] if ENV["CHROME_BINARY"].present?
  end
end
