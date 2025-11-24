class Timeslot < ApplicationRecord
  belongs_to :conference_program
  has_one :conference, through: :conference_program
  has_one :program, through: :conference_program
  has_many :volunteer_signups, dependent: :destroy
  has_many :users, through: :volunteer_signups

  validates :conference_program, presence: true
  validates :start_time, presence: true
  validates :end_time, presence: true
  validates :max_volunteers, presence: true, numericality: { greater_than: 0 }
  validates :current_volunteers_count, presence: true, numericality: { greater_than_or_equal_to: 0 }
  validates :start_time, uniqueness: { scope: :conference_program_id }

  before_validation :set_end_time, if: :start_time?

  def available?
    current_volunteers_count < max_volunteers
  end

  def full?
    current_volunteers_count >= max_volunteers
  end

  private

  def set_end_time
    self.end_time = start_time + 15.minutes if start_time
  end
end
