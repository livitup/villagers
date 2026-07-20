require "application_system_test_case"

# Regression coverage for the stale-inspector-node conversion (#234, #237).
# Chrome reports a detached-node race as a generic UnknownError ("unhandled
# inspector error: ... Node with given id does not belong to the document").
# The patch in application_system_test_case.rb must convert it — at the
# Selenium Response level, so EVERY command path (find, text, click,
# visible?, ...) surfaces it as the retryable StaleElementReferenceError
# that Capybara auto-retries inside #synchronize.
class SeleniumStaleNodePatchTest < ActiveSupport::TestCase
  STALE_MESSAGE = 'unhandled inspector error: {"code":-32000,' \
                  '"message":"Node with given id does not belong to the document"}'

  def response_error(message)
    # Bypass initialize (which raises via assert_ok) to unit-test #error.
    response = Selenium::WebDriver::Remote::Response.allocate
    response.instance_variable_set(:@code, 400)
    response.instance_variable_set(:@payload, { "value" => { "error" => "unknown error", "message" => message } })
    response.error
  end

  test "the stale-inspector-node message becomes a retryable StaleElementReferenceError" do
    error = response_error(STALE_MESSAGE)

    assert_instance_of Selenium::WebDriver::Error::StaleElementReferenceError, error
    assert_match(/Node with given id does not belong to the document/, error.message)
  end

  test "unrelated UnknownErrors are left untouched" do
    error = response_error("session deleted because of page crash")

    assert_instance_of Selenium::WebDriver::Error::UnknownError, error
  end

  test "Capybara auto-retries StaleElementReferenceError" do
    assert_includes Capybara::Selenium::Driver.new(nil).invalid_element_errors,
                    Selenium::WebDriver::Error::StaleElementReferenceError
  end
end
