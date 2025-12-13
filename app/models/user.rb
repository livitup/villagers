class User < ApplicationRecord
  # Include default devise modules. Others available are:
  # :confirmable, :lockable, :timeoutable, :trackable and :omniauthable
  devise :database_authenticatable, :registerable,
         :recoverable, :rememberable, :validatable

  # Devise handles email validation, but we keep format validation
  validates :email, format: { with: URI::MailTo::EMAIL_REGEXP }

  # Role associations
  has_many :user_roles, dependent: :destroy
  has_many :roles, through: :user_roles
  has_many :conference_roles, dependent: :destroy
  has_many :program_roles, dependent: :destroy
  # Qualification associations
  has_many :user_qualifications, dependent: :destroy
  has_many :qualifications, through: :user_qualifications
  has_many :conference_user_qualifications, dependent: :destroy
  has_many :conference_qualifications, through: :conference_user_qualifications
  has_many :qualification_removals, dependent: :destroy
  # Volunteer signup associations
  has_many :volunteer_signups, dependent: :destroy
  has_many :timeslots, through: :volunteer_signups

  # Role checking methods
  def village_admin?
    roles.exists?(name: Role::VILLAGE_ADMIN)
  end

  def conference_lead?(conference)
    conference_roles.exists?(conference: conference, role_name: ConferenceRole::CONFERENCE_LEAD)
  end

  def conference_admin?(conference)
    conference_roles.exists?(conference: conference, role_name: ConferenceRole::CONFERENCE_ADMIN)
  end

  def conference_lead_or_admin?(conference)
    conference_lead?(conference) || conference_admin?(conference)
  end

  def can_manage_conference?(conference)
    village_admin? || conference_lead_or_admin?(conference)
  end

  def program_lead?(program)
    program_roles.exists?(program: program, role_name: ProgramRole::PROGRAM_LEAD)
  end

  def can_manage_program?(program)
    return true if village_admin?
    return true if program_lead?(program)
    # Conference leads/admins can manage their conference-specific programs
    if program.conference_specific?
      return conference_lead_or_admin?(program.conference)
    end
    false
  end

  def led_programs
    Program.joins(:program_roles).where(program_roles: { user_id: id, role_name: ProgramRole::PROGRAM_LEAD })
  end

  def volunteer?
    # Any registered user is a volunteer
    persisted?
  end

  # Methods for displaying permissions
  def global_roles
    roles.pluck(:name)
  end

  def conference_lead_conferences
    conference_roles.where(role_name: ConferenceRole::CONFERENCE_LEAD).includes(:conference).map(&:conference)
  end

  def conference_admin_conferences
    conference_roles.where(role_name: ConferenceRole::CONFERENCE_ADMIN).includes(:conference).map(&:conference)
  end

  # Qualification checking methods
  def has_qualification?(qualification)
    user_qualifications.exists?(qualification: qualification)
  end

  def has_qualification_for_program?(program)
    program.qualifications.all? { |qual| has_qualification?(qual) }
  end

  # Conference-specific qualification methods
  def has_conference_qualification?(conference_qualification)
    conference_user_qualifications.exists?(conference_qualification: conference_qualification)
  end

  def qualification_removed_for_conference?(qualification, conference)
    qualification_removals.exists?(qualification: qualification, conference: conference)
  end

  def effective_qualification_for_conference?(qualification, conference)
    return false unless has_qualification?(qualification)
    !qualification_removed_for_conference?(qualification, conference)
  end

  # Volunteer statistics methods
  def total_shifts
    volunteer_signups.count
  end

  def total_volunteer_hours
    # Each timeslot is 15 minutes = 0.25 hours
    total_shifts * 0.25
  end

  def conferences_participated
    Conference.joins(conference_programs: { timeslots: :volunteer_signups })
              .where(volunteer_signups: { user_id: id })
              .distinct
  end

  def conferences_participated_count
    conferences_participated.count
  end

  def shifts_for_conference(conference)
    volunteer_signups.joins(timeslot: :conference_program)
                     .where(conference_programs: { conference_id: conference.id })
                     .count
  end

  def hours_for_conference(conference)
    shifts_for_conference(conference) * 0.25
  end

  def volunteer_signups_for_conference(conference)
    volunteer_signups.joins(timeslot: :conference_program)
                     .where(conference_programs: { conference_id: conference.id })
                     .includes(timeslot: { conference_program: [ :conference, :program ] })
  end

  # Class methods for leaderboard
  def self.top_volunteers(limit = 10)
    select("users.*, COUNT(volunteer_signups.id) as shifts_count")
      .joins(:volunteer_signups)
      .group("users.id")
      .order("shifts_count DESC")
      .limit(limit)
  end

  def self.top_volunteers_for_conference(conference, limit = 10)
    select("users.*, COUNT(volunteer_signups.id) as shifts_count")
      .joins(volunteer_signups: { timeslot: :conference_program })
      .where(conference_programs: { conference_id: conference.id })
      .group("users.id")
      .order("shifts_count DESC")
      .limit(limit)
  end
end
