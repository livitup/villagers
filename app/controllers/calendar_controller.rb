class CalendarController < ApplicationController
  before_action :authenticate_user!
  before_action :set_conference

  def show
    authorize @conference, :show?, policy_class: ConferencePolicy

    # Get all timeslots for this conference, grouped by day
    @timeslots_by_day = {}
    (@conference.start_date..@conference.end_date).each_with_index do |date, day_index|
      @timeslots_by_day[date] = []
    end

    @conference.timeslots.includes(:conference_program, :program, :volunteer_signups).each do |timeslot|
      day = timeslot.start_time.to_date
      @timeslots_by_day[day] ||= []
      @timeslots_by_day[day] << timeslot
    end

    # Sort timeslots within each day by start_time
    @timeslots_by_day.each do |_date, timeslots|
      timeslots.sort_by!(&:start_time)
    end

    # Get user's signups for highlighting
    @user_signups = current_user.volunteer_signups.where(timeslot_id: @conference.timeslots.pluck(:id)).pluck(:timeslot_id).to_set

    # Get programs for filtering
    @programs = @conference.programs.order(:name)
    @selected_program_id = params[:program_id]&.to_i
  end

  private

  def set_conference
    @conference = Conference.find(params[:conference_id])
  end
end
