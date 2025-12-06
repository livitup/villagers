class CreateConferenceQualifications < ActiveRecord::Migration[8.1]
  def change
    create_table :conference_qualifications do |t|
      t.string :name, null: false
      t.text :description, null: false
      t.references :conference, null: false, foreign_key: true

      t.timestamps
    end

    add_index :conference_qualifications, [ :conference_id, :name ], unique: true
  end
end
