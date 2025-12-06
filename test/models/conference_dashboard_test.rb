# frozen_string_literal: true

require "test_helper"

class ConferenceDashboardTest < ActiveSupport::TestCase
  def setup
    @village = Village.create!(name: "Test Village", setup_complete: true)
    @conference = Conference.create!(
      name: "Test Conference",
      village: @village,
      start_date: Date.current,
      end_date: Date.current + 3.days,
      conference_hours_start: Time.zone.parse("2000-01-01 09:00"),
      conference_hours_end: Time.zone.parse("2000-01-01 17:00")
    )
    @program = Program.create!(name: "Test Program", max_volunteers: 2, village: @village)
  end

  test "total_timeslots returns count of all timeslots" do
    conference_program = ConferenceProgram.create!(
      conference: @conference,
      program: @program,
      day_schedules: { "0" => { "enabled" => true, "start_time" => "09:00", "end_time" => "10:00" } }
    )

    assert @conference.total_timeslots > 0
    expected_count = @conference.timeslots.count
    assert_equal expected_count, @conference.total_timeslots
  end

  test "total_timeslots returns zero when no programs" do
    assert_equal 0, @conference.total_timeslots
  end

  test "filled_timeslots returns count of timeslots at max capacity" do
    conference_program = ConferenceProgram.create!(
      conference: @conference,
      program: @program,
      max_volunteers: 1,
      day_schedules: { "0" => { "enabled" => true, "start_time" => "09:00", "end_time" => "09:30" } }
    )

    timeslot = conference_program.timeslots.first
    assert timeslot.present?

    user = create_test_user
    VolunteerSignup.create!(user: user, timeslot: timeslot)

    assert_equal 1, @conference.filled_timeslots
  end

  test "filled_timeslots returns zero when no timeslots are full" do
    conference_program = ConferenceProgram.create!(
      conference: @conference,
      program: @program,
      max_volunteers: 2,
      day_schedules: { "0" => { "enabled" => true, "start_time" => "09:00", "end_time" => "09:30" } }
    )

    assert_equal 0, @conference.filled_timeslots
  end

  test "unfilled_timeslots returns count of timeslots with available spots" do
    conference_program = ConferenceProgram.create!(
      conference: @conference,
      program: @program,
      max_volunteers: 2,
      day_schedules: { "0" => { "enabled" => true, "start_time" => "09:00", "end_time" => "09:30" } }
    )

    total = @conference.total_timeslots
    assert total > 0
    assert_equal total, @conference.unfilled_timeslots
  end

  test "unfilled_timeslots decreases when timeslots are filled" do
    conference_program = ConferenceProgram.create!(
      conference: @conference,
      program: @program,
      max_volunteers: 1,
      day_schedules: { "0" => { "enabled" => true, "start_time" => "09:00", "end_time" => "09:30" } }
    )

    total_before = @conference.total_timeslots
    unfilled_before = @conference.unfilled_timeslots
    assert_equal total_before, unfilled_before

    timeslot = conference_program.timeslots.first
    user = create_test_user
    VolunteerSignup.create!(user: user, timeslot: timeslot)

    assert_equal unfilled_before - 1, @conference.unfilled_timeslots
  end

  test "volunteer_count returns count of unique volunteers" do
    conference_program = ConferenceProgram.create!(
      conference: @conference,
      program: @program,
      max_volunteers: 3,
      day_schedules: { "0" => { "enabled" => true, "start_time" => "09:00", "end_time" => "10:00" } }
    )

    timeslots = conference_program.timeslots.first(2)
    user1 = create_test_user(email: "user1@test.com")
    user2 = create_test_user(email: "user2@test.com")

    # User1 signs up for two timeslots
    VolunteerSignup.create!(user: user1, timeslot: timeslots[0])
    VolunteerSignup.create!(user: user1, timeslot: timeslots[1])
    # User2 signs up for one timeslot
    VolunteerSignup.create!(user: user2, timeslot: timeslots[0])

    assert_equal 2, @conference.volunteer_count
  end

  test "volunteer_count returns zero when no signups" do
    assert_equal 0, @conference.volunteer_count
  end

  test "programs_count returns count of conference programs" do
    assert_equal 0, @conference.programs_count

    ConferenceProgram.create!(
      conference: @conference,
      program: @program,
      day_schedules: { "0" => { "enabled" => true, "start_time" => "09:00", "end_time" => "10:00" } }
    )

    assert_equal 1, @conference.programs_count
  end

  test "total_volunteer_hours returns sum of filled timeslots in hours" do
    conference_program = ConferenceProgram.create!(
      conference: @conference,
      program: @program,
      max_volunteers: 1,
      day_schedules: { "0" => { "enabled" => true, "start_time" => "09:00", "end_time" => "10:00" } }
    )

    # Each timeslot is 15 minutes = 0.25 hours
    timeslots = conference_program.timeslots.first(4)
    user = create_test_user

    timeslots.each do |ts|
      VolunteerSignup.create!(user: user, timeslot: ts)
    end

    # 4 signups * 0.25 hours = 1.0 hour
    assert_equal 1.0, @conference.total_volunteer_hours
  end

  test "total_volunteer_hours returns zero when no signups" do
    assert_equal 0.0, @conference.total_volunteer_hours
  end

  test "fill_rate returns percentage of filled timeslots" do
    conference_program = ConferenceProgram.create!(
      conference: @conference,
      program: @program,
      max_volunteers: 1,
      day_schedules: { "0" => { "enabled" => true, "start_time" => "09:00", "end_time" => "09:30" } }
    )

    total = @conference.total_timeslots
    assert total > 0

    # Fill half the timeslots
    timeslots_to_fill = conference_program.timeslots.first(total / 2)
    timeslots_to_fill.each_with_index do |ts, i|
      user = create_test_user(email: "user#{i}@test.com")
      VolunteerSignup.create!(user: user, timeslot: ts)
    end

    expected_rate = (timeslots_to_fill.size.to_f / total * 100).round(1)
    assert_equal expected_rate, @conference.fill_rate
  end

  test "fill_rate returns zero when no timeslots" do
    assert_equal 0.0, @conference.fill_rate
  end

  test "recent_signups returns signups ordered by creation" do
    conference_program = ConferenceProgram.create!(
      conference: @conference,
      program: @program,
      max_volunteers: 3,
      day_schedules: { "0" => { "enabled" => true, "start_time" => "09:00", "end_time" => "10:00" } }
    )

    timeslots = conference_program.timeslots.first(3)
    user1 = create_test_user(email: "user1@test.com")
    user2 = create_test_user(email: "user2@test.com")
    user3 = create_test_user(email: "user3@test.com")

    signup1 = VolunteerSignup.create!(user: user1, timeslot: timeslots[0])
    signup2 = VolunteerSignup.create!(user: user2, timeslot: timeslots[1])
    signup3 = VolunteerSignup.create!(user: user3, timeslot: timeslots[2])

    recent = @conference.recent_signups(2)
    assert_equal 2, recent.count
    assert_equal signup3.id, recent.first.id
    assert_equal signup2.id, recent.second.id
  end

  test "recent_signups defaults to 5 signups" do
    conference_program = ConferenceProgram.create!(
      conference: @conference,
      program: @program,
      max_volunteers: 10,
      day_schedules: { "0" => { "enabled" => true, "start_time" => "09:00", "end_time" => "12:00" } }
    )

    timeslots = conference_program.timeslots.first(7)
    7.times do |i|
      user = create_test_user(email: "user#{i}@test.com")
      VolunteerSignup.create!(user: user, timeslot: timeslots[i])
    end

    assert_equal 5, @conference.recent_signups.count
  end

  private

  def create_test_user(email: "test#{SecureRandom.hex(4)}@test.com")
    User.create!(
      email: email,
      password: "password123",
      password_confirmation: "password123"
    )
  end
end
