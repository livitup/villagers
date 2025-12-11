class ConferencesController < ApplicationController
  before_action :set_conference, only: [ :show, :edit, :update, :destroy, :archive, :unarchive ]
  before_action :set_village

  def index
    @show_archived = params[:show_archived] == "true"
    @conferences = if @show_archived
                     Conference.order(start_date: :desc)
    else
                     Conference.active.order(start_date: :desc)
    end
  end

  def show
    authorize @conference, :show?, policy_class: ConferencePolicy
    @conference_roles = @conference.conference_roles.includes(:user)
  end

  def new
    @conference = Conference.new
    @conference.village = @village
    @users = User.all.order(:email)
    authorize @conference, :create?, policy_class: ConferencePolicy
  end

  def create
    @conference = Conference.new(conference_params)
    @conference.village = @village
    @users = User.all.order(:email)
    authorize @conference, :create?, policy_class: ConferencePolicy

    if @conference.save
      # Assign conference lead if provided
      if params[:conference_lead_id].present?
        ConferenceRole.create!(
          user_id: params[:conference_lead_id],
          conference: @conference,
          role_name: ConferenceRole::CONFERENCE_LEAD
        )
      end

      redirect_to @conference, notice: "Conference was successfully created."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
    authorize @conference, :update?, policy_class: ConferencePolicy
    @users = User.all.order(:email)
    @current_lead = @conference.conference_roles.find_by(role_name: ConferenceRole::CONFERENCE_LEAD)&.user
  end

  def update
    authorize @conference, :update?, policy_class: ConferencePolicy
    if @conference.update(conference_params)
      # Update conference lead if provided
      if params[:conference_lead_id].present?
        # Remove existing lead
        @conference.conference_roles.where(role_name: ConferenceRole::CONFERENCE_LEAD).destroy_all
        # Add new lead
        ConferenceRole.create!(
          user_id: params[:conference_lead_id],
          conference: @conference,
          role_name: ConferenceRole::CONFERENCE_LEAD
        )
      end

      redirect_to @conference, notice: "Conference was successfully updated."
    else
      @users = User.all.order(:email)
      @current_lead = @conference.conference_roles.find_by(role_name: ConferenceRole::CONFERENCE_LEAD)&.user
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    authorize @conference, :destroy?, policy_class: ConferencePolicy
    @conference.destroy
    redirect_to conferences_path, notice: "Conference was successfully deleted."
  end

  def archive
    authorize @conference, :archive?, policy_class: ConferencePolicy

    if @conference.archivable?
      @conference.archive!
      redirect_to @conference, notice: "Conference was successfully archived."
    else
      redirect_to @conference, alert: "Cannot archive a conference that hasn't ended yet."
    end
  end

  def unarchive
    authorize @conference, :archive?, policy_class: ConferencePolicy
    @conference.unarchive!
    redirect_to @conference, notice: "Conference was successfully unarchived."
  end

  def bulk_archive
    authorize Conference, :archive?, policy_class: ConferencePolicy
    conference_ids = params[:conference_ids] || []

    archived_count = 0
    Conference.where(id: conference_ids).find_each do |conference|
      if conference.archivable? && policy(conference).archive?
        conference.archive!
        archived_count += 1
      end
    end

    if request.format.json?
      render json: { success: true, archived_count: archived_count }
    else
      redirect_to conferences_path, notice: "#{archived_count} conference(s) archived."
    end
  end

  private

  def set_conference
    @conference = Conference.find(params[:id])
  end

  def set_village
    @village = Village.first
    redirect_to setup_path if @village.nil?
  end

  def conference_params
    params.require(:conference).permit(:name, :country, :state, :city, :start_date, :end_date, :conference_hours_start, :conference_hours_end)
  end
end
