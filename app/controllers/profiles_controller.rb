class ProfilesController < ApplicationController
  before_action :authenticate_user!

  # Volunteers edit their own Display Name, callsign, and contact methods here.
  # A plain `current_user.update` (unlike Devise's registration update) does not
  # require the current password — essential for OAuth users, who have a random
  # password they never see. Email and password changes still go through Devise.
  def update
    if current_user.update(profile_params)
      redirect_to edit_user_registration_path, notice: "Profile updated."
    else
      redirect_to edit_user_registration_path,
                  alert: current_user.errors.full_messages.to_sentence.presence || "Failed to update profile."
    end
  end

  private

  def profile_params
    params.require(:user).permit(:handle, :callsign, :phone, :twitter, :signal, :discord)
  end
end
