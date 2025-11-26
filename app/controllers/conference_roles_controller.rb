class ConferenceRolesController < ApplicationController
  before_action :set_conference

  def create
    @user = User.find(params[:user_id])
    role_name = params[:role_name] || ConferenceRole::CONFERENCE_ADMIN

    # Only conference leads and village admins can delegate admins
    # Only village admins can change leads
    if role_name == ConferenceRole::CONFERENCE_LEAD
      authorize @conference, :update?, policy_class: ConferencePolicy
    else
      authorize @conference, :update?, policy_class: ConferencePolicy
    end

    @conference_role = ConferenceRole.find_or_create_by!(
      user: @user,
      conference: @conference,
      role_name: role_name
    )

    redirect_to @conference, notice: "Role assigned successfully."
  rescue ActiveRecord::RecordInvalid => e
    redirect_to @conference, alert: "Could not assign role: #{e.message}"
  end

  def destroy
    @conference_role = ConferenceRole.find(params[:id])
    authorize @conference, :update?, policy_class: ConferencePolicy

    # Prevent removing the last conference lead (village admin can override)
    if @conference_role.role_name == ConferenceRole::CONFERENCE_LEAD &&
       @conference.conference_roles.where(role_name: ConferenceRole::CONFERENCE_LEAD).count <= 1 &&
       !current_user.village_admin?
      redirect_to @conference, alert: "Cannot remove the last conference lead."
      return
    end

    @conference_role.destroy
    redirect_to @conference, notice: "Role removed successfully."
  end

  private

  def set_conference
    @conference = Conference.find(params[:conference_id])
  end
end
