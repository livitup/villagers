class CreateTimeslots < ActiveRecord::Migration[8.1]
  def change
    create_table :timeslots do |t|
      t.references :conference_program, null: false, foreign_key: true
      t.datetime :start_time, null: false
      t.datetime :end_time, null: false
      t.integer :max_volunteers, default: 1, null: false
      t.integer :current_volunteers_count, default: 0, null: false

      t.timestamps
    end

    add_index :timeslots, [ :conference_program_id, :start_time ], unique: true
    add_index :timeslots, :start_time
  end
end
