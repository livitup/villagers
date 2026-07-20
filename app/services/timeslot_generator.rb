class TimeslotGenerator
  def initialize(conference_program, previous_time_zone: nil)
    @conference_program = conference_program
    @conference = conference_program.conference
    @day_schedules = conference_program.day_schedules
    # The zone the EXISTING timeslots' wall clock was written in. Callers pass
    # this when the conference's zone just changed (#252); defaults to the
    # current zone, which makes reconciliation instant-equivalent otherwise.
    @previous_time_zone = previous_time_zone.presence || @conference.time_zone
  end

  # Reconciles the conference program's timeslots against its current schedule.
  #
  # A slot's identity is its calendar date + wall-clock time in the
  # conference's zone (#226/#252), not its absolute instant. So:
  # - identity unchanged, instant unchanged -> untouched;
  # - identity unchanged, instant moved (the conference's time zone changed)
  #   -> the slot slides in place, keeping its id and volunteer signups, with
  #   no notifications;
  # - identity gone (day dropped, hours narrowed) -> destroyed, and its
  #   volunteers are notified their shift was cancelled (issue #225);
  # - new identity -> created.
  def generate
    # use_zone so cancellation notifications (and any other formatting done
    # during reconciliation) render times in the conference's zone.
    Time.use_zone(@conference.tz) do
      reconcile(compute_desired_slots)
    end
  end

  private

  # { [iso_date, "HH:MM"] => Time } for every 15-minute tick the current
  # schedule calls for, with instants computed in the conference's zone.
  def compute_desired_slots
    return {} if @day_schedules.empty?

    Time.use_zone(@conference.tz) do
      desired = {}
      (@conference.start_date..@conference.end_date).each do |date|
        # day_schedules are keyed by calendar date (#226); dates outside the
        # conference range are retained in the config but generate nothing.
        day_schedule = @day_schedules[date.iso8601]
        next unless day_schedule && day_schedule["enabled"] == true

        start_times_for_day(date, day_schedule).each do |time|
          desired[[ date.iso8601, time.strftime("%H:%M") ]] = time
        end
      end
      desired
    end
  end

  def start_times_for_day(date, day_schedule)
    start_time_str = day_schedule["start"]
    end_time_str = day_schedule["end"]

    # Use day-specific times if provided, otherwise use conference defaults
    if start_time_str.nil? && @conference.conference_hours_start
      # conference_hours_start is stored as a time column; format it as HH:MM
      start_time_str = @conference.conference_hours_start.utc.strftime("%H:%M")
    end
    if end_time_str.nil? && @conference.conference_hours_end
      end_time_str = @conference.conference_hours_end.utc.strftime("%H:%M")
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

  def reconcile(desired)
    remaining = desired.dup
    previous_zone = ActiveSupport::TimeZone[@previous_time_zone] || @conference.tz

    @conference_program.timeslots.includes(volunteer_signups: :user).find_each do |timeslot|
      # The slot's identity, read back in the zone its wall clock was written in.
      local = timeslot.start_time.in_time_zone(previous_zone)
      key = [ local.to_date.iso8601, local.strftime("%H:%M") ]
      new_start = remaining.delete(key)

      if new_start.nil?
        notify_affected_volunteers(timeslot)
        timeslot.destroy!
      elsif timeslot.start_time.to_i != new_start.to_i
        # Same wall-clock identity, new instant (zone change): slide in place.
        # update_columns skips callbacks/validations — transient uniqueness
        # collisions mid-slide are fine because the mapping is one-to-one.
        timeslot.update_columns(start_time: new_start, end_time: new_start + 15.minutes)
      end
    end

    remaining.each_value do |start_time|
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
