class UserPolicy < ApplicationPolicy
  def index?
    user&.village_admin?
  end

  # Conference managers and activity leads may read volunteer profiles (#262):
  # the staffing timeline links to them, and these roles already receive the
  # same contact data through the reports. Editing stays village-admin-only.
  def show?
    return true if user&.village_admin?
    return false if user.nil?

    ConferenceRole.exists?(user: user) ||
      ConferenceProgramRole.exists?(user: user, role_name: ConferenceProgramRole::ACTIVITY_LEAD)
  end

  def edit?
    user&.village_admin?
  end

  def update?
    user&.village_admin?
  end

  def grant_qualification?
    user&.village_admin?
  end

  def manage_village_admin_role?
    user&.village_admin?
  end

  class Scope < ApplicationPolicy::Scope
    def resolve
      if user&.village_admin?
        scope.all
      else
        scope.none
      end
    end
  end
end
