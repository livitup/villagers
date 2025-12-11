require "test_helper"

class ConferenceQualificationTest < ActiveSupport::TestCase
  setup do
    @village = Village.create!(name: "Test Village", setup_complete: true)
    @conference = Conference.create!(
      name: "Test Conference",
      city: "Test City", state: "NV", country: "US",
      start_date: Date.today + 1.day,
      end_date: Date.today + 2.days,
      conference_hours_start: Time.zone.parse("2000-01-01 09:00"),
      conference_hours_end: Time.zone.parse("2000-01-01 17:00"),
      village: @village
    )
  end

  test "valid conference qualification" do
    qualification = ConferenceQualification.new(
      name: "Badge Check Training",
      description: "Training for badge checking",
      conference: @conference
    )
    assert qualification.valid?
  end

  test "requires name" do
    qualification = ConferenceQualification.new(
      description: "Training for badge checking",
      conference: @conference
    )
    assert_not qualification.valid?
    assert_includes qualification.errors[:name], "can't be blank"
  end

  test "requires description" do
    qualification = ConferenceQualification.new(
      name: "Badge Check Training",
      conference: @conference
    )
    assert_not qualification.valid?
    assert_includes qualification.errors[:description], "can't be blank"
  end

  test "requires conference" do
    qualification = ConferenceQualification.new(
      name: "Badge Check Training",
      description: "Training for badge checking"
    )
    assert_not qualification.valid?
    assert_includes qualification.errors[:conference], "must exist"
  end

  test "name is unique within conference" do
    ConferenceQualification.create!(
      name: "Badge Check Training",
      description: "Training for badge checking",
      conference: @conference
    )

    duplicate = ConferenceQualification.new(
      name: "Badge Check Training",
      description: "Another description",
      conference: @conference
    )
    assert_not duplicate.valid?
    assert_includes duplicate.errors[:name], "has already been taken"
  end

  test "same name allowed in different conferences" do
    another_conference = Conference.create!(
      name: "Another Conference",
      city: "Another City", state: "TX", country: "US",
      start_date: Date.today + 10.days,
      end_date: Date.today + 11.days,
      conference_hours_start: Time.zone.parse("2000-01-01 09:00"),
      conference_hours_end: Time.zone.parse("2000-01-01 17:00"),
      village: @village
    )

    ConferenceQualification.create!(
      name: "Badge Check Training",
      description: "Training for badge checking",
      conference: @conference
    )

    qualification = ConferenceQualification.new(
      name: "Badge Check Training",
      description: "Training for badge checking",
      conference: another_conference
    )
    assert qualification.valid?
  end
end
