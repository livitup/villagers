class StatesController < ApplicationController
  before_action :authenticate_user!

  def index
    country_code = params[:country]
    states = CS.states(country_code.to_sym)

    render json: states.map { |code, name| { code: code.to_s, name: name } }
  end
end
