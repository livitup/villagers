# Grant/revoke the village admin role from the managed-user page (#263).
# Only village admins may use either action; revoking is refused when it
# would leave the village with no admin at all.
class VillageAdminRolesController < ApplicationController
  before_action :set_user

  def create
    authorize @user, :manage_village_admin_role?, policy_class: UserPolicy

    role = Role.find_or_create_by!(name: Role::VILLAGE_ADMIN)
    UserRole.find_or_create_by!(user: @user, role: role)

    redirect_to managed_user_path(@user), notice: "#{@user.display_name} is now a village admin."
  end

  def destroy
    authorize @user, :manage_village_admin_role?, policy_class: UserPolicy

    user_role = @user.user_roles.joins(:role).find_by(roles: { name: Role::VILLAGE_ADMIN })
    unless user_role
      redirect_to managed_user_path(@user), notice: "#{@user.display_name} is not a village admin."
      return
    end

    if last_village_admin_role?(user_role)
      redirect_to managed_user_path(@user),
                  alert: "Cannot revoke the last village admin — grant the role to someone else first."
      return
    end

    user_role.destroy!
    redirect_to managed_user_path(@user), notice: "Village admin role revoked from #{@user.display_name}."
  end

  private

  def set_user
    @user = User.find(params[:managed_user_id])
  end

  def last_village_admin_role?(user_role)
    UserRole.joins(:role).where(roles: { name: Role::VILLAGE_ADMIN }).where.not(id: user_role.id).none?
  end
end
