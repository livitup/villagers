class CreateVolunteerSignups < ActiveRecord::Migration[8.1]
  def change
    create_table :volunteer_signups do |t|
      t.references :user, null: false, foreign_key: true
      t.references :timeslot, null: false, foreign_key: true

      t.timestamps
    end

    add_index :volunteer_signups, [ :user_id, :timeslot_id ], unique: true
  end
end
