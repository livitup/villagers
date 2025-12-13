class ProgramRolesController < ApplicationController
  before_action :set_program

  def create
    @user = User.find(params[:user_id])
    authorize @program, :update?

    @program_role = ProgramRole.find_or_create_by!(
      user: @user,
      program: @program,
      role_name: ProgramRole::PROGRAM_LEAD
    )

    redirect_to @program, notice: "Program lead assigned successfully."
  rescue ActiveRecord::RecordInvalid => e
    redirect_to @program, alert: "Could not assign program lead: #{e.message}"
  end

  def destroy
    @program_role = ProgramRole.find(params[:id])
    authorize @program, :update?

    @program_role.destroy
    redirect_to @program, notice: "Program lead removed successfully."
  end

  private

  def set_program
    @program = Program.find(params[:program_id])
  end
end
