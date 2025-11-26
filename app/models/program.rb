class Program < ApplicationRecord
  belongs_to :village
  has_many :conference_programs, dependent: :destroy
  has_many :conferences, through: :conference_programs
  has_many :timeslots, through: :conference_programs
  # Qualification associations (only if ProgramQualification model exists)
  if defined?(ProgramQualification)
    has_many :program_qualifications, dependent: :destroy
    has_many :qualifications, through: :program_qualifications
  end

  validates :name, presence: true
  validates :name, uniqueness: { scope: :village_id, message: "must be unique within the village" }
end
