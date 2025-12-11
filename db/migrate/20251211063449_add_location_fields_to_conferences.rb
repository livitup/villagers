class AddLocationFieldsToConferences < ActiveRecord::Migration[8.1]
  def change
    add_column :conferences, :country, :string, default: "US"
    add_column :conferences, :state, :string
    add_column :conferences, :city, :string
    remove_column :conferences, :location, :string
  end
end
