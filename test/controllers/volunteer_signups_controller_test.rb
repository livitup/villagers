require "test_helper"

class VolunteerSignupsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @village = Village.create!(name: "Test Village", setup_complete: true)
    @village_admin = User.create!(
      email: "admin@example.com",
      password: "password123",
      password_confirmation: "password123"
    )
    @volunteer = User.create!(
      email: "volunteer@example.com",
      password: "password123",
      password_confirmation: "password123"
    )
    @volunteer2 = User.create!(
      email: "volunteer2@example.com",
      password: "password123",
      password_confirmation: "password123"
    )

    village_admin_role = Role.find_or_create_by!(name: Role::VILLAGE_ADMIN)
    UserRole.create!(user: @village_admin, role: village_admin_role)

    @conference = Conference.create!(
      village: @village,
      name: "Test Conference",
      start_date: Date.tomorrow,
      end_date: Date.tomorrow + 2.days,
      conference_hours_start: "09:00",
      conference_hours_end: "17:00"
    )

    @program = Program.create!(
      name: "Test Program",
      village: @village
    )

    @conference_program = ConferenceProgram.create!(
      conference: @conference,
      program: @program
    )

    @timeslot = Timeslot.create!(
      conference_program: @conference_program,
      start_time: Date.tomorrow.to_datetime + 9.hours,
      max_volunteers: 2
    )

    @timeslot2 = Timeslot.create!(
      conference_program: @conference_program,
      start_time: Date.tomorrow.to_datetime + 10.hours,
      max_volunteers: 2
    )
  end

  # Index tests
  test "should get index as authenticated user" do
    sign_in @volunteer
    get conference_volunteer_signups_url(@conference)
    assert_response :success
  end

  test "should redirect index to login when not authenticated" do
    get conference_volunteer_signups_url(@conference)
    assert_redirected_to new_user_session_path
  end

  test "index shows user's signups for this conference" do
    VolunteerSignup.create!(user: @volunteer, timeslot: @timeslot)
    sign_in @volunteer
    get conference_volunteer_signups_url(@conference)
    assert_response :success
  end

  # Create tests
  test "should create signup for available timeslot" do
    sign_in @volunteer
    assert_difference("VolunteerSignup.count") do
      post conference_volunteer_signups_url(@conference), params: {
        timeslot_id: @timeslot.id
      }
    end
    assert_redirected_to conference_volunteer_signups_path(@conference)
  end

  test "should not create duplicate signup" do
    VolunteerSignup.create!(user: @volunteer, timeslot: @timeslot)
    sign_in @volunteer
    assert_no_difference("VolunteerSignup.count") do
      post conference_volunteer_signups_url(@conference), params: {
        timeslot_id: @timeslot.id
      }
    end
    assert_redirected_to conference_volunteer_signups_path(@conference)
  end

  test "should not create signup when timeslot is full" do
    # Fill the timeslot
    @timeslot.update!(max_volunteers: 1)
    VolunteerSignup.create!(user: @volunteer2, timeslot: @timeslot)

    sign_in @volunteer
    assert_no_difference("VolunteerSignup.count") do
      post conference_volunteer_signups_url(@conference), params: {
        timeslot_id: @timeslot.id
      }
    end
    assert_redirected_to conference_volunteer_signups_path(@conference)
  end

  test "should redirect create to login when not authenticated" do
    assert_no_difference("VolunteerSignup.count") do
      post conference_volunteer_signups_url(@conference), params: {
        timeslot_id: @timeslot.id
      }
    end
    assert_redirected_to new_user_session_path
  end

  # Destroy tests
  test "should destroy own signup" do
    signup = VolunteerSignup.create!(user: @volunteer, timeslot: @timeslot)
    sign_in @volunteer
    assert_difference("VolunteerSignup.count", -1) do
      delete conference_volunteer_signup_url(@conference, signup)
    end
    assert_redirected_to conference_volunteer_signups_path(@conference)
  end

  test "should not destroy other user's signup" do
    signup = VolunteerSignup.create!(user: @volunteer2, timeslot: @timeslot)
    sign_in @volunteer
    # The controller scopes to current_user.volunteer_signups, so the signup won't be found
    # and the request will fail (either with 404 or ActiveRecord::RecordNotFound)
    assert_no_difference("VolunteerSignup.count") do
      begin
        delete conference_volunteer_signup_url(@conference, signup)
      rescue ActiveRecord::RecordNotFound
        # Expected behavior - signup not found in user's signups scope
      end
    end
  end

  test "should redirect destroy to login when not authenticated" do
    signup = VolunteerSignup.create!(user: @volunteer, timeslot: @timeslot)
    assert_no_difference("VolunteerSignup.count") do
      delete conference_volunteer_signup_url(@conference, signup)
    end
    assert_redirected_to new_user_session_path
  end

  test "multiple signups for different timeslots are allowed" do
    sign_in @volunteer
    assert_difference("VolunteerSignup.count", 2) do
      post conference_volunteer_signups_url(@conference), params: {
        timeslot_id: @timeslot.id
      }
      post conference_volunteer_signups_url(@conference), params: {
        timeslot_id: @timeslot2.id
      }
    end
  end

  # Bulk create tests
  test "bulk create signs up for multiple consecutive timeslots" do
    # Create 4 consecutive 15-minute timeslots (1 hour total)
    timeslots = []
    4.times do |i|
      timeslots << Timeslot.create!(
        conference_program: @conference_program,
        start_time: Date.tomorrow.to_datetime + 11.hours + (i * 15).minutes,
        max_volunteers: 2
      )
    end

    sign_in @volunteer
    assert_difference("VolunteerSignup.count", 4) do
      post bulk_create_conference_volunteer_signups_url(@conference), params: {
        timeslot_id: timeslots.first.id,
        end_time: timeslots.last.end_time.iso8601
      }
    end
    assert_redirected_to conference_volunteer_signups_path(@conference)
    assert_match(/4 shifts/, flash[:notice])
  end

  test "bulk create with duration parameter" do
    # Create 4 consecutive 15-minute timeslots
    timeslots = []
    4.times do |i|
      timeslots << Timeslot.create!(
        conference_program: @conference_program,
        start_time: Date.tomorrow.to_datetime + 11.hours + (i * 15).minutes,
        max_volunteers: 2
      )
    end

    sign_in @volunteer
    assert_difference("VolunteerSignup.count", 4) do
      post bulk_create_conference_volunteer_signups_url(@conference), params: {
        timeslot_id: timeslots.first.id,
        duration_minutes: 60
      }
    end
    assert_redirected_to conference_volunteer_signups_path(@conference)
  end

  test "bulk create rejects duration below conference minimum_shift_duration" do
    @conference.update!(minimum_shift_duration: 60)

    timeslots = []
    4.times do |i|
      timeslots << Timeslot.create!(
        conference_program: @conference_program,
        start_time: Date.tomorrow.to_datetime + 11.hours + (i * 15).minutes,
        max_volunteers: 2
      )
    end

    sign_in @volunteer
    assert_no_difference("VolunteerSignup.count") do
      post bulk_create_conference_volunteer_signups_url(@conference), params: {
        timeslot_id: timeslots.first.id,
        duration_minutes: 30
      }
    end
    assert_redirected_to conference_schedule_path(@conference)
    assert_match(/block/i, flash[:alert])
  end

  test "bulk create rejects a duration that is not a whole number of blocks" do
    @conference.update!(minimum_shift_duration: 30)

    timeslots = []
    4.times do |i|
      timeslots << Timeslot.create!(
        conference_program: @conference_program,
        start_time: Date.tomorrow.to_datetime + 11.hours + (i * 15).minutes,
        max_volunteers: 2
      )
    end

    sign_in @volunteer
    # 45 minutes is >= the 30-min minimum but is not a multiple of 30
    assert_no_difference("VolunteerSignup.count") do
      post bulk_create_conference_volunteer_signups_url(@conference), params: {
        timeslot_id: timeslots.first.id,
        duration_minutes: 45
      }
    end
    assert_redirected_to conference_schedule_path(@conference)
    assert_match(/block/i, flash[:alert])
  end

  test "bulk create allows duration at conference minimum_shift_duration" do
    @conference.update!(minimum_shift_duration: 60)

    timeslots = []
    4.times do |i|
      timeslots << Timeslot.create!(
        conference_program: @conference_program,
        start_time: Date.tomorrow.to_datetime + 11.hours + (i * 15).minutes,
        max_volunteers: 2
      )
    end

    sign_in @volunteer
    assert_difference("VolunteerSignup.count", 4) do
      post bulk_create_conference_volunteer_signups_url(@conference), params: {
        timeslot_id: timeslots.first.id,
        duration_minutes: 60
      }
    end
    assert_redirected_to conference_volunteer_signups_path(@conference)
  end

  test "bulk create fails if any timeslot is full" do
    timeslots = []
    4.times do |i|
      timeslots << Timeslot.create!(
        conference_program: @conference_program,
        start_time: Date.tomorrow.to_datetime + 11.hours + (i * 15).minutes,
        max_volunteers: 1
      )
    end

    # Fill the third timeslot
    VolunteerSignup.create!(user: @volunteer2, timeslot: timeslots[2])

    sign_in @volunteer
    assert_no_difference("VolunteerSignup.count") do
      post bulk_create_conference_volunteer_signups_url(@conference), params: {
        timeslot_id: timeslots.first.id,
        end_time: timeslots.last.end_time.iso8601
      }
    end
    assert_redirected_to conference_schedule_path(@conference)
    assert_match(/full/, flash[:alert])
  end

  test "bulk create fails if user already signed up for any timeslot in range" do
    timeslots = []
    4.times do |i|
      timeslots << Timeslot.create!(
        conference_program: @conference_program,
        start_time: Date.tomorrow.to_datetime + 11.hours + (i * 15).minutes,
        max_volunteers: 2
      )
    end

    # User already signed up for the second timeslot
    VolunteerSignup.create!(user: @volunteer, timeslot: timeslots[1])

    sign_in @volunteer
    # Should only create 3 new signups (skipping the one already signed up for)
    assert_difference("VolunteerSignup.count", 3) do
      post bulk_create_conference_volunteer_signups_url(@conference), params: {
        timeslot_id: timeslots.first.id,
        end_time: timeslots.last.end_time.iso8601
      }
    end
  end

  # --- conflicting signups (#267): swap-or-keep instead of a green "0 shifts" ---

  def build_run(conference_program, hour, count: 4, max: 2)
    count.times.map do |i|
      Timeslot.create!(
        conference_program: conference_program,
        start_time: Date.tomorrow.to_datetime + hour.hours + (i * 15).minutes,
        max_volunteers: max
      )
    end
  end

  def conflict_setup
    other_cp = ConferenceProgram.create!(
      conference: @conference,
      program: Program.create!(name: "Front Desk", village: @village)
    )
    @my_slots = build_run(other_cp, 11, count: 2)             # Front Desk 11:00–11:30
    @my_signups = @my_slots.map { |slot| VolunteerSignup.create!(user: @volunteer, timeslot: slot) }
    @target_slots = build_run(@conference_program, 11)        # Test Program 11:00–12:00
  end

  test "bulk create with the whole window already claimed alerts instead of a green zero-shift notice" do
    slots = build_run(@conference_program, 11)
    slots.each { |slot| VolunteerSignup.create!(user: @volunteer, timeslot: slot) }

    sign_in @volunteer
    assert_no_difference("VolunteerSignup.count") do
      post bulk_create_conference_volunteer_signups_url(@conference), params: {
        timeslot_id: slots.first.id,
        duration_minutes: 60
      }
    end
    assert_nil flash[:notice]
    assert_match(/already signed up/i, flash[:alert])
  end

  test "bulk create with a cross-activity conflict redirects to swap confirmation instead of silently failing" do
    conflict_setup

    sign_in @volunteer
    assert_no_difference([ "VolunteerSignup.count", "Notification.count" ]) do
      post bulk_create_conference_volunteer_signups_url(@conference), params: {
        timeslot_id: @target_slots.first.id,
        duration_minutes: 60,
        return_to: "coverage",
        return_day: Date.tomorrow.iso8601
      }
    end
    assert_redirected_to conference_schedule_path(
      @conference, day: Date.tomorrow.iso8601,
      confirm_swap: @target_slots.first.id, swap_minutes: 60
    )
  end

  test "bulk create with replace_conflicts cancels the conflicting shifts and books the window" do
    conflict_setup

    sign_in @volunteer
    assert_difference("VolunteerSignup.count", 2) do  # -2 old, +4 new
      post bulk_create_conference_volunteer_signups_url(@conference), params: {
        timeslot_id: @target_slots.first.id,
        duration_minutes: 60,
        replace_conflicts: "1"
      }
    end
    assert_empty @volunteer.volunteer_signups.where(timeslot_id: @my_slots.map(&:id))
    assert_equal @target_slots.map(&:id).sort, @volunteer.volunteer_signups.pluck(:timeslot_id).sort
    assert_equal [ 0, 0 ], @my_slots.map { |slot| slot.reload.current_volunteers_count }
    assert_equal [ 1, 1, 1, 1 ], @target_slots.map { |slot| slot.reload.current_volunteers_count }
    assert_match(/4 shifts/, flash[:notice])
  end

  test "a failed swap keeps the existing shifts and sends no notification" do
    conflict_setup
    qualification = Qualification.create!(name: "Radio License", description: "FCC license", village: @village)
    ProgramQualification.create!(program: @program, qualification: qualification)

    sign_in @volunteer
    assert_no_difference([ "VolunteerSignup.count", "Notification.count" ]) do
      post bulk_create_conference_volunteer_signups_url(@conference), params: {
        timeslot_id: @target_slots.first.id,
        duration_minutes: 60,
        replace_conflicts: "1"
      }
    end
    assert_equal @my_slots.map(&:id).sort, @volunteer.volunteer_signups.pluck(:timeslot_id).sort,
                 "the conflicting shifts must survive a failed swap"
    assert_equal [ 1, 1 ], @my_slots.map { |slot| slot.reload.current_volunteers_count }
    assert_nil flash[:notice]
    assert_match(/qualification/i, flash[:alert])
  end

  test "bulk create surfaces validation failures instead of a green zero-shift notice" do
    qualification = Qualification.create!(name: "Radio License", description: "FCC license", village: @village)
    ProgramQualification.create!(program: @program, qualification: qualification)
    slots = build_run(@conference_program, 11)

    sign_in @volunteer
    assert_no_difference([ "VolunteerSignup.count", "Notification.count" ]) do
      post bulk_create_conference_volunteer_signups_url(@conference), params: {
        timeslot_id: slots.first.id,
        duration_minutes: 60
      }
    end
    assert_nil flash[:notice]
    assert_match(/qualification/i, flash[:alert])
  end

  test "bulk create requires authentication" do
    timeslots = []
    2.times do |i|
      timeslots << Timeslot.create!(
        conference_program: @conference_program,
        start_time: Date.tomorrow.to_datetime + 11.hours + (i * 15).minutes,
        max_volunteers: 2
      )
    end

    assert_no_difference("VolunteerSignup.count") do
      post bulk_create_conference_volunteer_signups_url(@conference), params: {
        timeslot_id: timeslots.first.id,
        end_time: timeslots.last.end_time.iso8601
      }
    end
    assert_redirected_to new_user_session_path
  end

  # Consolidated shifts tests
  test "index groups consecutive signups into shift groups" do
    # Create 4 consecutive timeslots (use 13:00 to avoid conflicts)
    timeslots = []
    4.times do |i|
      timeslots << Timeslot.create!(
        conference_program: @conference_program,
        start_time: Date.tomorrow.to_datetime + 13.hours + (i * 15).minutes,
        max_volunteers: 2
      )
    end

    # Sign up for all 4
    timeslots.each { |ts| VolunteerSignup.create!(user: @volunteer, timeslot: ts) }

    sign_in @volunteer
    get conference_volunteer_signups_url(@conference)

    assert_response :success
    # Should show consolidated time range (1:00 PM - 2:00 PM)
    assert_match(/1:00 PM.*2:00 PM/m, response.body)
    # Should show duration
    assert_match(/1 hr/, response.body)
    # Should show "4 timeslots in 1 shift"
    assert_match(/4 timeslots in 1 shift/, response.body)
  end

  test "index keeps non-consecutive signups as separate groups" do
    # Create timeslots with a gap (use 14:00 and 16:00 to avoid conflicts)
    ts1 = Timeslot.create!(
      conference_program: @conference_program,
      start_time: Date.tomorrow.to_datetime + 14.hours,
      max_volunteers: 2
    )
    ts2 = Timeslot.create!(
      conference_program: @conference_program,
      start_time: Date.tomorrow.to_datetime + 16.hours, # 2 hour gap
      max_volunteers: 2
    )

    VolunteerSignup.create!(user: @volunteer, timeslot: ts1)
    VolunteerSignup.create!(user: @volunteer, timeslot: ts2)

    sign_in @volunteer
    get conference_volunteer_signups_url(@conference)

    assert_response :success
    # Should show "2 timeslots in 2 shifts" (non-consecutive = separate)
    assert_match(/2 timeslots in 2 shifts/, response.body)
  end

  test "index keeps different programs as separate groups" do
    program2 = Program.create!(name: "Second Program", village: @village)
    cp2 = ConferenceProgram.create!(conference: @conference, program: program2)

    ts1 = Timeslot.create!(
      conference_program: @conference_program,
      start_time: Date.tomorrow.to_datetime + 15.hours,
      max_volunteers: 2
    )
    ts2 = Timeslot.create!(
      conference_program: cp2,
      start_time: Date.tomorrow.to_datetime + 15.hours + 15.minutes,
      max_volunteers: 2
    )

    VolunteerSignup.create!(user: @volunteer, timeslot: ts1)
    VolunteerSignup.create!(user: @volunteer, timeslot: ts2)

    sign_in @volunteer
    get conference_volunteer_signups_url(@conference)

    assert_response :success
    # Should show "2 timeslots in 2 shifts" (different programs = separate)
    assert_match(/2 timeslots in 2 shifts/, response.body)
    # Both program names should appear
    assert_match(/Test Program/, response.body)
    assert_match(/Second Program/, response.body)
  end

  test "bulk_destroy cancels all signups in a group" do
    timeslots = []
    4.times do |i|
      timeslots << Timeslot.create!(
        conference_program: @conference_program,
        start_time: Date.tomorrow.to_datetime + 12.hours + (i * 15).minutes,
        max_volunteers: 2
      )
    end

    signups = timeslots.map { |ts| VolunteerSignup.create!(user: @volunteer, timeslot: ts) }

    sign_in @volunteer
    assert_difference("VolunteerSignup.count", -4) do
      delete bulk_destroy_conference_volunteer_signups_url(@conference),
             params: { signup_ids: signups.map(&:id) }
    end

    assert_redirected_to conference_volunteer_signups_path(@conference)
    assert_match(/4 shifts/, flash[:notice])
  end

  test "bulk_destroy only cancels user's own signups" do
    ts = Timeslot.create!(
      conference_program: @conference_program,
      start_time: Date.tomorrow.to_datetime + 17.hours,
      max_volunteers: 2
    )

    own_signup = VolunteerSignup.create!(user: @volunteer, timeslot: ts)
    other_signup = VolunteerSignup.create!(user: @volunteer2, timeslot: @timeslot)

    sign_in @volunteer
    # Try to delete both - should only delete own
    assert_difference("VolunteerSignup.count", -1) do
      delete bulk_destroy_conference_volunteer_signups_url(@conference),
             params: { signup_ids: [ own_signup.id, other_signup.id ] }
    end

    # Other user's signup should still exist
    assert VolunteerSignup.exists?(other_signup.id)
  end
end
