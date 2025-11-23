class VillagePolicy < ApplicationPolicy
  def show?
    user&.volunteer?
  end

  def update?
    user&.village_admin?
  end

  def edit?
    update?
  end

  class Scope < ApplicationPolicy::Scope
    def resolve
      scope.all
    end
  end
end
