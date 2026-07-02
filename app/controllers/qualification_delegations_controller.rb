# Conference managers grant/revoke a user's right to assign a specific
# qualification within this conference (issue #186).
class QualificationDelegationsController < ApplicationController
  before_action :authenticate_user!
  before_action :set_conference
  before_action :authorize_manage

  def index
    @delegations = @conference.qualification_assignment_delegations
                              .includes(:user, :qualification)
                              .order("qualifications.name")
    @qualifications = @conference.village.qualifications.order(:name)
    @users = User.order(:email)
  end

  def create
    user = User.find(params[:user_id])
    qualification = @conference.village.qualifications.find(params[:qualification_id])

    QualificationAssignmentDelegation.find_or_create_by!(
      user: user, qualification: qualification, conference: @conference
    )

    redirect_to conference_qualification_delegations_path(@conference),
                notice: "Delegated #{qualification.name} to #{user.email}."
  rescue ActiveRecord::RecordInvalid => e
    redirect_to conference_qualification_delegations_path(@conference),
                alert: "Could not delegate: #{e.message}"
  end

  def destroy
    delegation = @conference.qualification_assignment_delegations.find(params[:id])
    delegation.destroy
    redirect_to conference_qualification_delegations_path(@conference),
                notice: "Delegation removed."
  end

  private

  def set_conference
    @conference = Conference.find(params[:conference_id])
  end

  def authorize_manage
    authorize @conference, :update?, policy_class: ConferencePolicy
  end
end
