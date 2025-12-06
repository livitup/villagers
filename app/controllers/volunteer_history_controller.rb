class VolunteerHistoryController < ApplicationController
  before_action :authenticate_user!
  before_action :set_conference, only: [ :show ]

  def index
    @user = current_user
    @conferences = @user.conferences_participated.order(start_date: :desc)
  end

  def show
    @user = current_user
    @signups = @user.volunteer_signups_for_conference(@conference)
                    .includes(timeslot: { conference_program: :program })
                    .order("timeslots.start_time")
  end

  private

  def set_conference
    @conference = Conference.find(params[:id])
  end
end
