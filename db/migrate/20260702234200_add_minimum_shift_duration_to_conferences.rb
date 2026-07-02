class AddMinimumShiftDurationToConferences < ActiveRecord::Migration[8.1]
  def change
    add_column :conferences, :minimum_shift_duration, :integer
  end
end
