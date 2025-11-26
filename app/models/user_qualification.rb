class UserQualification < ApplicationRecord
  belongs_to :user
  belongs_to :qualification

  validates :user, uniqueness: { scope: :qualification_id }
end
