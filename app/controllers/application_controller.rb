class ApplicationController < ActionController::Base
  include Pundit::Authorization

  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  allow_browser versions: :modern

  # Make Devise helpers available in all views
  before_action :configure_permitted_parameters, if: :devise_controller?

  # Pundit authorization
  rescue_from Pundit::NotAuthorizedError, with: :user_not_authorized

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
end
