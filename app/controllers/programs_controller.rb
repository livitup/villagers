class ProgramsController < ApplicationController
  before_action :set_program, only: [ :show, :edit, :update, :destroy ]
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

  private

  def set_program
    @program = Program.find(params[:id])
  end

  def set_village
    @village = Village.first
    redirect_to setup_path if @village.nil?
  end

  def program_params
    params.require(:program).permit(:name, :description)
  end
end
