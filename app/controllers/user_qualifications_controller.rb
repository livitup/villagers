class UserQualificationsController < ApplicationController
  before_action :set_user
  before_action :set_village

  def create
    @qualification = Qualification.find(params[:qualification_id])
    authorize @qualification, :update?, policy_class: QualificationPolicy

    @user_qualification = UserQualification.find_or_create_by!(
      user: @user,
      qualification: @qualification
    )

    redirect_to @user, notice: "Qualification granted successfully."
  rescue ActiveRecord::RecordInvalid => e
    redirect_to @user, alert: "Could not grant qualification: #{e.message}"
  end

  def destroy
    @user_qualification = UserQualification.find(params[:id])
    @qualification = @user_qualification.qualification
    authorize @qualification, :update?, policy_class: QualificationPolicy

    @user_qualification.destroy
    redirect_to @user, notice: "Qualification removed successfully."
  end

  private

  def set_user
    @user = User.find(params[:user_id])
  end

  def set_village
    @village = Village.first
    redirect_to setup_path if @village.nil?
  end
end
