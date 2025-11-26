require "test_helper"

class QualificationTest < ActiveSupport::TestCase
  setup do
    @village = Village.create!(name: "Test Village", setup_complete: true)
  end

  test "should be valid with all required fields" do
    qualification = Qualification.new(
      name: "Volunteer Examiner",
      description: "Can administer amateur radio license tests",
      village: @village
    )
    assert qualification.valid?
  end

  test "should require name" do
    qualification = Qualification.new(
      description: "A description",
      village: @village
    )
    assert_not qualification.valid?
    assert qualification.errors[:name].any?
  end

  test "should require description" do
    qualification = Qualification.new(
      name: "Test Qualification",
      village: @village
    )
    assert_not qualification.valid?
    assert qualification.errors[:description].any?
  end

  test "should require village" do
    qualification = Qualification.new(
      name: "Test Qualification",
      description: "A description"
    )
    assert_not qualification.valid?
    assert qualification.errors[:village].any?
  end

  test "name should be unique within village" do
    Qualification.create!(
      name: "Existing Qualification",
      description: "Desc",
      village: @village
    )
    duplicate = Qualification.new(
      name: "Existing Qualification",
      description: "Another Desc",
      village: @village
    )
    assert_not duplicate.valid?
    assert duplicate.errors[:name].any?
  end

  test "name can be duplicated across different villages" do
    another_village = Village.create!(name: "Another Village", setup_complete: true)
    Qualification.create!(
      name: "Shared Qualification",
      description: "Desc",
      village: @village
    )
    duplicate = Qualification.new(
      name: "Shared Qualification",
      description: "Another Desc",
      village: another_village
    )
    assert duplicate.valid?
  end

  test "should belong to a village" do
    qualification = Qualification.create!(
      name: "Test Qualification",
      description: "A test qualification",
      village: @village
    )
    assert_equal @village, qualification.village
  end
end
