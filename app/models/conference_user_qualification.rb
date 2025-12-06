class ConferenceUserQualification < ApplicationRecord
  belongs_to :user
  belongs_to :conference_qualification

  validates :user, uniqueness: { scope: :conference_qualification_id }
end
