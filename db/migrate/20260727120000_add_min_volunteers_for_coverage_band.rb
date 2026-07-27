class AddMinVolunteersForCoverageBand < ActiveRecord::Migration[8.1]
  # Coverage band (#259): min_volunteers is the coverage target ("green at
  # min"), max_volunteers stays the hard signup cap. Backfilling min = max
  # preserves today's behavior exactly (covered used to mean full).
  def up
    add_column :timeslots, :min_volunteers, :integer, default: 1, null: false
    add_column :programs, :min_volunteers, :integer, default: 1, null: false
    add_column :conference_programs, :min_volunteers, :integer

    execute "UPDATE timeslots SET min_volunteers = max_volunteers"
    execute "UPDATE programs SET min_volunteers = max_volunteers"
    execute "UPDATE conference_programs SET min_volunteers = max_volunteers WHERE max_volunteers IS NOT NULL"
  end

  def down
    remove_column :timeslots, :min_volunteers
    remove_column :programs, :min_volunteers
    remove_column :conference_programs, :min_volunteers
  end
end
