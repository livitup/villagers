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
end
