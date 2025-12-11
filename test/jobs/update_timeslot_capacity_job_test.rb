require "test_helper"

class UpdateTimeslotCapacityJobTest < ActiveJob::TestCase
  setup do
    @village = Village.create!(name: "Test Village", setup_complete: true)
    @conference = Conference.create!(
      name: "Test Conference",
      village: @village,
      start_date: Date.tomorrow,
      end_date: Date.tomorrow + 2.days,
      conference_hours_start: Time.zone.parse("2000-01-01 09:00"),
      conference_hours_end: Time.zone.parse("2000-01-01 12:00")
    )
    @program = Program.create!(
      name: "Test Program",
      village: @village,
      max_volunteers: 2
    )
    @conference_program = ConferenceProgram.create!(
      conference: @conference,
      program: @program,
      day_schedules: {
        "0" => { "enabled" => true, "start" => "09:00", "end" => "10:00" }
      }
    )
  end

  test "updates all timeslot max_volunteers for a conference_program" do
    # All timeslots should have initial max_volunteers of 2 (from program default)
    assert @conference_program.timeslots.all? { |ts| ts.max_volunteers == 2 }

    # Run job to update to new capacity
    UpdateTimeslotCapacityJob.perform_now(@conference_program.id, 5)

    # Verify all timeslots updated
    @conference_program.timeslots.reload.each do |timeslot|
      assert_equal 5, timeslot.max_volunteers
    end
  end

  test "does not reduce capacity below current signups" do
    timeslot = @conference_program.timeslots.first
    user1 = User.create!(email: "user1@example.com", password: "password123", password_confirmation: "password123")
    user2 = User.create!(email: "user2@example.com", password: "password123", password_confirmation: "password123")
    VolunteerSignup.create!(timeslot: timeslot, user: user1)
    VolunteerSignup.create!(timeslot: timeslot, user: user2)
    timeslot.update!(current_volunteers_count: 2)

    # Try to reduce capacity to 1 (below current signups of 2)
    UpdateTimeslotCapacityJob.perform_now(@conference_program.id, 1)

    # Timeslot should keep capacity at 2 (current signups), not reduce to 1
    timeslot.reload
    assert_equal 2, timeslot.max_volunteers
  end

  test "handles missing conference_program gracefully" do
    # Should not raise an error for non-existent conference_program
    assert_nothing_raised do
      UpdateTimeslotCapacityJob.perform_now(999999, 5)
    end
  end

  test "job is idempotent" do
    # Running the job twice with same value should produce same result
    UpdateTimeslotCapacityJob.perform_now(@conference_program.id, 5)
    UpdateTimeslotCapacityJob.perform_now(@conference_program.id, 5)

    @conference_program.timeslots.reload.each do |timeslot|
      assert_equal 5, timeslot.max_volunteers
    end
  end

  test "returns count of updated and skipped timeslots" do
    timeslot = @conference_program.timeslots.first
    user1 = User.create!(email: "user1@example.com", password: "password123", password_confirmation: "password123")
    user2 = User.create!(email: "user2@example.com", password: "password123", password_confirmation: "password123")
    VolunteerSignup.create!(timeslot: timeslot, user: user1)
    VolunteerSignup.create!(timeslot: timeslot, user: user2)
    timeslot.update!(current_volunteers_count: 2)

    # Reduce to 1 - the timeslot with 2 signups should be skipped
    result = UpdateTimeslotCapacityJob.perform_now(@conference_program.id, 1)

    assert_kind_of Hash, result
    assert result[:skipped] >= 1
  end
end
