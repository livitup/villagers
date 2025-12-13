class CreateProgramRoles < ActiveRecord::Migration[8.1]
  def change
    create_table :program_roles do |t|
      t.references :user, null: false, foreign_key: true
      t.references :program, null: false, foreign_key: true
      t.string :role_name, null: false

      t.timestamps
    end

    add_index :program_roles, [ :user_id, :program_id, :role_name ], unique: true
  end
end
