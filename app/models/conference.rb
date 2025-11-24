class Conference < ApplicationRecord
  belongs_to :village
  has_many :conference_roles, dependent: :destroy
  has_many :users, through: :conference_roles
  has_many :conference_programs, dependent: :destroy
  has_many :programs, through: :conference_programs

  validates :name, presence: true
  validates :start_date, presence: true
  validates :end_date, presence: true
  validate :end_date_after_start_date

  private

  def end_date_after_start_date
    return unless start_date && end_date

    errors.add(:end_date, "must be after start date") if end_date < start_date
  end
end
