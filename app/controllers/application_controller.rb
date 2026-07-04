class ApplicationController < ActionController::Base
  include Pundit::Authorization

  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  allow_browser versions: :modern

  # Require authentication everywhere by default. Public pages opt out with
  # skip_before_action: the home page (RootController), the first-run setup
  # wizard (SetupController), the health endpoint (HealthController), and all
  # Devise controllers (sign in/up, password reset, confirmations, OAuth).
  before_action :authenticate_user!
  skip_before_action :authenticate_user!, if: :devise_controller?

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
    devise_parameter_sanitizer.permit(:sign_up, keys: [ :handle, :callsign, :phone, :twitter, :signal, :discord ])
    devise_parameter_sanitizer.permit(:account_update, keys: [ :handle, :callsign, :phone, :twitter, :signal, :discord, :notify_by_email, :notify_in_app ])
  end

  private

  def user_not_authorized
    flash[:alert] = "You are not authorized to perform this action."
    if user_signed_in?
      redirect_to(request.referer || root_path)
    else
      redirect_to new_user_session_path
    end
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
