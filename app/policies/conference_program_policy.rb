class ConferenceProgramPolicy < ApplicationPolicy
  def index?
    user&.can_manage_conference?(record.conference)
  end

  def show?
    user&.can_manage_conference_program?(record)
  end

  def create?
    user&.can_manage_conference?(record.conference)
  end

  # Permits conference managers AND the activity lead of this specific program.
  # This is the chokepoint for managing an activity's timeslots (add/remove
  # volunteers, edit capacity) and for appointing/removing its activity leads.
  def update?
    user&.can_manage_conference_program?(record)
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
