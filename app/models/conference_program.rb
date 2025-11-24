class ConferenceProgram < ApplicationRecord
  belongs_to :conference
  belongs_to :program

  validates :conference, presence: true
  validates :program, presence: true, uniqueness: { scope: :conference_id }

  def day_schedules
    super || {}
  end
end
