class ProgramQualificationsController < ApplicationController
  before_action :set_program
  before_action :set_village

  def create
    @qualification = Qualification.find(params[:qualification_id])
    authorize @program, :update?, policy_class: ProgramPolicy

    @program_qualification = ProgramQualification.find_or_create_by!(
      program: @program,
      qualification: @qualification
    )

    redirect_to @program, notice: "Qualification requirement added successfully."
  rescue ActiveRecord::RecordInvalid => e
    redirect_to @program, alert: "Could not add qualification requirement: #{e.message}"
  end

  def destroy
    @program_qualification = ProgramQualification.find(params[:id])
    authorize @program, :update?, policy_class: ProgramPolicy

    @program_qualification.destroy
    redirect_to @program, notice: "Qualification requirement removed successfully."
  end

  private

  def set_program
    @program = Program.find(params[:program_id])
  end

  def set_village
    @village = Village.first
    redirect_to setup_path if @village.nil?
  end
end
