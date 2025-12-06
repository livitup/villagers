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
  # Qualification associations
  has_many :user_qualifications, dependent: :destroy
  has_many :qualifications, through: :user_qualifications
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
