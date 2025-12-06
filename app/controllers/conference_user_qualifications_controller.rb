class ConferenceUserQualificationsController < ApplicationController
  before_action :authenticate_user!
  before_action :set_conference
  before_action :authorize_manage

  def create
    @qualification = @conference.conference_qualifications.find(params[:conference_qualification_id])
    @user = User.find(params[:user_id])

    ConferenceUserQualification.find_or_create_by!(
      user: @user,
      conference_qualification: @qualification
    )

    redirect_to conference_conference_qualification_path(@conference, @qualification),
                notice: "Qualification granted successfully."
  rescue ActiveRecord::RecordInvalid => e
    redirect_to conference_conference_qualification_path(@conference, @qualification),
                alert: "Could not grant qualification: #{e.message}"
  end

  def destroy
    @user_qualification = ConferenceUserQualification.find(params[:id])
    @qualification = @user_qualification.conference_qualification

    @user_qualification.destroy
    redirect_to conference_conference_qualification_path(@conference, @qualification),
                notice: "Qualification revoked successfully."
  end

  private

  def set_conference
    @conference = Conference.find(params[:conference_id])
  end

  def authorize_manage
    authorize @conference, :update?, policy_class: ConferencePolicy
  end
end
