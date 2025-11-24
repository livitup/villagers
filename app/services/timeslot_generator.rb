class TimeslotGenerator
  def initialize(conference_program)
    @conference_program = conference_program
    @conference = conference_program.conference
    @day_schedules = conference_program.day_schedules
  end

  def generate
    return if @day_schedules.empty?

    (@conference.start_date..@conference.end_date).each_with_index do |date, day_index|
      day_schedule = @day_schedules[day_index.to_s]
      next unless day_schedule && day_schedule["enabled"] == true

      generate_timeslots_for_day(date, day_schedule)
    end
  end

  private

  def generate_timeslots_for_day(date, day_schedule)
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

    return unless start_time_str && end_time_str

    start_time = Time.zone.parse("#{date} #{start_time_str}")
    end_time = Time.zone.parse("#{date} #{end_time_str}")

    current_time = start_time
    while current_time < end_time
      Timeslot.create!(
        conference_program: @conference_program,
        start_time: current_time,
        max_volunteers: 1
      )
      current_time += 15.minutes
    end
  end
end
