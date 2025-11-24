class ProgramQualification < ApplicationRecord
  belongs_to :program
  belongs_to :qualification

  validates :program, uniqueness: { scope: :qualification_id }
end
