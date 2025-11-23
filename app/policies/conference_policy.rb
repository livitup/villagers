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

  class Scope < Scope
    def resolve
      # All users can see all conferences (for now)
      scope.all
    end
  end
end
