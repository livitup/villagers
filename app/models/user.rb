class User < ApplicationRecord
  # Include default devise modules. Others available are:
  # :lockable, :timeoutable, :trackable
  devise :database_authenticatable, :registerable,
         :recoverable, :rememberable, :validatable,
         :confirmable, :omniauthable, omniauth_providers: [ :villager_oauth ]

  # Devise handles email validation, but we keep format validation
  validates :email, format: { with: URI::MailTo::EMAIL_REGEXP }

  # `handle` is the one and only Display Name — whatever a volunteer wants to be
  # called (a name, a handle, a callsign). It's required, but we never block a
  # save on it: a blank handle falls back to the email address so every account
  # always has a Display Name. The self-service form nudges people to set a real
  # one (see the profile-completion prompt).
  before_validation :ensure_display_name
  validates :handle, presence: true

  # The single accessor every view should use to show a person. Defensive
  # `|| email` in case a record ever slips through with a blank handle.
  def display_name
    handle.presence || email
  end

  # Contact methods a lead could actually reach a volunteer through.
  CONTACT_FIELDS = %i[phone signal discord twitter].freeze

  def contact_method?
    CONTACT_FIELDS.any? { |field| public_send(field).present? }
  end

  # A handle counts as a real Display Name only once it differs from the email
  # fallback — otherwise the schedule still shows an email address.
  def display_name_set?
    handle.present? && !handle.to_s.casecmp?(email.to_s)
  end

  # "Complete" = a personalized Display Name plus at least one contact method.
  # Callsign is collected but never required (Villagers ships to non-ham
  # villages too).
  def profile_complete?
    display_name_set? && contact_method?
  end

  def needs_profile_completion?
    !profile_complete?
  end

  # Find or create a user from an OmniAuth callback.
  # Resolution order: existing identity (provider + uid) -> existing account
  # with the same email (linked) -> brand new just-in-time provisioned user.
  # OAuth users are auto-confirmed since the provider vouches for the email.
  def self.from_omniauth(auth)
    # Only match an existing identity by a present uid. A blank uid identifies
    # no one, so matching on it would collapse every blank-uid login onto the
    # first such account (callers should reject blank uids before this).
    if auth.uid.present?
      identity = find_by(provider: auth.provider, uid: auth.uid)
      return identity if identity
    end

    user = find_or_initialize_by(email: auth.info.email)
    user.provider = auth.provider
    user.uid = auth.uid
    # Prefill the Display Name from the provider's name on first sign-in only;
    # never overwrite a handle the volunteer has since chosen for themselves.
    user.handle = auth.info.name if user.handle.blank? && auth.info.name.present?
    user.password = Devise.friendly_token[0, 32] if user.encrypted_password.blank?
    user.skip_confirmation! unless user.confirmed?
    user.save
    user
  end

  # OAuth-backed accounts authenticate through the provider, so they don't need
  # a local password. Password-only accounts still require one (via :validatable).
  def password_required?
    return false if provider.present?

    super
  end

  # Skip email confirmation when email is disabled
  before_create :auto_confirm_if_email_disabled

  # Protect demo accounts from deletion
  before_destroy :prevent_demo_account_deletion

  def demo_protected?
    DemoMode.enabled? && DemoMode.protected_email?(email)
  end

  private def auto_confirm_if_email_disabled
    skip_confirmation! unless Village.email_enabled?
  end

  private def ensure_display_name
    self.handle = email if handle.blank?
  end

  private def prevent_demo_account_deletion
    if demo_protected?
      errors.add(:base, "Cannot delete protected demo accounts in demo mode")
      throw(:abort)
    end
  end

  # Role associations
  has_many :user_roles, dependent: :destroy
  has_many :roles, through: :user_roles
  has_many :conference_roles, dependent: :destroy
  has_many :program_roles, dependent: :destroy
  has_many :conference_program_roles, dependent: :destroy
  # Qualification associations
  has_many :user_qualifications, dependent: :destroy
  has_many :qualifications, through: :user_qualifications
  has_many :conference_user_qualifications, dependent: :destroy
  has_many :conference_qualifications, through: :conference_user_qualifications
  has_many :qualification_removals, dependent: :destroy
  has_many :qualification_assignment_delegations, dependent: :destroy
  # Volunteer signup associations
  has_many :volunteer_signups, dependent: :destroy
  has_many :timeslots, through: :volunteer_signups
  # Notification associations
  has_many :notifications, dependent: :destroy
  # API access
  has_many :api_tokens, dependent: :destroy

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

  def activity_lead?(conference_program)
    conference_program_roles.exists?(
      conference_program: conference_program,
      role_name: ConferenceProgramRole::ACTIVITY_LEAD
    )
  end

  def can_manage_conference_program?(conference_program)
    can_manage_conference?(conference_program.conference) || activity_lead?(conference_program)
  end

  # The activities (conference programs) this user leads within a conference.
  def led_conference_programs(conference)
    conference.conference_programs
              .joins(:conference_program_roles)
              .where(conference_program_roles: { user_id: id, role_name: ConferenceProgramRole::ACTIVITY_LEAD })
              .includes(:program)
              .order("programs.name")
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

  # Qualification-assignment delegation (issue #186). A conference manager can
  # always assign any qualification; a delegate may assign only the specific
  # qualifications delegated to them within that conference.
  def can_assign_qualification?(qualification, conference)
    return true if can_manage_conference?(conference)

    qualification_assignment_delegations.exists?(qualification: qualification, conference: conference)
  end

  # Qualifications this user is allowed to assign within the given conference.
  def assignable_qualifications(conference)
    return conference.village.qualifications.order(:name) if can_manage_conference?(conference)

    Qualification.where(
      id: qualification_assignment_delegations.where(conference: conference).select(:qualification_id)
    ).order(:name)
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

  # Notification methods
  def unread_notifications_count
    notifications.unread.count
  end

  def has_unread_notifications?
    unread_notifications_count > 0
  end

  def should_notify_by_email?
    notify_by_email? && Village.email_enabled?
  end

  def should_notify_in_app?
    notify_in_app?
  end
end
