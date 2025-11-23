class CreateUsers < ActiveRecord::Migration[8.1]
  def change
    create_table :users do |t|
      t.string :email, null: false
      t.string :password_digest, null: false
      t.string :name
      t.string :handle
      t.string :phone
      t.string :twitter
      t.string :signal
      t.string :discord

      t.timestamps
    end

    add_index :users, :email, unique: true
  end
end
