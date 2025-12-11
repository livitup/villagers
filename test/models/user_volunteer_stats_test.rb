require "test_helper"

class UserVolunteerStatsTest < ActiveSupport::TestCase
  setup do
    @village = Village.create!(name: "Test Village", setup_complete: true)
    @conference1 = Conference.create!(
      name: "Conference 2024",
      city: "Test City", state: "NV", country: "US",
      start_date: Date.today + 1.day,
      end_date: Date.today + 2.days,
      conference_hours_start: Time.zone.parse("2000-01-01 09:00"),
      conference_hours_end: Time.zone.parse("2000-01-01 17:00"),
      village: @village
    )
    @conference2 = Conference.create!(
      name: "Conference 2023",
      city: "Other City", state: "CA", country: "US",
      start_date: Date.today + 10.days,
      end_date: Date.today + 11.days,
      conference_hours_start: Time.zone.parse("2000-01-01 09:00"),
      conference_hours_end: Time.zone.parse("2000-01-01 17:00"),
      village: @village
    )
    @program = Program.create!(
      name: "Test Program",
      description: "A test program",
      village: @village
    )
    @cp1 = ConferenceProgram.create!(
      conference: @conference1,
      program: @program,
      day_schedules: {
        "0" => { "enabled" => true, "start" => "09:00", "end" => "10:00" }
      }
    )
    @cp2 = ConferenceProgram.create!(
      conference: @conference2,
      program: @program,
      day_schedules: {
        "0" => { "enabled" => true, "start" => "09:00", "end" => "10:00" }
      }
    )
    @user = User.create!(
      email: "volunteer@example.com",
      password: "password123",
      password_confirmation: "password123",
      name: "Test Volunteer"
    )
  end

  test "total_shifts returns 0 for user with no signups" do
    assert_equal 0, @user.total_shifts
  end

  test "total_shifts counts all volunteer signups" do
    timeslot1 = @cp1.timeslots.first
    timeslot2 = @cp1.timeslots.second
    VolunteerSignup.create!(user: @user, timeslot: timeslot1)
    VolunteerSignup.create!(user: @user, timeslot: timeslot2)

    assert_equal 2, @user.total_shifts
  end

  test "total_volunteer_hours returns 0 for user with no signups" do
    assert_equal 0.0, @user.total_volunteer_hours
  end

  test "total_volunteer_hours calculates hours from 15-minute timeslots" do
    # Each timeslot is 15 minutes = 0.25 hours
    timeslot1 = @cp1.timeslots.first
    timeslot2 = @cp1.timeslots.second
    VolunteerSignup.create!(user: @user, timeslot: timeslot1)
    VolunteerSignup.create!(user: @user, timeslot: timeslot2)

    # 2 timeslots * 15 minutes = 30 minutes = 0.5 hours
    assert_equal 0.5, @user.total_volunteer_hours
  end

  test "conferences_participated returns empty array for user with no signups" do
    assert_empty @user.conferences_participated
  end

  test "conferences_participated returns unique conferences" do
    timeslot1 = @cp1.timeslots.first
    timeslot2 = @cp1.timeslots.second
    timeslot3 = @cp2.timeslots.first

    VolunteerSignup.create!(user: @user, timeslot: timeslot1)
    VolunteerSignup.create!(user: @user, timeslot: timeslot2)
    VolunteerSignup.create!(user: @user, timeslot: timeslot3)

    conferences = @user.conferences_participated
    assert_equal 2, conferences.count
    assert_includes conferences, @conference1
    assert_includes conferences, @conference2
  end

  test "conferences_participated_count returns count of unique conferences" do
    timeslot1 = @cp1.timeslots.first
    timeslot2 = @cp1.timeslots.second
    timeslot3 = @cp2.timeslots.first

    VolunteerSignup.create!(user: @user, timeslot: timeslot1)
    VolunteerSignup.create!(user: @user, timeslot: timeslot2)
    VolunteerSignup.create!(user: @user, timeslot: timeslot3)

    assert_equal 2, @user.conferences_participated_count
  end

  test "shifts_for_conference returns shifts for specific conference" do
    timeslot1 = @cp1.timeslots.first
    timeslot2 = @cp1.timeslots.second
    timeslot3 = @cp2.timeslots.first

    VolunteerSignup.create!(user: @user, timeslot: timeslot1)
    VolunteerSignup.create!(user: @user, timeslot: timeslot2)
    VolunteerSignup.create!(user: @user, timeslot: timeslot3)

    assert_equal 2, @user.shifts_for_conference(@conference1)
    assert_equal 1, @user.shifts_for_conference(@conference2)
  end

  test "hours_for_conference returns hours for specific conference" do
    timeslot1 = @cp1.timeslots.first
    timeslot2 = @cp1.timeslots.second

    VolunteerSignup.create!(user: @user, timeslot: timeslot1)
    VolunteerSignup.create!(user: @user, timeslot: timeslot2)

    # 2 timeslots * 15 minutes = 0.5 hours
    assert_equal 0.5, @user.hours_for_conference(@conference1)
  end

  test "volunteer_signups_for_conference returns signups for specific conference" do
    timeslot1 = @cp1.timeslots.first
    timeslot2 = @cp2.timeslots.first

    signup1 = VolunteerSignup.create!(user: @user, timeslot: timeslot1)
    VolunteerSignup.create!(user: @user, timeslot: timeslot2)

    signups = @user.volunteer_signups_for_conference(@conference1)
    assert_equal 1, signups.count
    assert_includes signups, signup1
  end

  # Class method tests for leaderboard
  test "top_volunteers returns users ordered by total shifts descending" do
    user2 = User.create!(
      email: "volunteer2@example.com",
      password: "password123",
      password_confirmation: "password123",
      name: "Top Volunteer"
    )

    # user2 has 3 shifts, @user has 1 shift
    VolunteerSignup.create!(user: @user, timeslot: @cp1.timeslots.first)
    VolunteerSignup.create!(user: user2, timeslot: @cp1.timeslots.second)
    VolunteerSignup.create!(user: user2, timeslot: @cp1.timeslots.third)
    VolunteerSignup.create!(user: user2, timeslot: @cp2.timeslots.first)

    top = User.top_volunteers(10)
    assert_equal user2, top.first
    assert_equal @user, top.second
  end

  test "top_volunteers limits results" do
    # Create a program with more timeslots
    cp_large = ConferenceProgram.create!(
      conference: @conference1,
      program: Program.create!(name: "Large Program", description: "Many slots", village: @village),
      day_schedules: {
        "0" => { "enabled" => true, "start" => "09:00", "end" => "12:00" }
      }
    )

    5.times do |i|
      user = User.create!(
        email: "volunteer#{i}@example.com",
        password: "password123",
        password_confirmation: "password123"
      )
      VolunteerSignup.create!(user: user, timeslot: cp_large.timeslots[i])
    end

    assert_equal 3, User.top_volunteers(3).to_a.size
  end

  test "top_volunteers excludes users with no shifts" do
    User.create!(
      email: "inactive@example.com",
      password: "password123",
      password_confirmation: "password123"
    )
    VolunteerSignup.create!(user: @user, timeslot: @cp1.timeslots.first)

    top = User.top_volunteers(10).to_a
    assert_equal 1, top.size
    assert_equal @user, top.first
  end

  test "top_volunteers_for_conference returns users for specific conference" do
    user2 = User.create!(
      email: "volunteer2@example.com",
      password: "password123",
      password_confirmation: "password123"
    )

    # @user has shifts in both conferences, user2 only in conference2
    VolunteerSignup.create!(user: @user, timeslot: @cp1.timeslots.first)
    VolunteerSignup.create!(user: user2, timeslot: @cp2.timeslots.first)
    VolunteerSignup.create!(user: user2, timeslot: @cp2.timeslots.second)

    top_c1 = User.top_volunteers_for_conference(@conference1, 10).to_a
    assert_equal 1, top_c1.size
    assert_equal @user, top_c1.first

    top_c2 = User.top_volunteers_for_conference(@conference2, 10).to_a
    assert_equal user2, top_c2.first
  end
end
