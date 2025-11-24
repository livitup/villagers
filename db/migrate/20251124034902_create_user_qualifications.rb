class CreateUserQualifications < ActiveRecord::Migration[8.1]
  def change
    create_table :user_qualifications do |t|
      t.references :user, null: false, foreign_key: true
      t.references :qualification, null: false, foreign_key: true

      t.timestamps
    end

    add_index :user_qualifications, [ :user_id, :qualification_id ], unique: true
  end
end
