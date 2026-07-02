class CreateConferenceProgramRoles < ActiveRecord::Migration[8.1]
  def change
    create_table :conference_program_roles do |t|
      t.references :conference_program, null: false, foreign_key: true
      t.references :user, null: false, foreign_key: true
      t.string :role_name, null: false

      t.timestamps
    end

    add_index :conference_program_roles,
              [ :user_id, :conference_program_id, :role_name ],
              unique: true,
              name: "index_conference_program_roles_unique"
  end
end
