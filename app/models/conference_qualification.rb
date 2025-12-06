class ConferenceQualification < ApplicationRecord
  belongs_to :conference
  has_many :conference_user_qualifications, dependent: :destroy
  has_many :users, through: :conference_user_qualifications

  validates :name, presence: true, uniqueness: { scope: :conference_id }
  validates :description, presence: true
end
