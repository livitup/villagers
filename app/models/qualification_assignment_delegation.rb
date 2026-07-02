# Grants one user (the delegate) the right to assign one specific global
# Qualification to volunteers within one Conference. Created by a conference
# manager; consulted by User#can_assign_qualification?.
class QualificationAssignmentDelegation < ApplicationRecord
  belongs_to :user
  belongs_to :qualification
  belongs_to :conference

  validates :user_id, uniqueness: { scope: [ :qualification_id, :conference_id ] }
end
