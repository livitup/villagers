class Village < ApplicationRecord
  validates :name, presence: true

  def self.setup_complete?
    exists? && first.setup_complete?
  end
end
