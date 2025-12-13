class Conference < ApplicationRecord
  belongs_to :village
  has_many :conference_roles, dependent: :destroy
  has_many :users, through: :conference_roles
  has_many :conference_programs, dependent: :destroy
  has_many :programs, through: :conference_programs
  has_many :timeslots, through: :conference_programs
  has_many :conference_qualifications, dependent: :destroy
  has_many :qualification_removals, dependent: :destroy

  validates :name, presence: true
  validates :start_date, presence: true
  validates :end_date, presence: true
  validate :end_date_after_start_date

  after_update :regenerate_timeslots_if_schedule_changed

  # Archive scopes
  scope :active, -> { where(archived_at: nil) }
  scope :archived, -> { where.not(archived_at: nil) }
  scope :past_unarchived, -> { where("end_date < ?", Date.today).where(archived_at: nil) }

  # Archive methods
  def archived?
    archived_at.present?
  end

  def archivable?
    end_date < Date.today
  end

  def archive!
    update!(archived_at: Time.current)
  end

  def unarchive!
    update!(archived_at: nil)
  end

  # Dashboard metrics
  def total_timeslots
    timeslots.count
  end

  def filled_timeslots
    timeslots.where("timeslots.current_volunteers_count >= timeslots.max_volunteers").count
  end

  def unfilled_timeslots
    timeslots.where("timeslots.current_volunteers_count < timeslots.max_volunteers").count
  end

  def volunteer_count
    User.joins(volunteer_signups: { timeslot: :conference_program })
        .where(conference_programs: { conference_id: id })
        .distinct
        .count
  end

  def programs_count
    conference_programs.count
  end

  def total_volunteer_hours
    VolunteerSignup.joins(timeslot: :conference_program)
                   .where(conference_programs: { conference_id: id })
                   .count * 0.25
  end

  def fill_rate
    return 0.0 if total_timeslots.zero?

    (filled_timeslots.to_f / total_timeslots * 100).round(1)
  end

  def recent_signups(limit = 5)
    VolunteerSignup.joins(timeslot: :conference_program)
                   .where(conference_programs: { conference_id: id })
                   .includes(user: [], timeslot: { conference_program: :program })
                   .order(created_at: :desc)
                   .limit(limit)
  end

  # Conference lead methods
  def conference_leads
    users.joins(:conference_roles)
         .where(conference_roles: { role_name: ConferenceRole::CONFERENCE_LEAD })
  end

  def primary_lead
    conference_roles.find_by(role_name: ConferenceRole::CONFERENCE_LEAD)&.user
  end

  def lead_display_name
    lead = primary_lead
    return "No lead assigned" unless lead

    name = lead.name.presence || lead.email
    additional_leads = conference_leads.count - 1
    additional_leads > 0 ? "#{name} +#{additional_leads}" : name
  end

  # Location display methods
  def display_location
    return "Not specified" if city.blank?

    if country == "US"
      state.present? ? "#{city}, #{state}" : city
    else
      country_name = ISO3166::Country.new(country)&.common_name || country
      "#{city}, #{country_name}"
    end
  end

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
