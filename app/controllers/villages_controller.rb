class VillagesController < ApplicationController
  before_action :set_village
  before_action :authorize_village

  def show
  end

  def edit
  end

  def update
    if @village.update(village_params)
      redirect_to village_path, notice: "Village settings updated successfully."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  private

  def set_village
    @village = Village.first
    redirect_to setup_path if @village.nil?
  end

  def authorize_village
    return if @village.nil?

    case action_name
    when "show"
      authorize @village
    when "edit", "update"
      authorize @village, :update?
    end
  end

  def village_params
    params.require(:village).permit(:name)
  end
end
