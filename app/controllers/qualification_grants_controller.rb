# Assign / unassign global qualifications to users within a conference.
# Open to conference managers (all qualifications) and to delegates (only the
# qualifications delegated to them for this conference) — see issue #186.
class QualificationGrantsController < ApplicationController
  before_action :authenticate_user!
  before_action :set_conference
  before_action :authorize_any_assignment, only: [ :index ]

  def index
    @assignable_qualifications = current_user.assignable_qualifications(@conference)
    @users = User.order(:email)
  end

  def create
    qualification = find_assignable_qualification!(params[:qualification_id])
    user = User.find(params[:user_id])

    UserQualification.find_or_create_by!(user: user, qualification: qualification)
    redirect_to conference_qualification_grants_path(@conference),
                notice: "Granted #{qualification.name} to #{user.email}."
  rescue ActiveRecord::RecordInvalid => e
    redirect_to conference_qualification_grants_path(@conference),
                alert: "Could not grant qualification: #{e.message}"
  end

  def destroy
    user_qualification = UserQualification.find(params[:id])
    # Authorize against the specific qualification being revoked.
    find_assignable_qualification!(user_qualification.qualification_id)

    user_qualification.destroy
    redirect_to conference_qualification_grants_path(@conference),
                notice: "Revoked #{user_qualification.qualification.name} from #{user_qualification.user.email}."
  end

  private

  def set_conference
    @conference = Conference.find(params[:conference_id])
  end

  # The user must be able to assign at least one qualification to view the page.
  def authorize_any_assignment
    raise Pundit::NotAuthorizedError unless current_user.assignable_qualifications(@conference).exists?
  end

  # Load a qualification the current user is permitted to assign in this
  # conference, or raise NotAuthorized (rescued into a redirect + flash).
  def find_assignable_qualification!(qualification_id)
    qualification = Qualification.find(qualification_id)
    unless current_user.can_assign_qualification?(qualification, @conference)
      raise Pundit::NotAuthorizedError
    end

    qualification
  end
end
