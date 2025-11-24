class Program < ApplicationRecord
  belongs_to :village

  validates :name, presence: true
  validates :name, uniqueness: { scope: :village_id, message: "must be unique within the village" }
end
