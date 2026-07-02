class ConferenceProgramRolesController < ApplicationController
  before_action :authenticate_user!
  before_action :set_conference
  before_action :set_conference_program

  def create
    @user = User.find(params[:user_id])
    authorize @conference_program, :update?, policy_class: ConferenceProgramPolicy

    ConferenceProgramRole.find_or_create_by!(
      user: @user,
      conference_program: @conference_program,
      role_name: ConferenceProgramRole::ACTIVITY_LEAD
    )

    redirect_to conference_conference_program_path(@conference, @conference_program),
                notice: "Activity lead assigned successfully."
  rescue ActiveRecord::RecordInvalid => e
    redirect_to conference_conference_program_path(@conference, @conference_program),
                alert: "Could not assign activity lead: #{e.message}"
  end

  def destroy
    @conference_program_role = @conference_program.conference_program_roles.find(params[:id])
    authorize @conference_program, :update?, policy_class: ConferenceProgramPolicy

    @conference_program_role.destroy
    redirect_to conference_conference_program_path(@conference, @conference_program),
                notice: "Activity lead removed successfully."
  end

  private

  def set_conference
    @conference = Conference.find(params[:conference_id])
  end

  def set_conference_program
    @conference_program = @conference.conference_programs.find(params[:conference_program_id])
  end
end
