class UsersController < ApplicationController
  before_action :set_user, only: [ :show, :edit, :update ]
  before_action :set_village

  def index
    authorize User, :index?, policy_class: UserPolicy
    @users = User.order(:email)
  end

  def show
    authorize @user, :show?, policy_class: UserPolicy
    @qualifications = Qualification.where(village: @village).order(:name)
  end

  def edit
    authorize @user, :edit?, policy_class: UserPolicy
  end

  def update
    authorize @user, :update?, policy_class: UserPolicy

    if @user.update(user_params)
      redirect_to managed_user_path(@user), notice: "User was successfully updated."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  private

  def set_user
    @user = User.find(params[:id])
  end

  def set_village
    @village = Village.first
    redirect_to setup_path if @village.nil?
  end

  def user_params
    # Only allow profile fields - no email or password changes
    params.require(:user).permit(:name, :handle, :phone, :twitter, :signal, :discord)
  end
end
