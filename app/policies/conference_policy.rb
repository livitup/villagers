class ConferencePolicy < ApplicationPolicy
  def index?
    user&.volunteer?
  end

  def show?
    user&.volunteer?
  end

  def create?
    user&.village_admin?
  end

  def update?
    user&.can_manage_conference?(record)
  end

  def destroy?
    user&.village_admin?
  end

  def archive?
    # Village admins can archive any conference
    # Conference leads can archive their assigned conferences
    return true if user&.village_admin?

    # Handle when record is a class (for bulk_archive collection action)
    return user&.village_admin? unless record.is_a?(Conference)

    user&.can_manage_conference?(record)
  end

  class Scope < ApplicationPolicy::Scope
    def resolve
      # All users can see all conferences (for now)
      scope.all
    end
  end
end
