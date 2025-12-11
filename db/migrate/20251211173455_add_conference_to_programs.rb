class AddConferenceToPrograms < ActiveRecord::Migration[8.1]
  def change
    add_reference :programs, :conference, null: true, foreign_key: true
  end
end
