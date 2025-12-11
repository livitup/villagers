class ProgramPolicy < ApplicationPolicy
  def index?
    user&.volunteer?
  end

  def show?
    user&.volunteer?
  end

  def create?
    return true if user&.village_admin?

    # Handle case when checking permission against the Program class (not an instance)
    return false unless record.is_a?(Program)

    # Conference leads/admins can create conference-specific programs for their conference
    if record.conference_specific?
      user&.can_manage_conference?(record.conference)
    else
      false
    end
  end

  def update?
    return true if user&.village_admin?

    # Conference leads/admins can update conference-specific programs for their conference
    if record.conference_specific?
      user&.can_manage_conference?(record.conference)
    else
      false
    end
  end

  def destroy?
    return true if user&.village_admin?

    # Conference leads/admins can destroy conference-specific programs for their conference
    if record.conference_specific?
      user&.can_manage_conference?(record.conference)
    else
      false
    end
  end

  class Scope < ApplicationPolicy::Scope
    def resolve
      scope.all
    end
  end
end
