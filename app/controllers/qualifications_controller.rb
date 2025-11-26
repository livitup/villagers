class QualificationsController < ApplicationController
  before_action :set_qualification, only: [ :show, :edit, :update, :destroy ]
  before_action :set_village

  def index
    @qualifications = Qualification.where(village: @village).order(:name)
  end

  def show
    authorize @qualification, :show?, policy_class: QualificationPolicy
  end

  def new
    @qualification = Qualification.new
    @qualification.village = @village
    authorize @qualification, :create?, policy_class: QualificationPolicy
  end

  def create
    @qualification = Qualification.new(qualification_params)
    @qualification.village = @village
    authorize @qualification, :create?, policy_class: QualificationPolicy

    if @qualification.save
      redirect_to @qualification, notice: "Qualification was successfully created."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
    authorize @qualification, :update?, policy_class: QualificationPolicy
  end

  def update
    authorize @qualification, :update?, policy_class: QualificationPolicy
    if @qualification.update(qualification_params)
      redirect_to @qualification, notice: "Qualification was successfully updated."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    authorize @qualification, :destroy?, policy_class: QualificationPolicy
    @qualification.destroy
    redirect_to qualifications_path, notice: "Qualification was successfully deleted."
  end

  private

  def set_qualification
    @qualification = Qualification.find(params[:id])
  end

  def set_village
    @village = Village.first
    redirect_to setup_path if @village.nil?
  end

  def qualification_params
    params.require(:qualification).permit(:name, :description)
  end
end
