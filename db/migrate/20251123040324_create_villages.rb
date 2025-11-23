class CreateVillages < ActiveRecord::Migration[8.1]
  def change
    create_table :villages do |t|
      t.string :name, null: false
      t.boolean :setup_complete, default: false, null: false

      t.timestamps
    end
  end
end
