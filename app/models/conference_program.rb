class ConferenceProgram < ApplicationRecord
  # Force JSON (de)serialization for day_schedules so it behaves identically on
  # every supported adapter. PostgreSQL and MySQL expose a native `json` type, but
  # MariaDB reports the column as `longtext`, where ActiveRecord would otherwise
  # store a hash via #to_s (invalid JSON) and trip MariaDB's implicit json_valid()
  # CHECK constraint. Declaring the type here is a no-op on Postgres/MySQL and the
  # fix for MariaDB.
  attribute :day_schedules, :json

  belongs_to :conference
  belongs_to :program
  has_many :timeslots, dependent: :destroy
  has_many :conference_program_roles, dependent: :destroy
  has_many :activity_leads,
           -> { where(conference_program_roles: { role_name: ConferenceProgramRole::ACTIVITY_LEAD }) },
           through: :conference_program_roles, source: :user

  validates :conference, presence: true
  validates :program, presence: true, uniqueness: { scope: :conference_id }
  validates :max_volunteers, numericality: { greater_than: 0 }, allow_nil: true

  # Returns the effective max_volunteers (override or program default)
  def effective_max_volunteers
    max_volunteers || program&.max_volunteers || 1
  end

  after_create :generate_timeslots
  after_update :regenerate_timeslots_if_needed
  before_validation :normalize_day_schedule_keys

  def day_schedules
    super || {}
  end

  private

  # day_schedules are keyed by calendar date (ISO "YYYY-MM-DD") so a
  # conference date change never re-assigns a day's hours to a different
  # date (#226). Legacy positional index keys ("0", "1", ...) — old stored
  # data, old callers, seeds — are converted here using the conference's
  # current start_date at write time.
  def normalize_day_schedule_keys
    return if day_schedules.blank? || conference.nil?

    normalized = day_schedules.transform_keys do |key|
      key.to_s.match?(/\A\d+\z/) ? (conference.start_date + key.to_i).iso8601 : key.to_s
    end
    self.day_schedules = normalized if normalized != day_schedules
  end

  def generate_timeslots
    TimeslotGenerator.new(self).generate
  end

  def regenerate_timeslots_if_needed
    return unless saved_change_to_day_schedules?

    # Reconcile timeslots against the new schedule. TimeslotGenerator preserves
    # timeslots (and their volunteer signups) whose start time is unchanged, so
    # editing the schedule no longer silently drops existing signups (issue #225).
    generate_timeslots
  end
end
