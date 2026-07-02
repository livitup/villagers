class ConferenceProgramRole < ApplicationRecord
  belongs_to :user
  belongs_to :conference_program

  validates :user_id, uniqueness: { scope: [ :conference_program_id, :role_name ] }
  validates :role_name, inclusion: { in: %w[activity_lead] }

  # Role names
  ACTIVITY_LEAD = "activity_lead"
end
