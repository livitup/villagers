class VolunteerSignupsController < ApplicationController
  before_action :authenticate_user!
  before_action :set_timeslot, only: [ :create ]
  before_action :set_volunteer_signup, only: [ :destroy ]

  def index
    @conference = Conference.find(params[:conference_id])
    authorize @conference, :show?, policy_class: ConferencePolicy
    @my_signups = current_user.volunteer_signups.joins(:timeslot)
                              .where(timeslots: { conference_program_id: @conference.conference_programs.pluck(:id) })
                              .includes(timeslot: [ :conference_program, :program ])
                              .order("timeslots.start_time")
  end

  def create
    @volunteer_signup = VolunteerSignup.new(user: current_user, timeslot: @timeslot)

    if @volunteer_signup.save
      redirect_to conference_volunteer_signups_path(@timeslot.conference), notice: "Successfully signed up for this shift."
    else
      redirect_to conference_volunteer_signups_path(@timeslot.conference), alert: @volunteer_signup.errors.full_messages.join(", ")
    end
  end

  def destroy
    @conference = @volunteer_signup.timeslot.conference
    @volunteer_signup.destroy
    redirect_to conference_volunteer_signups_path(@conference), notice: "Signup cancelled successfully."
  end

  private

  def set_timeslot
    @timeslot = Timeslot.find(params[:timeslot_id])
  end

  def set_volunteer_signup
    @volunteer_signup = current_user.volunteer_signups.find(params[:id])
  end
end
