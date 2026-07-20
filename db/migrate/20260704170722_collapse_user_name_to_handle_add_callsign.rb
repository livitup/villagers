class CollapseUserNameToHandleAddCallsign < ActiveRecord::Migration[8.1]
  # We no longer collect "official" names. The existing `handle` column becomes
  # the single Display Name, and a new optional `callsign` is added. This drops
  # `name` after preserving any display name people already gave.
  def up
    add_column :users, :callsign, :string

    # Preserve display names people already set: fill blank handles from name.
    execute(<<~SQL.squish)
      UPDATE users SET handle = name
      WHERE (handle IS NULL OR handle = '') AND name IS NOT NULL AND name <> ''
    SQL

    # Anyone still without a handle falls back to their email so the new
    # NOT NULL constraint passes and no one is left without a Display Name.
    execute(<<~SQL.squish)
      UPDATE users SET handle = email WHERE handle IS NULL OR handle = ''
    SQL

    change_column_null :users, :handle, false
    remove_column :users, :name
  end

  def down
    add_column :users, :name, :string
    change_column_null :users, :handle, true
    remove_column :users, :callsign
  end
end
