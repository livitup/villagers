require "test_helper"

class QualificationAssignmentDelegationTest < ActiveSupport::TestCase
  setup do
    @village = Village.create!(name: "Test Village", setup_complete: true)
    @conference = Conference.create!(
      village: @village, name: "Test Conference",
      start_date: Date.tomorrow, end_date: Date.tomorrow + 2.days
    )
    @qualification = Qualification.create!(village: @village, name: "Foobar", description: "Can foo")
    @other_qualification = Qualification.create!(village: @village, name: "Bazzer", description: "Can baz")
    @user = User.create!(email: "delegate@example.com", password: "password123", password_confirmation: "password123")
  end

  test "is valid with user, qualification, and conference" do
    delegation = QualificationAssignmentDelegation.new(user: @user, qualification: @qualification, conference: @conference)
    assert delegation.valid?
  end

  test "does not allow duplicate delegation for the same user, qualification, and conference" do
    QualificationAssignmentDelegation.create!(user: @user, qualification: @qualification, conference: @conference)
    dup = QualificationAssignmentDelegation.new(user: @user, qualification: @qualification, conference: @conference)
    assert_not dup.valid?
  end

  test "can_assign_qualification? is true for a delegate of that qualification and conference only" do
    QualificationAssignmentDelegation.create!(user: @user, qualification: @qualification, conference: @conference)

    assert @user.can_assign_qualification?(@qualification, @conference)
    assert_not @user.can_assign_qualification?(@other_qualification, @conference)

    other_conference = Conference.create!(
      village: @village, name: "Other", start_date: Date.tomorrow, end_date: Date.tomorrow + 1.day
    )
    assert_not @user.can_assign_qualification?(@qualification, other_conference)
  end

  test "can_assign_qualification? is true for any conference manager" do
    admin = User.create!(email: "admin@example.com", password: "password123", password_confirmation: "password123")
    UserRole.create!(user: admin, role: Role.find_or_create_by!(name: Role::VILLAGE_ADMIN))
    assert admin.can_assign_qualification?(@qualification, @conference)
    assert admin.can_assign_qualification?(@other_qualification, @conference)
  end

  test "assignable_qualifications returns only delegated ones for a delegate" do
    QualificationAssignmentDelegation.create!(user: @user, qualification: @qualification, conference: @conference)
    assert_equal [ @qualification ], @user.assignable_qualifications(@conference).to_a
  end

  test "assignable_qualifications returns all village qualifications for a manager" do
    admin = User.create!(email: "admin@example.com", password: "password123", password_confirmation: "password123")
    UserRole.create!(user: admin, role: Role.find_or_create_by!(name: Role::VILLAGE_ADMIN))
    assert_equal [ @other_qualification, @qualification ].sort_by(&:name), admin.assignable_qualifications(@conference).to_a
  end
end
