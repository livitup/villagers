require "test_helper"

# Window/day-scoped admin write paths (#242): bulk add/remove a volunteer
# across a window and day-scoped capacity. Settled decisions: admins may
# over-cover (exceed needed); capacity is one value per activity per day.
class TimeslotBulkActionsTest < ActionDispatch::IntegrationTest
  setup do
    @village = Village.create!(name: "Test Village", setup_complete: true)
    @conference = Conference.create!(
      village: @village,
      name: "Test Conference",
      start_date: Date.tomorrow,
      end_date: Date.tomorrow + 1.day,
      conference_hours_start: "09:00",
      conference_hours_end: "17:00"
    )
    @program = Program.create!(name: "Ham Exams", village: @village)
    @cp = ConferenceProgram.create!(
      conference: @conference,
      program: @program,
      day_schedules: {
        "0" => { "enabled" => true, "start" => "09:00", "end" => "11:00" },
        "1" => { "enabled" => true, "start" => "09:00", "end" => "10:00" }
      }
    )
    @day1_slots = @cp.timeslots.where(start_time: @conference.start_date.in_time_zone.all_day).order(:start_time).to_a

    @admin = create_user("admin@example.com", handle: "Admin")
    UserRole.create!(user: @admin, role: Role.find_or_create_by!(name: Role::VILLAGE_ADMIN))
    @target = create_user("target@example.com", handle: "Radio Ray")
    sign_in @admin
  end

  def create_user(email, handle:)
    User.create!(email: email, password: "password123", password_confirmation: "password123", handle: handle)
  end

  def bulk_add(start_slot: @day1_slots.first, duration: 60, user: @target)
    post bulk_add_volunteer_conference_timeslots_path(@conference),
         params: { conference_program_id: @cp.id, user_id: user.id,
                   start_timeslot_id: start_slot.id, duration_minutes: duration }
  end

  # --- bulk add ---

  test "adds the volunteer to every slot in the window and keeps counters correct" do
    bulk_add(duration: 60)

    assert_response :redirect
    assert_equal 4, @target.volunteer_signups.count
    assert_equal @day1_slots.first(4).map(&:id).sort, @target.volunteer_signups.map(&:timeslot_id).sort
    assert_equal [ 1, 1, 1, 1, 0, 0, 0, 0 ], @day1_slots.map { |slot| slot.reload.current_volunteers_count }
    assert_match "Radio Ray", flash[:notice]
  end

  test "skips slots the volunteer is already on" do
    VolunteerSignup.create!(user: @target, timeslot: @day1_slots[1])

    bulk_add(duration: 60)

    assert_equal 4, @target.volunteer_signups.count
    assert_equal 1, @day1_slots[1].reload.current_volunteers_count, "no duplicate signup"
  end

  test "admin placement may over-cover a full slot" do
    other = create_user("other@example.com", handle: "Other Vol")
    VolunteerSignup.create!(user: other, timeslot: @day1_slots.first)   # 1/1 -> full

    bulk_add(duration: 15)

    assert_equal 1, @target.volunteer_signups.count
    assert_equal 2, @day1_slots.first.reload.current_volunteers_count
    assert_operator @day1_slots.first.current_volunteers_count, :>, @day1_slots.first.max_volunteers
  end

  test "rolls back the whole window when one slot fails validation" do
    # Overlapping signup on another program mid-window -> that slot fails.
    other_cp = ConferenceProgram.create!(
      conference: @conference,
      program: Program.create!(name: "Front Desk", village: @village),
      day_schedules: { "0" => { "enabled" => true, "start" => "09:30", "end" => "09:45" } }
    )
    VolunteerSignup.create!(user: @target, timeslot: other_cp.timeslots.first)

    bulk_add(duration: 60)

    assert_equal 1, @target.volunteer_signups.count, "only the pre-existing signup remains"
    assert_equal [ 0, 0, 0, 0 ], @day1_slots.first(4).map { |slot| slot.reload.current_volunteers_count }
    assert_match(/overlapping/i, flash[:alert])
  end

  test "still enforces qualifications" do
    qualification = Qualification.create!(name: "Licensed Ham", description: "License", village: @village)
    ProgramQualification.create!(program: @program, qualification: qualification)

    bulk_add(duration: 30)

    assert_equal 0, @target.volunteer_signups.count
    assert_match(/qualifications/i, flash[:alert])
  end

  # --- bulk remove ---

  test "removes the volunteer from only the window's slots" do
    @day1_slots.each { |slot| VolunteerSignup.create!(user: @target, timeslot: slot) }

    delete bulk_remove_volunteer_conference_timeslots_path(@conference),
           params: { conference_program_id: @cp.id, user_id: @target.id,
                     start_timeslot_id: @day1_slots[2].id, duration_minutes: 60 }

    assert_response :redirect
    remaining = @target.volunteer_signups.map(&:timeslot_id).sort
    assert_equal (@day1_slots.first(2) + @day1_slots.last(2)).map(&:id).sort, remaining
    assert_equal [ 1, 1, 0, 0, 0, 0, 1, 1 ], @day1_slots.map { |slot| slot.reload.current_volunteers_count }
  end

  # --- day-scoped capacity ---

  test "sets capacity for every slot of the activity on the date and nothing else" do
    other_cp = ConferenceProgram.create!(
      conference: @conference,
      program: Program.create!(name: "Front Desk", village: @village),
      day_schedules: { "0" => { "enabled" => true, "start" => "09:00", "end" => "10:00" } }
    )

    patch bulk_update_capacity_conference_timeslots_path(@conference),
          params: { conference_program_id: @cp.id, date: @conference.start_date.iso8601, max_volunteers: 3 }

    assert_response :redirect
    assert_equal [ 3 ], @day1_slots.map { |slot| slot.reload.max_volunteers }.uniq
    day2_slots = @cp.timeslots.where(start_time: (@conference.start_date + 1.day).in_time_zone.all_day)
    assert_equal [ 1 ], day2_slots.map(&:max_volunteers).uniq, "other day untouched"
    assert_equal [ 1 ], other_cp.timeslots.map(&:max_volunteers).uniq, "other activity untouched"
  end

  test "rejects a capacity below 1" do
    patch bulk_update_capacity_conference_timeslots_path(@conference),
          params: { conference_program_id: @cp.id, date: @conference.start_date.iso8601, max_volunteers: 0 }

    assert_match(/at least 1/i, flash[:alert])
    assert_equal [ 1 ], @day1_slots.map { |slot| slot.reload.max_volunteers }.uniq
  end

  # --- authorization ---

  test "the activity lead of this activity may use all three actions" do
    lead = create_user("lead@example.com", handle: "Lead")
    ConferenceProgramRole.create!(user: lead, conference_program: @cp, role_name: ConferenceProgramRole::ACTIVITY_LEAD)
    sign_in lead

    bulk_add(duration: 15)
    assert_equal 1, @target.volunteer_signups.count

    patch bulk_update_capacity_conference_timeslots_path(@conference),
          params: { conference_program_id: @cp.id, date: @conference.start_date.iso8601, max_volunteers: 2 }
    assert_equal [ 2 ], @day1_slots.map { |slot| slot.reload.max_volunteers }.uniq
  end

  test "an activity lead of a different activity is denied" do
    other_cp = ConferenceProgram.create!(
      conference: @conference,
      program: Program.create!(name: "Front Desk", village: @village),
      day_schedules: { "0" => { "enabled" => true, "start" => "09:00", "end" => "10:00" } }
    )
    outsider = create_user("outsider@example.com", handle: "Outsider")
    ConferenceProgramRole.create!(user: outsider, conference_program: other_cp, role_name: ConferenceProgramRole::ACTIVITY_LEAD)
    sign_in outsider

    bulk_add(duration: 15)

    assert_equal 0, @target.volunteer_signups.count
  end

  test "a plain volunteer is denied" do
    sign_in @target

    bulk_add(duration: 15, user: @target)
    assert_equal 0, @target.volunteer_signups.count

    patch bulk_update_capacity_conference_timeslots_path(@conference),
          params: { conference_program_id: @cp.id, date: @conference.start_date.iso8601, max_volunteers: 5 }
    assert_equal [ 1 ], @day1_slots.map { |slot| slot.reload.max_volunteers }.uniq
  end

  test "volunteer self-signup still cannot enter a full slot (over-cover is admin-only)" do
    other = create_user("other@example.com", handle: "Other Vol")
    VolunteerSignup.create!(user: other, timeslot: @day1_slots.first)   # full

    signup = VolunteerSignup.new(user: @target, timeslot: @day1_slots.first)
    assert_not signup.valid?
    assert_match(/full/i, signup.errors.full_messages.to_sentence)
  end
end
