require "test_helper"

class ConferenceTest < ActiveSupport::TestCase
  def setup
    @village = Village.create!(name: "Test Village", setup_complete: true)
  end

  test "conference has country, state, and city attributes" do
    conference = Conference.new(
      village: @village,
      name: "Test Conference",
      start_date: Date.tomorrow,
      end_date: Date.tomorrow + 3.days,
      country: "US",
      state: "NV",
      city: "Las Vegas"
    )
    assert conference.valid?
    assert_equal "US", conference.country
    assert_equal "NV", conference.state
    assert_equal "Las Vegas", conference.city
  end

  test "conference country defaults to US" do
    conference = Conference.new(
      village: @village,
      name: "Test Conference",
      start_date: Date.tomorrow,
      end_date: Date.tomorrow + 3.days
    )
    assert_equal "US", conference.country
  end

  test "conference is valid without state for non-US country" do
    conference = Conference.new(
      village: @village,
      name: "Test Conference",
      start_date: Date.tomorrow,
      end_date: Date.tomorrow + 3.days,
      country: "DE",
      city: "Berlin"
    )
    assert conference.valid?
  end

  test "display_location returns city and state for US" do
    conference = Conference.create!(
      village: @village,
      name: "Test Conference",
      start_date: Date.tomorrow,
      end_date: Date.tomorrow + 3.days,
      country: "US",
      state: "NV",
      city: "Las Vegas"
    )
    assert_equal "Las Vegas, NV", conference.display_location
  end

  test "display_location returns city and country for non-US" do
    conference = Conference.create!(
      village: @village,
      name: "Test Conference",
      start_date: Date.tomorrow,
      end_date: Date.tomorrow + 3.days,
      country: "DE",
      city: "Berlin"
    )
    assert_equal "Berlin, Germany", conference.display_location
  end

  test "display_location returns Not specified when no location" do
    conference = Conference.create!(
      village: @village,
      name: "Test Conference",
      start_date: Date.tomorrow,
      end_date: Date.tomorrow + 3.days
    )
    assert_equal "Not specified", conference.display_location
  end
end
