class SetupController < ApplicationController
  before_action :redirect_if_setup_complete

  def show
    @village = Village.new
    @user = User.new
  end

  def create
    @village = Village.new(village_params)
    @user = User.new(user_params)

    if @village.valid? && @user.valid?
      @village.setup_complete = true
      @village.save!
      @user.save!
      redirect_to root_path, notice: "Setup complete! Welcome to #{@village.name}."
    else
      render :show, status: :unprocessable_entity
    end
  end

  private

  def redirect_if_setup_complete
    redirect_to root_path if Village.setup_complete?
  end

  def village_params
    params.require(:village).permit(:name)
  end

  def user_params
    params.require(:user).permit(:email, :password, :password_confirmation)
  end
end
