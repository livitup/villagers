class CustomProgramsController < ApplicationController
  before_action :set_conference
  before_action :set_program, only: [ :edit, :update, :destroy ]

  def new
    @program = Program.new(village: @conference.village, conference: @conference)
    authorize @program, :create?, policy_class: ProgramPolicy
  end

  def create
    @program = Program.new(program_params)
    @program.village = @conference.village
    @program.conference = @conference
    authorize @program, :create?, policy_class: ProgramPolicy

    if @program.save
      redirect_to conference_conference_programs_path(@conference),
                  notice: "Program '#{@program.name}' was created. You can now enable it for scheduling."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
    authorize @program, :update?, policy_class: ProgramPolicy
  end

  def update
    authorize @program, :update?, policy_class: ProgramPolicy

    if @program.update(program_params)
      redirect_to conference_conference_programs_path(@conference),
                  notice: "Program was successfully updated."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    authorize @program, :destroy?, policy_class: ProgramPolicy
    @program.destroy
    redirect_to conference_conference_programs_path(@conference),
                notice: "Program was successfully deleted."
  end

  private

  def set_conference
    @conference = Conference.find(params[:conference_id])
    authorize @conference, :update?, policy_class: ConferencePolicy
  end

  def set_program
    @program = Program.find(params[:id])
    # Ensure program belongs to this conference
    unless @program.conference_id == @conference.id
      redirect_to conference_conference_programs_path(@conference),
                  alert: "Program not found."
    end
  end

  def program_params
    params.require(:program).permit(:name, :description, :max_volunteers)
  end
end
