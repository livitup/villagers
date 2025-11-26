class AddMaxVolunteersToConferencePrograms < ActiveRecord::Migration[8.1]
  def change
    add_column :conference_programs, :max_volunteers, :integer, default: 1, null: false
  end
end
