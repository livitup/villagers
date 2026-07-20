class VolunteerMailer < ApplicationMailer
  def shift_signup_confirmation(user:, signups:, conference:)
    @user = user
    @signups = signups
    @conference = conference
    @village_name = Village.first&.name || "Villagers"

    # Group signups by program for easier display
    @grouped_signups = group_signups_by_program(signups)

    # Calculate total duration
    @total_minutes = signups.size * 15
    @duration_display = format_duration(@total_minutes)

    mail(
      to: @user.email,
      subject: "[#{@village_name}] Shift Signup Confirmation - #{@conference.name}"
    )
  end

  def shift_reminder(user:, signups:, conference:)
    @user = user
    @signups = signups
    @conference = conference
    @village_name = Village.first&.name || "Villagers"

    # Group signups by program for easier display
    @grouped_signups = group_signups_by_program(signups)

    # Calculate total duration
    @total_minutes = signups.size * 15
    @duration_display = format_duration(@total_minutes)

    # Find the earliest shift time for the subject line
    earliest_shift = signups.min_by { |s| s.timeslot.start_time }
    @earliest_time = earliest_shift.timeslot.start_time

    mail(
      to: @user.email,
      subject: "[#{@village_name}] Shift Reminder - #{@conference.name}"
    )
  end

  def admin_signup_notification(admin:, volunteer:, signup:, conference:)
    @admin = admin
    @volunteer = volunteer
    @signup = signup
    @conference = conference
    @village_name = Village.first&.name || "Villagers"

    @timeslot = signup.timeslot
    @program = @timeslot.conference_program.program
    @fill_status = "#{@timeslot.current_volunteers_count}/#{@timeslot.max_volunteers}"

    mail(
      to: @admin.email,
      subject: "[#{@village_name}] New Volunteer Signup - #{@conference.name}"
    )
  end

  # Render every shift email in the conference's time zone (#252) so the
  # times volunteers read match the clock at the event. mail() renders the
  # templates synchronously, so wrapping it wraps the views too.
  def mail(**)
    return super unless @conference

    Time.use_zone(@conference.time_zone) { super }
  end

  private

  def group_signups_by_program(signups)
    signups.group_by { |s| s.timeslot.conference_program.program.name }.map do |program_name, program_signups|
      sorted = program_signups.sort_by { |s| s.timeslot.start_time }
      {
        program_name: program_name,
        start_time: sorted.first.timeslot.start_time,
        end_time: sorted.last.timeslot.start_time + 15.minutes,
        date: sorted.first.timeslot.start_time.to_date,
        slot_count: sorted.size
      }
    end
  end

  def format_duration(minutes)
    hours = minutes / 60
    mins = minutes % 60

    parts = []
    parts << "#{hours} hour#{'s' if hours != 1}" if hours > 0
    parts << "#{mins} minute#{'s' if mins != 1}" if mins > 0
    parts.join(" ")
  end
end
