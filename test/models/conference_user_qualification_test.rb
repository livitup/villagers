require "test_helper"

class ConferenceUserQualificationTest < ActiveSupport::TestCase
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
    @qualification = ConferenceQualification.create!(
      name: "Badge Check Training",
      description: "Training for badge checking",
      conference: @conference
    )
    @user = User.create!(
      email: "volunteer@example.com",
      password: "password123",
      password_confirmation: "password123"
    )
  end

  test "valid conference user qualification" do
    user_qual = ConferenceUserQualification.new(
      user: @user,
      conference_qualification: @qualification
    )
    assert user_qual.valid?
  end

  test "requires user" do
    user_qual = ConferenceUserQualification.new(
      conference_qualification: @qualification
    )
    assert_not user_qual.valid?
    assert_includes user_qual.errors[:user], "must exist"
  end

  test "requires conference qualification" do
    user_qual = ConferenceUserQualification.new(
      user: @user
    )
    assert_not user_qual.valid?
    assert_includes user_qual.errors[:conference_qualification], "must exist"
  end

  test "user can only have qualification once" do
    ConferenceUserQualification.create!(
      user: @user,
      conference_qualification: @qualification
    )

    duplicate = ConferenceUserQualification.new(
      user: @user,
      conference_qualification: @qualification
    )
    assert_not duplicate.valid?
    assert_includes duplicate.errors[:user], "has already been taken"
  end

  test "different users can have same qualification" do
    ConferenceUserQualification.create!(
      user: @user,
      conference_qualification: @qualification
    )

    another_user = User.create!(
      email: "another@example.com",
      password: "password123",
      password_confirmation: "password123"
    )

    user_qual = ConferenceUserQualification.new(
      user: another_user,
      conference_qualification: @qualification
    )
    assert user_qual.valid?
  end
end
