class CreateConferenceUserQualifications < ActiveRecord::Migration[8.1]
  def change
    create_table :conference_user_qualifications do |t|
      t.references :user, null: false, foreign_key: true
      t.references :conference_qualification, null: false, foreign_key: true

      t.timestamps
    end

    add_index :conference_user_qualifications, [ :user_id, :conference_qualification_id ], unique: true, name: "idx_conf_user_quals_on_user_and_qual"
  end
end
