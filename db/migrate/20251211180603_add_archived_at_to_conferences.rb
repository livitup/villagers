class AddArchivedAtToConferences < ActiveRecord::Migration[8.1]
  def change
    add_column :conferences, :archived_at, :datetime
  end
end
