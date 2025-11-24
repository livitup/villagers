class ConferenceProgramPolicy < ApplicationPolicy
  def index?
    user&.can_manage_conference?(record.conference)
  end

  def show?
    user&.can_manage_conference?(record.conference)
  end

  def create?
    user&.can_manage_conference?(record.conference)
  end

  def update?
    user&.can_manage_conference?(record.conference)
  end

  def destroy?
    user&.can_manage_conference?(record.conference)
  end

  class Scope < ApplicationPolicy::Scope
    def resolve
      scope.all
    end
  end
end
