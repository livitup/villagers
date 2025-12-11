class Program < ApplicationRecord
  belongs_to :village
  belongs_to :conference, optional: true
  has_many :conference_programs, dependent: :destroy
  has_many :enabled_conferences, through: :conference_programs, source: :conference
  has_many :timeslots, through: :conference_programs
  has_many :program_qualifications, dependent: :destroy
  has_many :qualifications, through: :program_qualifications

  validates :name, presence: true
  validates :name, uniqueness: { scope: [ :village_id, :conference_id ], message: "must be unique within the village" }
  validates :max_volunteers, presence: true, numericality: { greater_than: 0 }

  # Scopes
  scope :village_level, -> { where(conference_id: nil) }
  scope :for_conference, ->(conference) { where(conference_id: [ nil, conference.id ]) }

  # Instance methods
  def village_level?
    conference_id.nil?
  end

  def conference_specific?
    conference_id.present?
  end
end
