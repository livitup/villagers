class ProgramRole < ApplicationRecord
  belongs_to :user
  belongs_to :program

  validates :user_id, uniqueness: { scope: [ :program_id, :role_name ] }
  validates :role_name, inclusion: { in: %w[program_lead] }

  # Role names
  PROGRAM_LEAD = "program_lead"
end
