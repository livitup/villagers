class VolunteerSignup < ApplicationRecord
  belongs_to :user
  belongs_to :timeslot
  has_one :conference, through: :timeslot
  has_one :program, through: :timeslot

  # Admin placements may exceed a slot's needed count (#242 settled decision:
  # admins can place anyone anywhere, including over-covering). Volunteer
  # self-signup never sets this, so the fullness check still protects it.
  # Overlap and qualification validations apply to everyone regardless.
  attr_accessor :allow_over_capacity

  validates :user, presence: true
  validates :timeslot, presence: true, uniqueness: { scope: :user_id }
  validate :no_overlapping_signups
  validate :timeslot_not_full
  validate :user_has_required_qualifications

  after_create :increment_timeslot_count
  after_destroy :decrement_timeslot_count

  # The user's signups that clash in time with a requested window (#267):
  # anything overlapping [start_time, end_time) except signups on the window's
  # own slots — those are extensions of an existing shift, not conflicts.
  # Ordered by start time for display. Shared by the bulk-claim path and the
  # swap-confirmation modal so both always agree on what conflicts.
  def self.conflicting_for(user, conference_program, start_time, end_time)
    window_slot_ids = conference_program.timeslots
                                        .where("start_time >= ? AND start_time < ?", start_time, end_time)
                                        .select(:id)
    user.volunteer_signups
        .joins(:timeslot)
        .where("timeslots.start_time < ? AND timeslots.end_time > ?", end_time, start_time)
        .where.not(timeslot_id: window_slot_ids)
        .includes(timeslot: { conference_program: :program })
        .order("timeslots.start_time")
  end

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
    return if allow_over_capacity

    if timeslot.current_volunteers_count >= timeslot.max_volunteers
      errors.add(:base, "This timeslot is full")
    end
  end

  def user_has_required_qualifications
    return unless user && timeslot

    program = timeslot.program
    conference = timeslot.conference_program.conference
    required_qualifications = program.qualifications

    missing_qualifications = required_qualifications.reject do |qual|
      user.effective_qualification_for_conference?(qual, conference)
    end

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
