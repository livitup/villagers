class ConferenceProgram < ApplicationRecord
  belongs_to :conference
  belongs_to :program
  has_many :timeslots, dependent: :destroy

  validates :conference, presence: true
  validates :program, presence: true, uniqueness: { scope: :conference_id }
  validates :max_volunteers, presence: true, numericality: { greater_than: 0 }

  after_create :generate_timeslots
  after_update :regenerate_timeslots_if_needed

  def day_schedules
    super || {}
  end

  private

  def generate_timeslots
    TimeslotGenerator.new(self).generate
  end

  def regenerate_timeslots_if_needed
    return unless saved_change_to_day_schedules? || saved_change_to_public_description?

    # Only regenerate if day_schedules changed
    return unless saved_change_to_day_schedules?

    timeslots.destroy_all
    generate_timeslots
  end
end
