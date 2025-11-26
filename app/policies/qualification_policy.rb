class QualificationPolicy < ApplicationPolicy
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
    user&.village_admin?
  end

  def destroy?
    user&.village_admin?
  end

  class Scope < ApplicationPolicy::Scope
    def resolve
      scope.all
    end
  end
end
