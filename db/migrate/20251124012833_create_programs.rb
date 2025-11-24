class CreatePrograms < ActiveRecord::Migration[8.1]
  def change
    create_table :programs do |t|
      t.string :name, null: false
      t.text :description
      t.references :village, null: false, foreign_key: true

      t.timestamps
    end

    add_index :programs, [ :village_id, :name ], unique: true
  end
end
