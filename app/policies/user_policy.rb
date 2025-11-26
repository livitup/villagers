class UserPolicy < ApplicationPolicy
  def index?
    user&.village_admin?
  end

  def show?
    user&.village_admin?
  end

  def grant_qualification?
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
