class TimeslotGenerator
  def initialize(conference_program)
    @conference_program = conference_program
    @conference = conference_program.conference
    @day_schedules = conference_program.day_schedules
  end

  # Reconciles the conference program's timeslots against its current schedule.
  #
  # Rather than destroying every timeslot and recreating from scratch (which
  # would cascade-delete all volunteer signups), this keeps timeslots whose
  # start time still exists in the schedule, creates any newly-scheduled slots,
  # and removes only the slots that no longer belong. Volunteers signed up for a
  # removed slot are notified that their shift was cancelled (issue #225).
  def generate
    desired_start_times = compute_desired_start_times

    remove_obsolete_timeslots(desired_start_times)
    create_missing_timeslots(desired_start_times)
  end

  private

  # Every start time the current schedule calls for, as Time objects.
  def compute_desired_start_times
    return [] if @day_schedules.empty?

    start_times = []
    (@conference.start_date..@conference.end_date).each_with_index do |date, day_index|
      day_schedule = @day_schedules[day_index.to_s]
      next unless day_schedule && day_schedule["enabled"] == true

      start_times.concat(start_times_for_day(date, day_schedule))
    end
    start_times
  end

  def start_times_for_day(date, day_schedule)
    start_time_str = day_schedule["start"]
    end_time_str = day_schedule["end"]

    # Use day-specific times if provided, otherwise use conference defaults
    if start_time_str.nil? && @conference.conference_hours_start
      # conference_hours_start is stored as a time, format it as HH:MM
      time_obj = @conference.conference_hours_start
      # For time columns, use strftime with UTC to avoid timezone issues
      start_time_str = time_obj.utc.strftime("%H:%M")
    end
    if end_time_str.nil? && @conference.conference_hours_end
      time_obj = @conference.conference_hours_end
      end_time_str = time_obj.utc.strftime("%H:%M")
    end

    return [] unless start_time_str && end_time_str

    start_time = Time.zone.parse("#{date} #{start_time_str}")
    end_time = Time.zone.parse("#{date} #{end_time_str}")

    times = []
    current_time = start_time
    while current_time < end_time
      times << current_time
      current_time += 15.minutes
    end
    times
  end

  # Remove timeslots that no longer belong to the schedule. Compare by epoch
  # seconds so persisted (DB-loaded) and freshly-parsed times match regardless
  # of adapter or timezone representation.
  def remove_obsolete_timeslots(desired_start_times)
    desired_keys = desired_start_times.map(&:to_i).to_set

    @conference_program.timeslots.includes(volunteer_signups: :user).find_each do |timeslot|
      next if desired_keys.include?(timeslot.start_time.to_i)

      notify_affected_volunteers(timeslot)
      timeslot.destroy!
    end
  end

  def create_missing_timeslots(desired_start_times)
    existing_keys = @conference_program.timeslots.pluck(:start_time).map(&:to_i).to_set

    desired_start_times.each do |start_time|
      next if existing_keys.include?(start_time.to_i)

      Timeslot.create!(
        conference_program: @conference_program,
        start_time: start_time,
        max_volunteers: @conference_program.effective_max_volunteers
      )
    end
  end

  def notify_affected_volunteers(timeslot)
    timeslot.volunteer_signups.each do |signup|
      NotificationService.notify_shift_cancelled(user: signup.user, timeslot: timeslot)
    end
  end
end
