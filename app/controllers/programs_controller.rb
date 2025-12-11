class ProgramsController < ApplicationController
  before_action :set_program, only: [ :show, :edit, :update, :destroy, :affected_conferences, :bulk_update_capacity ]
  before_action :set_village

  def index
    @programs = Program.where(village: @village).order(:name)
  end

  def show
    authorize @program, :show?, policy_class: ProgramPolicy
    @qualifications = Qualification.where(village: @village).order(:name)
  end

  def new
    @program = Program.new
    @program.village = @village
    authorize @program, :create?, policy_class: ProgramPolicy
  end

  def create
    @program = Program.new(program_params)
    @program.village = @village
    authorize @program, :create?, policy_class: ProgramPolicy

    if @program.save
      redirect_to @program, notice: "Program was successfully created."
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
      redirect_to @program, notice: "Program was successfully updated."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    authorize @program, :destroy?, policy_class: ProgramPolicy
    @program.destroy
    redirect_to programs_path, notice: "Program was successfully deleted."
  end

  # Returns JSON with affected open conferences for the bulk update modal
  def affected_conferences
    authorize @program, :update?, policy_class: ProgramPolicy
    new_max_volunteers = params[:new_max_volunteers].to_i

    conferences_data = @program.conference_programs
      .joins(:conference)
      .where("conferences.end_date >= ?", Date.today)
      .includes(:conference, :timeslots)
      .map do |cp|
        timeslots_count = cp.timeslots.count
        over_capacity_count = cp.timeslots.where("current_volunteers_count > ?", new_max_volunteers).count

        {
          conference_program_id: cp.id,
          conference_name: cp.conference.name,
          current_max_volunteers: cp.effective_max_volunteers,
          timeslots_count: timeslots_count,
          over_capacity_count: over_capacity_count,
          has_override: cp.max_volunteers.present?
        }
      end

    render json: { conferences: conferences_data }
  end

  # Enqueues bulk update jobs for selected conference programs
  def bulk_update_capacity
    authorize @program, :update?, policy_class: ProgramPolicy
    new_max_volunteers = params[:new_max_volunteers].to_i
    conference_program_ids = params[:conference_program_ids] || []

    conference_program_ids.each do |cp_id|
      UpdateTimeslotCapacityJob.perform_later(cp_id.to_i, new_max_volunteers)
    end

    render json: {
      success: true,
      message: "Updating #{conference_program_ids.count} conference(s) in the background."
    }
  end

  private

  def set_program
    @program = Program.find(params[:id])
  end

  def set_village
    @village = Village.first
    redirect_to setup_path if @village.nil?
  end

  def program_params
    params.require(:program).permit(:name, :description, :max_volunteers)
  end
end
