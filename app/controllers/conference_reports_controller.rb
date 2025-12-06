require "csv"

class ConferenceReportsController < ApplicationController
  before_action :authenticate_user!
  before_action :set_conference
  before_action :authorize_reports

  def index
    @programs = @conference.programs
  end

  def shift_assignments
    @timeslots = filtered_timeslots
                 .includes(:volunteer_signups, :users, conference_program: :program)
                 .where("timeslots.current_volunteers_count > 0")
                 .order(:start_time)

    respond_to do |format|
      format.html
      format.csv { send_shift_assignments_csv }
    end
  end

  def unmanned_shifts
    @timeslots = filtered_timeslots
                 .includes(conference_program: :program)
                 .where("timeslots.current_volunteers_count < timeslots.max_volunteers")
                 .order(:start_time)

    respond_to do |format|
      format.html
      format.csv { send_unmanned_shifts_csv }
    end
  end

  private

  def set_conference
    @conference = Conference.find(params[:conference_id])
  end

  def authorize_reports
    authorize @conference, :update?, policy_class: ConferencePolicy
  end

  def filtered_timeslots
    timeslots = @conference.timeslots

    if params[:program_id].present?
      timeslots = timeslots.joins(:conference_program)
                           .where(conference_programs: { program_id: params[:program_id] })
    end

    if params[:date].present?
      date = Date.parse(params[:date])
      timeslots = timeslots.where("DATE(timeslots.start_time) = ?", date)
    end

    timeslots
  end

  def send_shift_assignments_csv
    csv_data = CSV.generate(headers: true) do |csv|
      csv << [ "Date", "Time", "Program", "Volunteer Name", "Volunteer Email" ]

      @timeslots.each do |timeslot|
        timeslot.users.each do |user|
          csv << [
            timeslot.start_time.strftime("%Y-%m-%d"),
            "#{timeslot.start_time.strftime('%H:%M')} - #{timeslot.end_time.strftime('%H:%M')}",
            timeslot.conference_program.program.name,
            user.name || "N/A",
            user.email
          ]
        end
      end
    end

    send_data csv_data,
              filename: "shift_assignments_#{@conference.name.parameterize}_#{Date.current}.csv",
              type: "text/csv"
  end

  def send_unmanned_shifts_csv
    csv_data = CSV.generate(headers: true) do |csv|
      csv << [ "Date", "Time", "Program", "Current Volunteers", "Max Volunteers", "Spots Available" ]

      @timeslots.each do |timeslot|
        csv << [
          timeslot.start_time.strftime("%Y-%m-%d"),
          "#{timeslot.start_time.strftime('%H:%M')} - #{timeslot.end_time.strftime('%H:%M')}",
          timeslot.conference_program.program.name,
          timeslot.current_volunteers_count,
          timeslot.max_volunteers,
          timeslot.max_volunteers - timeslot.current_volunteers_count
        ]
      end
    end

    send_data csv_data,
              filename: "unmanned_shifts_#{@conference.name.parameterize}_#{Date.current}.csv",
              type: "text/csv"
  end
end
