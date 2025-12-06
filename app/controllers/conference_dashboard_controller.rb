class ConferenceDashboardController < ApplicationController
  before_action :authenticate_user!
  before_action :set_conference

  def show
    authorize @conference, :update?, policy_class: ConferencePolicy
    @recent_signups = @conference.recent_signups(5)
  end

  private

  def set_conference
    @conference = Conference.find(params[:conference_id])
  end
end
