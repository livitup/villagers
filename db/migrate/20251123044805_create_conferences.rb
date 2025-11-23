class CreateConferences < ActiveRecord::Migration[8.1]
  def change
    create_table :conferences do |t|
      t.references :village, null: false, foreign_key: true
      t.string :name, null: false
      t.string :location
      t.date :start_date, null: false
      t.date :end_date, null: false
      t.time :conference_hours_start
      t.time :conference_hours_end

      t.timestamps
    end
  end
end
