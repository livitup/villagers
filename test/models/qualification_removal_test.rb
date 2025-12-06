require "test_helper"

class QualificationRemovalTest < ActiveSupport::TestCase
  setup do
    @village = Village.create!(name: "Test Village", setup_complete: true)
    @conference = Conference.create!(
      name: "Test Conference",
      location: "Test Location",
      start_date: Date.today + 1.day,
      end_date: Date.today + 2.days,
      conference_hours_start: Time.zone.parse("2000-01-01 09:00"),
      conference_hours_end: Time.zone.parse("2000-01-01 17:00"),
      village: @village
    )
    @qualification = Qualification.create!(
      name: "Radio License",
      description: "Ham radio license",
      village: @village
    )
    @user = User.create!(
      email: "volunteer@example.com",
      password: "password123",
      password_confirmation: "password123"
    )
    # Give user the global qualification
    UserQualification.create!(user: @user, qualification: @qualification)
  end

  test "valid qualification removal" do
    removal = QualificationRemoval.new(
      user: @user,
      qualification: @qualification,
      conference: @conference
    )
    assert removal.valid?
  end

  test "requires user" do
    removal = QualificationRemoval.new(
      qualification: @qualification,
      conference: @conference
    )
    assert_not removal.valid?
    assert_includes removal.errors[:user], "must exist"
  end

  test "requires qualification" do
    removal = QualificationRemoval.new(
      user: @user,
      conference: @conference
    )
    assert_not removal.valid?
    assert_includes removal.errors[:qualification], "must exist"
  end

  test "requires conference" do
    removal = QualificationRemoval.new(
      user: @user,
      qualification: @qualification
    )
    assert_not removal.valid?
    assert_includes removal.errors[:conference], "must exist"
  end

  test "same removal cannot exist twice" do
    QualificationRemoval.create!(
      user: @user,
      qualification: @qualification,
      conference: @conference
    )

    duplicate = QualificationRemoval.new(
      user: @user,
      qualification: @qualification,
      conference: @conference
    )
    assert_not duplicate.valid?
    assert_includes duplicate.errors[:user], "has already been taken"
  end

  test "same user-qualification can be removed in different conferences" do
    another_conference = Conference.create!(
      name: "Another Conference",
      location: "Another Location",
      start_date: Date.today + 10.days,
      end_date: Date.today + 11.days,
      conference_hours_start: Time.zone.parse("2000-01-01 09:00"),
      conference_hours_end: Time.zone.parse("2000-01-01 17:00"),
      village: @village
    )

    QualificationRemoval.create!(
      user: @user,
      qualification: @qualification,
      conference: @conference
    )

    removal = QualificationRemoval.new(
      user: @user,
      qualification: @qualification,
      conference: another_conference
    )
    assert removal.valid?
  end
end
