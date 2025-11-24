class Program < ApplicationRecord
  belongs_to :village
  has_many :conference_programs, dependent: :destroy
  has_many :conferences, through: :conference_programs

  validates :name, presence: true
  validates :name, uniqueness: { scope: :village_id, message: "must be unique within the village" }
end
