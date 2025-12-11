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

  # Archiving tests
  test "conference is not archived by default" do
    conference = Conference.create!(
      village: @village,
      name: "Test Conference",
      start_date: Date.tomorrow,
      end_date: Date.tomorrow + 3.days
    )
    assert_not conference.archived?
  end

  test "archived? returns true when archived_at is set" do
    conference = Conference.create!(
      village: @village,
      name: "Test Conference",
      start_date: Date.yesterday - 5.days,
      end_date: Date.yesterday,
      archived_at: Time.current
    )
    assert conference.archived?
  end

  test "active scope returns only non-archived conferences" do
    active_conference = Conference.create!(
      village: @village,
      name: "Active Conference",
      start_date: Date.tomorrow,
      end_date: Date.tomorrow + 3.days
    )
    archived_conference = Conference.create!(
      village: @village,
      name: "Archived Conference",
      start_date: Date.yesterday - 5.days,
      end_date: Date.yesterday,
      archived_at: Time.current
    )

    active_conferences = Conference.active
    assert_includes active_conferences, active_conference
    assert_not_includes active_conferences, archived_conference
  end

  test "archived scope returns only archived conferences" do
    active_conference = Conference.create!(
      village: @village,
      name: "Active Conference",
      start_date: Date.tomorrow,
      end_date: Date.tomorrow + 3.days
    )
    archived_conference = Conference.create!(
      village: @village,
      name: "Archived Conference",
      start_date: Date.yesterday - 5.days,
      end_date: Date.yesterday,
      archived_at: Time.current
    )

    archived_conferences = Conference.archived
    assert_not_includes archived_conferences, active_conference
    assert_includes archived_conferences, archived_conference
  end

  test "past_unarchived scope returns ended conferences that are not archived" do
    future_conference = Conference.create!(
      village: @village,
      name: "Future Conference",
      start_date: Date.tomorrow,
      end_date: Date.tomorrow + 3.days
    )
    past_unarchived = Conference.create!(
      village: @village,
      name: "Past Unarchived",
      start_date: Date.yesterday - 10.days,
      end_date: Date.yesterday - 5.days
    )
    past_archived = Conference.create!(
      village: @village,
      name: "Past Archived",
      start_date: Date.yesterday - 10.days,
      end_date: Date.yesterday - 5.days,
      archived_at: Time.current
    )

    past_unarchived_conferences = Conference.past_unarchived
    assert_not_includes past_unarchived_conferences, future_conference
    assert_includes past_unarchived_conferences, past_unarchived
    assert_not_includes past_unarchived_conferences, past_archived
  end

  test "archive! sets archived_at timestamp" do
    conference = Conference.create!(
      village: @village,
      name: "Test Conference",
      start_date: Date.yesterday - 5.days,
      end_date: Date.yesterday
    )

    assert_nil conference.archived_at
    conference.archive!
    assert_not_nil conference.archived_at
    assert conference.archived?
  end

  test "unarchive! clears archived_at timestamp" do
    conference = Conference.create!(
      village: @village,
      name: "Test Conference",
      start_date: Date.yesterday - 5.days,
      end_date: Date.yesterday,
      archived_at: Time.current
    )

    assert conference.archived?
    conference.unarchive!
    assert_nil conference.archived_at
    assert_not conference.archived?
  end

  test "archivable? returns true for past conferences" do
    past_conference = Conference.create!(
      village: @village,
      name: "Past Conference",
      start_date: Date.yesterday - 5.days,
      end_date: Date.yesterday
    )
    assert past_conference.archivable?
  end

  test "archivable? returns false for future conferences" do
    future_conference = Conference.create!(
      village: @village,
      name: "Future Conference",
      start_date: Date.tomorrow,
      end_date: Date.tomorrow + 3.days
    )
    assert_not future_conference.archivable?
  end

  test "archivable? returns false for ongoing conferences" do
    ongoing_conference = Conference.create!(
      village: @village,
      name: "Ongoing Conference",
      start_date: Date.yesterday,
      end_date: Date.tomorrow
    )
    assert_not ongoing_conference.archivable?
  end
end
