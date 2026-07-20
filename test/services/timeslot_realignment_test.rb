require "test_helper"

# #226: day_schedules are keyed by calendar date (ISO), not positional index,
# so a start_date change never silently re-assigns a day's hours to a
# different date — and volunteers signed up on surviving days keep their
# shifts. Uses the repro from the ticket.
class TimeslotRealignmentTest < ActiveSupport::TestCase
  setup do
    @village = Village.create!(name: "Test Village", setup_complete: true)
    @day1 = Date.tomorrow
    @conference = Conference.create!(
      village: @village,
      name: "Test Conference",
      start_date: @day1,
      end_date: @day1 + 2.days,
      conference_hours_start: "09:00",
      conference_hours_end: "17:00"
    )
    @program = Program.create!(name: "Ham Exams", village: @village)
    # short / FULL / short — stored by calendar date.
    @cp = ConferenceProgram.create!(
      conference: @conference,
      program: @program,
      day_schedules: {
        @day1.iso8601 => { "enabled" => true, "start" => "09:00", "end" => "10:45" },
        (@day1 + 1.day).iso8601 => { "enabled" => true, "start" => "09:00", "end" => "16:45" },
        (@day1 + 2.days).iso8601 => { "enabled" => true, "start" => "09:00", "end" => "10:45" }
      }
    )
    @volunteer = User.create!(email: "vol@example.com", password: "password123",
                              password_confirmation: "password123", handle: "Vol One")
  end

  def slots_on(date)
    @cp.timeslots.where(start_time: date.in_time_zone.all_day).order(:start_time)
  end

  test "schedules are generated per calendar date" do
    assert_equal 7, slots_on(@day1).count           # 09:00-10:45
    assert_equal 31, slots_on(@day1 + 1.day).count  # 09:00-16:45
    assert_equal 7, slots_on(@day1 + 2.days).count
  end

  test "dropping the first day does not re-assign the full day's hours (the #226 repro)" do
    full_day = @day1 + 1.day
    thirteen_hundred = slots_on(full_day).find { |slot| slot.start_time.strftime("%H:%M") == "13:00" }
    VolunteerSignup.create!(user: @volunteer, timeslot: thirteen_hundred)

    @conference.update!(start_date: @day1 + 1.day)

    assert_equal 0, slots_on(@day1).count, "dropped day's slots removed"
    assert_equal 31, slots_on(full_day).count, "the full day KEEPS its full hours"
    assert VolunteerSignup.exists?(user: @volunteer, timeslot: thirteen_hundred),
           "the 13:00 signup on the surviving day survives"
  end

  test "dropping a day cancels (and notifies) only that day's signups" do
    first_day_slot = slots_on(@day1).first
    VolunteerSignup.create!(user: @volunteer, timeslot: first_day_slot)
    survivor_slot = slots_on(@day1 + 1.day).first
    VolunteerSignup.create!(user: @volunteer, timeslot: survivor_slot)

    assert_difference "Notification.count", 1 do
      @conference.update!(start_date: @day1 + 1.day)
    end
    assert_not VolunteerSignup.exists?(timeslot_id: first_day_slot.id)
    assert VolunteerSignup.exists?(timeslot_id: survivor_slot.id)
  end

  test "extending the conference a day earlier changes nothing on existing days" do
    signup = VolunteerSignup.create!(user: @volunteer, timeslot: slots_on(@day1).first)
    before_ids = @cp.timeslots.order(:start_time).pluck(:id)

    assert_no_difference "Notification.count" do
      @conference.update!(start_date: @day1 - 1.day)
    end

    assert_equal before_ids, @cp.timeslots.order(:start_time).pluck(:id), "no slot churn at all"
    assert VolunteerSignup.exists?(id: signup.id)
    assert_equal 0, slots_on(@day1 - 1.day).count, "the new day starts unscheduled"
  end

  test "a schedule for a date outside the range is retained and comes back when the range returns" do
    @conference.update!(end_date: @day1 + 1.day)   # drop the third day
    assert_equal 0, slots_on(@day1 + 2.days).count
    assert @cp.reload.day_schedules.key?((@day1 + 2.days).iso8601), "config retained"

    @conference.update!(end_date: @day1 + 2.days)  # bring it back
    assert_equal 7, slots_on(@day1 + 2.days).count, "slots regenerate from the retained config"
  end

  test "legacy positional index keys normalize to date keys on write" do
    legacy = ConferenceProgram.create!(
      conference: @conference,
      program: Program.create!(name: "Legacy Program", village: @village),
      day_schedules: {
        "0" => { "enabled" => true, "start" => "10:00", "end" => "11:00" },
        "2" => { "enabled" => true, "start" => "12:00", "end" => "13:00" }
      }
    )

    assert_equal [ @day1.iso8601, (@day1 + 2.days).iso8601 ], legacy.day_schedules.keys.sort
    assert_equal 4, legacy.timeslots.where(start_time: @day1.in_time_zone.all_day).count
  end
end
