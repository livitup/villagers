class SetupController < ApplicationController
  # The first-run wizard runs before any user account exists, so it must be
  # reachable without authentication.
  skip_before_action :authenticate_user!
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

      # Assign village admin role to the setup user
      village_admin_role = Role.find_or_create_by!(name: Role::VILLAGE_ADMIN)
      UserRole.find_or_create_by!(user: @user, role: village_admin_role)

      # Sign in the user after setup
      sign_in(@user)

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
    params.require(:village).permit(:name, :email_enabled, :mailgun_api_key, :mailgun_domain, :mailgun_region)
  end

  def user_params
    params.require(:user).permit(:email, :password, :password_confirmation, :handle, :callsign, :phone, :twitter, :signal, :discord)
  end
end
