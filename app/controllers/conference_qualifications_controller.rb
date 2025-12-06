class ConferenceQualificationsController < ApplicationController
  before_action :authenticate_user!
  before_action :set_conference
  before_action :set_qualification, only: [ :show, :edit, :update, :destroy ]
  before_action :authorize_manage

  def index
    @qualifications = @conference.conference_qualifications.order(:name)
  end

  def show
  end

  def new
    @qualification = @conference.conference_qualifications.new
  end

  def create
    @qualification = @conference.conference_qualifications.new(qualification_params)

    if @qualification.save
      redirect_to conference_conference_qualification_path(@conference, @qualification),
                  notice: "Qualification was successfully created."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    if @qualification.update(qualification_params)
      redirect_to conference_conference_qualification_path(@conference, @qualification),
                  notice: "Qualification was successfully updated."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @qualification.destroy
    redirect_to conference_conference_qualifications_path(@conference),
                notice: "Qualification was successfully deleted."
  end

  private

  def set_conference
    @conference = Conference.find(params[:conference_id])
  end

  def set_qualification
    @qualification = @conference.conference_qualifications.find(params[:id])
  end

  def authorize_manage
    authorize @conference, :update?, policy_class: ConferencePolicy
  end

  def qualification_params
    params.require(:conference_qualification).permit(:name, :description)
  end
end
