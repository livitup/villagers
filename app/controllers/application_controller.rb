class ApplicationController < ActionController::Base
  include Pundit::Authorization

  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  allow_browser versions: :modern

  # Make Devise helpers available in all views
  before_action :configure_permitted_parameters, if: :devise_controller?
  before_action :load_past_unarchived_conferences

  # Pundit authorization
  rescue_from Pundit::NotAuthorizedError, with: :user_not_authorized

  # Tell Pundit to use current_user for authorization
  def pundit_user
    current_user
  end

  protected

  def configure_permitted_parameters
    devise_parameter_sanitizer.permit(:sign_up, keys: [ :name, :handle, :phone, :twitter, :signal, :discord ])
    devise_parameter_sanitizer.permit(:account_update, keys: [ :name, :handle, :phone, :twitter, :signal, :discord ])
  end

  private

  def user_not_authorized
    flash[:alert] = "You are not authorized to perform this action."
    redirect_to(request.referer || root_path)
  end

  def load_past_unarchived_conferences
    # Only show archive prompt on the root page to avoid interrupting other workflows
    return unless user_signed_in?
    return if request.xhr? || request.format.json?
    return unless controller_name == "root" && action_name == "show"

    # Only load for users who can archive conferences
    if current_user.village_admin?
      @past_unarchived_conferences = Conference.past_unarchived.order(end_date: :desc)
    else
      # For conference leads/admins, show only their assigned past conferences
      managed_conference_ids = current_user.conference_roles.pluck(:conference_id)
      @past_unarchived_conferences = Conference.past_unarchived
                                               .where(id: managed_conference_ids)
                                               .order(end_date: :desc)
    end
  end
end
