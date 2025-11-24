class Village < ApplicationRecord
  has_many :programs, dependent: :destroy
  has_many :qualifications, dependent: :destroy

  validates :name, presence: true

  def self.setup_complete?
    exists? && first.setup_complete?
  end
end
