require "test_helper"

class ProgramTest < ActiveSupport::TestCase
  setup do
    @village = Village.create!(name: "Test Village", setup_complete: true)
  end

  test "should be valid with valid attributes" do
    program = Program.new(
      name: "Ham Test",
      description: "Amateur radio license testing",
      village: @village
    )
    assert program.valid?
  end

  test "should require name" do
    program = Program.new(
      description: "Amateur radio license testing",
      village: @village
    )
    assert_not program.valid?
    assert_includes program.errors[:name], "can't be blank"
  end

  test "should require village" do
    program = Program.new(
      name: "Ham Test",
      description: "Amateur radio license testing"
    )
    assert_not program.valid?
    assert_includes program.errors[:village], "must exist"
  end

  test "should belong to village" do
    program = Program.create!(
      name: "Ham Test",
      description: "Amateur radio license testing",
      village: @village
    )
    assert_equal @village, program.village
  end

  test "description is optional" do
    program = Program.new(
      name: "Ham Test",
      village: @village
    )
    assert program.valid?
  end

  test "name must be unique within village" do
    Program.create!(
      name: "Ham Test",
      description: "Amateur radio license testing",
      village: @village
    )

    duplicate = Program.new(
      name: "Ham Test",
      description: "Another description",
      village: @village
    )
    assert_not duplicate.valid?
    assert_includes duplicate.errors[:name], "must be unique within the village"
  end

  test "same name can exist in different villages" do
    other_village = Village.create!(name: "Other Village", setup_complete: true)
    Program.create!(
      name: "Ham Test",
      description: "Amateur radio license testing",
      village: @village
    )

    program_in_other_village = Program.new(
      name: "Ham Test",
      description: "Amateur radio license testing",
      village: other_village
    )
    assert program_in_other_village.valid?
  end
end
