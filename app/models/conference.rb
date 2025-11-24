class Conference < ApplicationRecord
  belongs_to :village
  has_many :conference_roles, dependent: :destroy
  has_many :users, through: :conference_roles
  has_many :conference_programs, dependent: :destroy
  has_many :programs, through: :conference_programs
  has_many :timeslots, through: :conference_programs

  validates :name, presence: true
  validates :start_date, presence: true
  validates :end_date, presence: true
  validate :end_date_after_start_date

  after_update :regenerate_timeslots_if_schedule_changed

  private

  def end_date_after_start_date
    return unless start_date && end_date

    errors.add(:end_date, "must be after start date") if end_date < start_date
  end

  def regenerate_timeslots_if_schedule_changed
    return unless saved_change_to_start_date? || saved_change_to_end_date? ||
                  saved_change_to_conference_hours_start? || saved_change_to_conference_hours_end?

    # Regenerate timeslots for all conference programs
    conference_programs.find_each do |cp|
      cp.timeslots.destroy_all
      TimeslotGenerator.new(cp).generate
    end
  end
end
