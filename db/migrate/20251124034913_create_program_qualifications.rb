class CreateProgramQualifications < ActiveRecord::Migration[8.1]
  def change
    create_table :program_qualifications do |t|
      t.references :program, null: false, foreign_key: true
      t.references :qualification, null: false, foreign_key: true

      t.timestamps
    end

    add_index :program_qualifications, [ :program_id, :qualification_id ], unique: true
  end
end
