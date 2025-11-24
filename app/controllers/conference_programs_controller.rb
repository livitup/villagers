class ConferenceProgramsController < ApplicationController
  before_action :set_conference
  before_action :set_conference_program, only: [ :show, :edit, :update, :destroy ]

  def index
    @conference_programs = @conference.conference_programs.includes(:program).order("programs.name")
    @available_programs = Program.where(village: @conference.village)
                                  .where.not(id: @conference.programs.pluck(:id))
                                  .order(:name)
  end

  def show
    authorize @conference_program, :show?, policy_class: ConferenceProgramPolicy
  end

  def new
    @conference_program = @conference.conference_programs.build
    @conference_program.program_id = params[:program_id] if params[:program_id].present?
    @available_programs = Program.where(village: @conference.village)
                                 .where.not(id: @conference.programs.pluck(:id))
                                 .order(:name)
    authorize @conference_program, :create?, policy_class: ConferenceProgramPolicy
  end

  def create
    @conference_program = @conference.conference_programs.build(conference_program_params)
    authorize @conference_program, :create?, policy_class: ConferenceProgramPolicy

    process_day_schedules

    if @conference_program.save
      redirect_to conference_conference_programs_path(@conference), notice: "Program was successfully enabled for this conference."
    else
      @available_programs = Program.where(village: @conference.village)
                                   .where.not(id: @conference.programs.pluck(:id))
                                   .order(:name)
      render :new, status: :unprocessable_entity
    end
  end

  def edit
    authorize @conference_program, :update?, policy_class: ConferenceProgramPolicy
  end

  def update
    authorize @conference_program, :update?, policy_class: ConferenceProgramPolicy
    @conference_program.assign_attributes(conference_program_params)
    process_day_schedules

    if @conference_program.save
      redirect_to conference_conference_programs_path(@conference), notice: "Conference program was successfully updated."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    authorize @conference_program, :destroy?, policy_class: ConferenceProgramPolicy
    @conference_program.destroy
    redirect_to conference_conference_programs_path(@conference), notice: "Program was successfully disabled for this conference."
  end

  private

  def set_conference
    @conference = Conference.find(params[:conference_id])
    authorize @conference, :update?, policy_class: ConferencePolicy
  end

  def set_conference_program
    @conference_program = @conference.conference_programs.find(params[:id])
  end

  def conference_program_params
    params.require(:conference_program).permit(:program_id, :public_description)
  end

  def process_day_schedules
    day_schedules_param = params[:conference_program][:day_schedules] if params[:conference_program]
    return unless day_schedules_param

    processed_schedules = {}
    day_schedules_param.each do |day_index, schedule|
      next unless schedule["enabled"] == "1" || schedule["enabled"] == true

      processed_schedules[day_index] = {
        "enabled" => true,
        "start" => schedule["start"],
        "end" => schedule["end"]
      }
    end
    @conference_program.day_schedules = processed_schedules
  end
end
