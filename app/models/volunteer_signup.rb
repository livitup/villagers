class VolunteerSignup < ApplicationRecord
  belongs_to :user
  belongs_to :timeslot
  has_one :conference, through: :timeslot
  has_one :program, through: :timeslot

  validates :user, presence: true
  validates :timeslot, presence: true, uniqueness: { scope: :user_id }
  validate :no_overlapping_signups
  validate :timeslot_not_full
  validate :user_has_required_qualifications

  after_create :increment_timeslot_count
  after_destroy :decrement_timeslot_count

  private

  def no_overlapping_signups
    return unless user && timeslot

    overlapping = user.volunteer_signups.joins(:timeslot).where(
      "timeslots.start_time < ? AND timeslots.end_time > ?",
      timeslot.end_time,
      timeslot.start_time
    ).where.not(timeslot_id: timeslot_id)

    if overlapping.exists?
      errors.add(:base, "You are already signed up for an overlapping timeslot")
    end
  end

  def timeslot_not_full
    return unless timeslot

    if timeslot.current_volunteers_count >= timeslot.max_volunteers
      errors.add(:base, "This timeslot is full")
    end
  end

  def user_has_required_qualifications
    return unless user && timeslot

    program = timeslot.program
    required_qualifications = program.qualifications

    missing_qualifications = required_qualifications.reject { |qual| user.has_qualification?(qual) }

    if missing_qualifications.any?
      errors.add(:base, "You do not have the required qualifications: #{missing_qualifications.map(&:name).join(', ')}")
    end
  end

  def increment_timeslot_count
    timeslot.increment!(:current_volunteers_count)
  end

  def decrement_timeslot_count
    timeslot.decrement!(:current_volunteers_count)
  end
end
