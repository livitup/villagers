class CreateConferencePrograms < ActiveRecord::Migration[8.1]
  def change
    create_table :conference_programs do |t|
      t.references :conference, null: false, foreign_key: true
      t.references :program, null: false, foreign_key: true
      t.text :public_description
      t.jsonb :day_schedules, default: {}

      t.timestamps
    end

    add_index :conference_programs, [ :conference_id, :program_id ], unique: true
  end
end
