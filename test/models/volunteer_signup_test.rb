require "test_helper"

class VolunteerSignupTest < ActiveSupport::TestCase
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
    @program = Program.create!(
      name: "Test Program",
      description: "A test program",
      village: @village
    )
    @conference_program = ConferenceProgram.create!(
      conference: @conference,
      program: @program,
      day_schedules: {
        "0" => { "enabled" => true, "start" => "09:00", "end" => "10:00" }
      }
    )
    @timeslot = @conference_program.timeslots.first
    @user = User.create!(
      email: "volunteer@example.com",
      password: "password123",
      password_confirmation: "password123"
    )
  end

  test "should be valid with all required fields" do
    signup = VolunteerSignup.new(
      user: @user,
      timeslot: @timeslot
    )
    assert signup.valid?
  end

  test "should require user" do
    signup = VolunteerSignup.new(timeslot: @timeslot)
    assert_not signup.valid?
    assert signup.errors[:user].any?
  end

  test "should require timeslot" do
    signup = VolunteerSignup.new(user: @user)
    assert_not signup.valid?
    assert signup.errors[:timeslot].any?
  end

  test "should prevent double signup for same timeslot" do
    VolunteerSignup.create!(user: @user, timeslot: @timeslot)
    duplicate = VolunteerSignup.new(user: @user, timeslot: @timeslot)
    assert_not duplicate.valid?
    assert duplicate.errors[:timeslot].any?
  end

  test "should prevent overlapping timeslots" do
    another_program = Program.create!(
      name: "Another Program",
      description: "Another program",
      village: @village
    )
    another_cp = ConferenceProgram.create!(
      conference: @conference,
      program: another_program,
      day_schedules: {
        "0" => { "enabled" => true, "start" => "09:00", "end" => "10:00" }
      }
    )
    overlapping_timeslot = another_cp.timeslots.find_by(start_time: @timeslot.start_time)

    VolunteerSignup.create!(user: @user, timeslot: @timeslot)
    overlapping = VolunteerSignup.new(user: @user, timeslot: overlapping_timeslot)
    assert_not overlapping.valid?
    assert overlapping.errors[:base].any?
  end

  test "should allow signup for non-overlapping timeslots" do
    another_program = Program.create!(
      name: "Another Program",
      description: "Another program",
      village: @village
    )
    another_cp = ConferenceProgram.create!(
      conference: @conference,
      program: another_program,
      day_schedules: {
        "0" => { "enabled" => true, "start" => "10:00", "end" => "11:00" }
      }
    )
    non_overlapping_timeslot = another_cp.timeslots.first

    VolunteerSignup.create!(user: @user, timeslot: @timeslot)
    non_overlapping = VolunteerSignup.new(user: @user, timeslot: non_overlapping_timeslot)
    assert non_overlapping.valid?
  end

  test "should belong to user" do
    signup = VolunteerSignup.create!(user: @user, timeslot: @timeslot)
    assert_equal @user, signup.user
  end

  test "should belong to timeslot" do
    signup = VolunteerSignup.create!(user: @user, timeslot: @timeslot)
    assert_equal @timeslot, signup.timeslot
  end

  test "should update timeslot current_volunteers_count on create" do
    initial_count = @timeslot.current_volunteers_count
    VolunteerSignup.create!(user: @user, timeslot: @timeslot)
    @timeslot.reload
    assert_equal initial_count + 1, @timeslot.current_volunteers_count
  end

  test "should update timeslot current_volunteers_count on destroy" do
    signup = VolunteerSignup.create!(user: @user, timeslot: @timeslot)
    @timeslot.reload
    count_after_create = @timeslot.current_volunteers_count
    signup.destroy
    @timeslot.reload
    assert_equal count_after_create - 1, @timeslot.current_volunteers_count
  end

  test "should allow signup when user has required qualification" do
    qualification = Qualification.create!(
      name: "Licensed Ham",
      description: "Ham radio license",
      village: @village
    )
    ProgramQualification.create!(program: @program, qualification: qualification)
    UserQualification.create!(user: @user, qualification: qualification)

    signup = VolunteerSignup.new(user: @user, timeslot: @timeslot)
    assert signup.valid?
  end

  test "should prevent signup when user lacks required qualification" do
    qualification = Qualification.create!(
      name: "Licensed Ham",
      description: "Ham radio license",
      village: @village
    )
    ProgramQualification.create!(program: @program, qualification: qualification)
    # User does NOT have the qualification

    signup = VolunteerSignup.new(user: @user, timeslot: @timeslot)
    assert_not signup.valid?
    assert signup.errors[:base].any?
    assert_match(/required qualifications/, signup.errors[:base].first)
  end

  test "should allow signup when program has no required qualifications" do
    # No qualifications required for program
    signup = VolunteerSignup.new(user: @user, timeslot: @timeslot)
    assert signup.valid?
  end

  test "should prevent signup when user lacks one of multiple required qualifications" do
    qual1 = Qualification.create!(name: "Qual 1", description: "First qual", village: @village)
    qual2 = Qualification.create!(name: "Qual 2", description: "Second qual", village: @village)
    ProgramQualification.create!(program: @program, qualification: qual1)
    ProgramQualification.create!(program: @program, qualification: qual2)
    # User only has one qualification
    UserQualification.create!(user: @user, qualification: qual1)

    signup = VolunteerSignup.new(user: @user, timeslot: @timeslot)
    assert_not signup.valid?
    assert_match(/Qual 2/, signup.errors[:base].first)
  end
end
