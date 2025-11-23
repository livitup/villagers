class RootController < ApplicationController
  def show
    if Village.setup_complete?
      # TODO: Show admin dashboard when implemented
      @village = Village.first
      render :show
    else
      redirect_to setup_path
    end
  end
end

