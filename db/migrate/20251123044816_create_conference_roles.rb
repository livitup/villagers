class CreateConferenceRoles < ActiveRecord::Migration[8.1]
  def change
    create_table :conference_roles do |t|
      t.references :user, null: false, foreign_key: true
      t.references :conference, null: false, foreign_key: true
      t.string :role_name, null: false

      t.timestamps
    end

    add_index :conference_roles, [ :user_id, :conference_id, :role_name ], unique: true, name: "index_conference_roles_unique"
  end
end
