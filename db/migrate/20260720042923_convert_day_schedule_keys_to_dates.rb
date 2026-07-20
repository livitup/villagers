class ConvertDayScheduleKeysToDates < ActiveRecord::Migration[8.1]
  # day_schedules were keyed by positional day index ("0", "1", ...) anchored
  # at the conference start_date, so moving start_date silently re-assigned
  # every day's hours to different dates (#226). Re-key by calendar date
  # (ISO "YYYY-MM-DD") using each conference's start_date as of now.
  #
  # Data-only migration; raw SQL/JSON handling so it doesn't depend on model
  # code. Idempotent: date-looking keys pass through untouched.
  def up
    say_with_time "re-keying conference_programs.day_schedules by calendar date" do
      execute(<<~SQL.squish).each do |row|
        SELECT cp.id, cp.day_schedules, c.start_date
        FROM conference_programs cp
        JOIN conferences c ON c.id = cp.conference_id
        WHERE cp.day_schedules IS NOT NULL
      SQL
        schedules = row["day_schedules"].is_a?(String) ? JSON.parse(row["day_schedules"]) : row["day_schedules"]
        next if schedules.blank?

        start_date = row["start_date"].is_a?(String) ? Date.parse(row["start_date"]) : row["start_date"]
        converted = schedules.transform_keys do |key|
          key.to_s.match?(/\A\d+\z/) ? (start_date + key.to_i).iso8601 : key.to_s
        end
        next if converted == schedules

        execute(<<~SQL.squish)
          UPDATE conference_programs
          SET day_schedules = #{connection.quote(converted.to_json)}
          WHERE id = #{row['id'].to_i}
        SQL
      end
    end
  end

  def down
    # Irreversible in general (index keys are lossy relative to dates), and
    # date keys are also understood by no prior code paths worth restoring.
    raise ActiveRecord::IrreversibleMigration
  end
end
