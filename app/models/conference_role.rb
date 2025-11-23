class ConferenceRole < ApplicationRecord
  belongs_to :user
  belongs_to :conference

  validates :user_id, uniqueness: { scope: [ :conference_id, :role_name ] }
  validates :role_name, inclusion: { in: %w[conference_lead conference_admin] }

  # Role names
  CONFERENCE_LEAD = "conference_lead"
  CONFERENCE_ADMIN = "conference_admin"
end
