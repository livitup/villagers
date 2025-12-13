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

  # Conference lead tests
  test "primary_lead returns the first conference lead" do
    conference = Conference.create!(
      village: @village,
      name: "Test Conference",
      start_date: Date.tomorrow,
      end_date: Date.tomorrow + 3.days
    )
    user = User.create!(email: "lead@example.com", password: "password123", password_confirmation: "password123")
    ConferenceRole.create!(user: user, conference: conference, role_name: ConferenceRole::CONFERENCE_LEAD)

    assert_equal user, conference.primary_lead
  end

  test "primary_lead returns nil when no lead assigned" do
    conference = Conference.create!(
      village: @village,
      name: "Test Conference",
      start_date: Date.tomorrow,
      end_date: Date.tomorrow + 3.days
    )

    assert_nil conference.primary_lead
  end

  test "conference_leads returns all conference leads" do
    conference = Conference.create!(
      village: @village,
      name: "Test Conference",
      start_date: Date.tomorrow,
      end_date: Date.tomorrow + 3.days
    )
    lead1 = User.create!(email: "lead1@example.com", password: "password123", password_confirmation: "password123")
    lead2 = User.create!(email: "lead2@example.com", password: "password123", password_confirmation: "password123")
    ConferenceRole.create!(user: lead1, conference: conference, role_name: ConferenceRole::CONFERENCE_LEAD)
    ConferenceRole.create!(user: lead2, conference: conference, role_name: ConferenceRole::CONFERENCE_LEAD)

    assert_equal 2, conference.conference_leads.count
    assert_includes conference.conference_leads, lead1
    assert_includes conference.conference_leads, lead2
  end

  test "lead_display_name returns user name when available" do
    conference = Conference.create!(
      village: @village,
      name: "Test Conference",
      start_date: Date.tomorrow,
      end_date: Date.tomorrow + 3.days
    )
    user = User.create!(email: "lead@example.com", password: "password123", password_confirmation: "password123", name: "John Doe")
    ConferenceRole.create!(user: user, conference: conference, role_name: ConferenceRole::CONFERENCE_LEAD)

    assert_equal "John Doe", conference.lead_display_name
  end

  test "lead_display_name returns email when name not available" do
    conference = Conference.create!(
      village: @village,
      name: "Test Conference",
      start_date: Date.tomorrow,
      end_date: Date.tomorrow + 3.days
    )
    user = User.create!(email: "lead@example.com", password: "password123", password_confirmation: "password123")
    ConferenceRole.create!(user: user, conference: conference, role_name: ConferenceRole::CONFERENCE_LEAD)

    assert_equal "lead@example.com", conference.lead_display_name
  end

  test "lead_display_name shows count when multiple leads" do
    conference = Conference.create!(
      village: @village,
      name: "Test Conference",
      start_date: Date.tomorrow,
      end_date: Date.tomorrow + 3.days
    )
    lead1 = User.create!(email: "lead1@example.com", password: "password123", password_confirmation: "password123", name: "Jane Doe")
    lead2 = User.create!(email: "lead2@example.com", password: "password123", password_confirmation: "password123")
    ConferenceRole.create!(user: lead1, conference: conference, role_name: ConferenceRole::CONFERENCE_LEAD)
    ConferenceRole.create!(user: lead2, conference: conference, role_name: ConferenceRole::CONFERENCE_LEAD)

    assert_equal "Jane Doe +1", conference.lead_display_name
  end

  test "lead_display_name returns message when no lead assigned" do
    conference = Conference.create!(
      village: @village,
      name: "Test Conference",
      start_date: Date.tomorrow,
      end_date: Date.tomorrow + 3.days
    )

    assert_equal "No lead assigned", conference.lead_display_name
  end
end
