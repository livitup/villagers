class AddTimeZoneToConferences < ActiveRecord::Migration[8.1]
  # Backfilling "UTC" preserves current behavior exactly: every stored
  # timeslot instant was generated as UTC wall clock, so no data moves at
  # migrate time. Assigning a real zone afterward slides slots in place
  # (see TimeslotGenerator, #252).
  def change
    add_column :conferences, :time_zone, :string, null: false, default: "UTC"
  end
end
