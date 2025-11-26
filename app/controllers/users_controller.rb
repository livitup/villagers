class UsersController < ApplicationController
  before_action :set_user, only: [ :show ]
  before_action :set_village

  def index
    authorize User, :index?, policy_class: UserPolicy
    @users = User.order(:email)
  end

  def show
    authorize @user, :show?, policy_class: UserPolicy
    @qualifications = Qualification.where(village: @village).order(:name)
  end

  private

  def set_user
    @user = User.find(params[:id])
  end

  def set_village
    @village = Village.first
    redirect_to setup_path if @village.nil?
  end
end
