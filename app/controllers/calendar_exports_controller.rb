require "icalendar"

class CalendarExportsController < ApplicationController
  before_action :authenticate_user!
  before_action :set_conference

  def show
    signups = current_user.volunteer_signups_for_conference(@conference)
                          .includes(timeslot: { conference_program: :program })

    calendar = Icalendar::Calendar.new
    calendar.prodid = "-//Villagers//Volunteer Shifts//EN"

    signups.each do |signup|
      timeslot = signup.timeslot
      program = timeslot.conference_program.program

      calendar.event do |event|
        event.dtstart = Icalendar::Values::DateTime.new(timeslot.start_time)
        event.dtend = Icalendar::Values::DateTime.new(timeslot.end_time)
        event.summary = "Volunteer: #{program.name}"
        event.description = "Volunteer shift for #{program.name} at #{@conference.name}"
        event.location = @conference.location
        event.uid = "volunteer-signup-#{signup.id}@villagers"
      end
    end

    send_data calendar.to_ical,
              filename: "volunteer_shifts_#{@conference.name.parameterize}_#{Date.current}.ics",
              type: "text/calendar"
  end

  private

  def set_conference
    @conference = Conference.find(params[:conference_id])
  end
end
