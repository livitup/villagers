class QualificationRemovalsController < ApplicationController
  before_action :authenticate_user!
  before_action :set_conference
  before_action :set_village
  before_action :authorize_manage

  def index
    @global_qualifications = @village.qualifications.order(:name)
    @removals = @conference.qualification_removals.includes(:user, :qualification)
  end

  def create
    @user = User.find(params[:user_id])
    @qualification = Qualification.find(params[:qualification_id])

    QualificationRemoval.find_or_create_by!(
      user: @user,
      qualification: @qualification,
      conference: @conference
    )

    redirect_to conference_qualification_removals_path(@conference),
                notice: "Qualification removed for this conference."
  rescue ActiveRecord::RecordInvalid => e
    redirect_to conference_qualification_removals_path(@conference),
                alert: "Could not remove qualification: #{e.message}"
  end

  def destroy
    @removal = QualificationRemoval.find(params[:id])
    @removal.destroy
    redirect_to conference_qualification_removals_path(@conference),
                notice: "Qualification restored for this conference."
  end

  private

  def set_conference
    @conference = Conference.find(params[:conference_id])
  end

  def set_village
    @village = Village.first
    redirect_to setup_path if @village.nil?
  end

  def authorize_manage
    authorize @conference, :update?, policy_class: ConferencePolicy
  end
end
