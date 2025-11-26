class TimeslotsController < ApplicationController
  before_action :authenticate_user!
  before_action :set_conference
  before_action :set_timeslot

  def update
    authorize @conference, :update?, policy_class: ConferencePolicy

    if @timeslot.update(timeslot_params)
      redirect_to conference_schedule_path(@conference), notice: "Timeslot updated successfully."
    else
      redirect_to conference_schedule_path(@conference), alert: @timeslot.errors.full_messages.join(", ")
    end
  end

  def add_volunteer
    authorize @conference, :update?, policy_class: ConferencePolicy

    user = User.find(params[:user_id])
    signup = VolunteerSignup.new(user: user, timeslot: @timeslot)

    if signup.save
      redirect_to conference_schedule_path(@conference), notice: "#{user.email} added to shift."
    else
      redirect_to conference_schedule_path(@conference), alert: signup.errors.full_messages.join(", ")
    end
  end

  def remove_volunteer
    authorize @conference, :update?, policy_class: ConferencePolicy

    signup = @timeslot.volunteer_signups.find_by!(user_id: params[:user_id])
    user_email = signup.user.email
    signup.destroy

    redirect_to conference_schedule_path(@conference), notice: "#{user_email} removed from shift."
  end

  private

  def set_conference
    @conference = Conference.find(params[:conference_id])
  end

  def set_timeslot
    @timeslot = @conference.timeslots.find(params[:id])
  end

  def timeslot_params
    params.require(:timeslot).permit(:max_volunteers)
  end
end
