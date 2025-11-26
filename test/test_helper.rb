ENV["RAILS_ENV"] ||= "test"
require_relative "../config/environment"
require "rails/test_help"

module ActiveSupport
  class TestCase
    # Run tests in parallel with specified workers
    # Disabled (threshold: 500) due to Devise mapping race conditions with parallel processes
    # TODO: Re-enable when Devise fixes parallel test support or we have 500+ tests
    parallelize(workers: :number_of_processors, threshold: 500)

    # Setup all fixtures in test/fixtures/*.yml for all tests in alphabetical order.
    fixtures :all

    # Add more helper methods to be used by all tests here...
  end
end

# Include Devise test helpers
class ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers
end

class ActionDispatch::SystemTestCase
  include Devise::Test::IntegrationHelpers
end
