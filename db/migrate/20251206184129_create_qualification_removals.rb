class CreateQualificationRemovals < ActiveRecord::Migration[8.1]
  def change
    create_table :qualification_removals do |t|
      t.references :user, null: false, foreign_key: true
      t.references :qualification, null: false, foreign_key: true
      t.references :conference, null: false, foreign_key: true

      t.timestamps
    end

    add_index :qualification_removals, [ :user_id, :qualification_id, :conference_id ], unique: true, name: "idx_qual_removals_on_user_qual_conf"
  end
end
