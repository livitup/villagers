class ApplicationController < ActionController::Base
  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  allow_browser versions: :modern

  # Make Devise helpers available in all views
  before_action :configure_permitted_parameters, if: :devise_controller?

  protected

  def configure_permitted_parameters
    devise_parameter_sanitizer.permit(:sign_up, keys: [ :name, :handle, :phone, :twitter, :signal, :discord ])
    devise_parameter_sanitizer.permit(:account_update, keys: [ :name, :handle, :phone, :twitter, :signal, :discord ])
  end
end
