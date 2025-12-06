class QualificationRemoval < ApplicationRecord
  belongs_to :user
  belongs_to :qualification
  belongs_to :conference

  validates :user, uniqueness: { scope: [ :qualification_id, :conference_id ] }
end
