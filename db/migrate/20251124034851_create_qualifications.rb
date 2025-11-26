class CreateQualifications < ActiveRecord::Migration[8.1]
  def change
    create_table :qualifications do |t|
      t.string :name, null: false
      t.text :description, null: false
      t.references :village, null: false, foreign_key: true

      t.timestamps
    end

    add_index :qualifications, [ :village_id, :name ], unique: true
  end
end
