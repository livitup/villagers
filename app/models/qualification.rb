class Qualification < ApplicationRecord
  belongs_to :village
  has_many :user_qualifications, dependent: :destroy
  has_many :users, through: :user_qualifications
  has_many :program_qualifications, dependent: :destroy
  has_many :programs, through: :program_qualifications

  validates :name, presence: true, uniqueness: { scope: :village_id }
  validates :description, presence: true
end
