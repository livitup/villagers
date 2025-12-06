class LeaderboardController < ApplicationController
  before_action :authenticate_user!
  before_action :set_conference, only: [ :conference ]

  def index
    @top_volunteers = User.top_volunteers(25)
  end

  def conference
    @top_volunteers = User.top_volunteers_for_conference(@conference, 25)
  end

  private

  def set_conference
    @conference = Conference.find(params[:conference_id])
  end
end
