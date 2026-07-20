require "test_helper"

# CoverageProjection (#239): projects existing Timeslot data into coverage
# ticks and gap runs. Pure read model — the single source both the volunteer
# claim stack and the admin board render from.
class CoverageProjectionTest < ActiveSupport::TestCase
  setup do
    @village = Village.create!(name: "Test Village", setup_complete: true)
    @conference = Conference.create!(
      village: @village,
      name: "Test Conference",
      start_date: Date.tomorrow,
      end_date: Date.tomorrow + 1.day,
      conference_hours_start: "09:00",
      conference_hours_end: "17:00"
    )
    @program = Program.create!(name: "Ham Exams", village: @village)
    # Day 0: 09:00-11:00 -> 8 fifteen-minute slots, needed defaults to 1 each.
    @cp = ConferenceProgram.create!(
      conference: @conference,
      program: @program,
      day_schedules: { "0" => { "enabled" => true, "start" => "09:00", "end" => "11:00" } }
    )
    @day = @conference.start_date
    @slots = @cp.timeslots.order(:start_time).to_a
    assert_equal 8, @slots.size, "expected the schedule to generate 8 slots"
  end

  def cover(slot, count)
    slot.update_column(:current_volunteers_count, count)
  end

  # --- ticks ---

  test "ticks are ordered, one per slot, with needed/on read from the slot" do
    projection = CoverageProjection.for(@cp, @day)

    assert_equal 8, projection.ticks.size
    assert_equal @slots.map(&:id), projection.ticks.map { |t| t[:timeslot_id] }
    assert_equal @slots.first.start_time, projection.ticks.first[:start]
    assert_equal [ 1 ], projection.ticks.map { |t| t[:needed] }.uniq
    assert_equal [ 0 ], projection.ticks.map { |t| t[:on] }.uniq
  end

  test "tick states: bare when empty, short when under target, covered at or over target" do
    cover(@slots[1], 1)              # covered (1/1)
    @slots[2].update_column(:max_volunteers, 2)
    cover(@slots[2], 1)              # short (1/2)
    @slots[3].update_column(:max_volunteers, 2)
    cover(@slots[3], 3)              # covered (3/2 — admin over-cover)

    states = CoverageProjection.for(@cp, @day).ticks.map { |t| t[:state] }

    assert_equal :bare,    states[0]
    assert_equal :covered, states[1]
    assert_equal :short,   states[2]
    assert_equal :covered, states[3]
  end

  test "only the requested date's slots appear" do
    other_day_cp = ConferenceProgram.create!(
      conference: @conference,
      program: Program.create!(name: "Two Day Program", village: @village),
      day_schedules: {
        "0" => { "enabled" => true, "start" => "09:00", "end" => "10:00" },
        "1" => { "enabled" => true, "start" => "09:00", "end" => "12:00" }
      }
    )

    assert_equal 4,  CoverageProjection.for(other_day_cp, @day).ticks.size
    assert_equal 12, CoverageProjection.for(other_day_cp, @day + 1.day).ticks.size
  end

  test "a day with no slots yields no ticks and no gaps" do
    projection = CoverageProjection.for(@cp, @day + 1.day)

    assert_empty projection.ticks
    assert_empty projection.gaps
  end

  # --- gaps ---

  test "a fully uncovered day is one gap spanning the whole schedule" do
    gaps = CoverageProjection.for(@cp, @day).gaps

    assert_equal 1, gaps.size
    assert_equal @slots.first.start_time, gaps.first[:start]
    assert_equal @slots.last.end_time,    gaps.first[:end]
    assert_equal @slots.first.id,         gaps.first[:start_timeslot_id]
    assert_equal 120,                     gaps.first[:minutes]
  end

  test "covered slots split the day into separate gaps" do
    cover(@slots[2], 1)
    cover(@slots[3], 1)

    gaps = CoverageProjection.for(@cp, @day).gaps

    assert_equal 2, gaps.size
    assert_equal [ @slots[0].start_time, @slots[4].start_time ], gaps.map { |g| g[:start] }
    assert_equal [ 30, 60 ], gaps.map { |g| g[:minutes] }
  end

  test "a fully covered day has no gaps" do
    @slots.each { |slot| cover(slot, 1) }

    assert_empty CoverageProjection.for(@cp, @day).gaps
  end

  test "short slots count as gaps and carry the run's max needed" do
    @slots.each { |slot| cover(slot, 1) }
    @slots[5].update_column(:max_volunteers, 3)   # 1/3 -> short

    gaps = CoverageProjection.for(@cp, @day).gaps

    assert_equal 1, gaps.size
    assert_equal @slots[5].start_time, gaps.first[:start]
    assert_equal @slots[5].end_time,   gaps.first[:end]
    assert_equal 3, gaps.first[:needed]
  end

  test "a schedule break splits a gap even when both sides are uncovered" do
    # Split the day: 09:00-09:30 and 10:00-11:00 with a 30-minute break between.
    @cp.update!(day_schedules: {
      "0" => { "enabled" => true, "start" => "09:00", "end" => "09:30" },
      "1" => { "enabled" => true, "start" => "09:00", "end" => "11:00" }
    })
    morning = ConferenceProgram.create!(
      conference: @conference,
      program: Program.create!(name: "Split Program", village: @village),
      day_schedules: { "0" => { "enabled" => true, "start" => "09:00", "end" => "09:30" } }
    )
    # Manufacture the break by removing 09:30-10:00 from an extended schedule.
    morning.update!(day_schedules: { "0" => { "enabled" => true, "start" => "09:00", "end" => "10:30" } })
    morning.timeslots.order(:start_time).offset(2).limit(2).each(&:destroy!)

    gaps = CoverageProjection.for(morning, @day).gaps

    assert_equal 2, gaps.size, "gap must not span the 09:30-10:00 break"
    assert_equal 30, gaps.first[:minutes]
    assert_equal 30, gaps.last[:minutes]
  end

  # --- conference-wide summary ---

  test "summary returns one entry per program scheduled that day, worst first" do
    bare_program = @cp                                     # all bare
    short_program = ConferenceProgram.create!(
      conference: @conference,
      program: Program.create!(name: "Radio Demos", village: @village),
      day_schedules: { "0" => { "enabled" => true, "start" => "09:00", "end" => "10:00" } }
    )
    short_program.timeslots.each { |slot| slot.update_column(:current_volunteers_count, 1) }
    short_program.timeslots.first.update_column(:max_volunteers, 2)  # one short slot
    covered_program = ConferenceProgram.create!(
      conference: @conference,
      program: Program.create!(name: "Front Desk", village: @village),
      day_schedules: { "0" => { "enabled" => true, "start" => "09:00", "end" => "10:00" } }
    )
    covered_program.timeslots.each { |slot| slot.update_column(:current_volunteers_count, 1) }
    unscheduled = ConferenceProgram.create!(
      conference: @conference,
      program: Program.create!(name: "Night Only", village: @village),
      day_schedules: { "1" => { "enabled" => true, "start" => "09:00", "end" => "10:00" } }
    )

    summary = CoverageProjection.summary(@conference, @day)

    assert_equal [ bare_program.id, short_program.id, covered_program.id ],
                 summary.map { |entry| entry[:conference_program].id }
    refute_includes summary.map { |entry| entry[:conference_program].id }, unscheduled.id

    bare_entry, short_entry, covered_entry = summary
    assert_equal :bare, bare_entry[:worst_state]
    assert_equal 120,   bare_entry[:uncovered_minutes]
    assert_equal :short, short_entry[:worst_state]
    assert_equal 15,     short_entry[:uncovered_minutes]
    assert_equal :covered, covered_entry[:worst_state]
    assert_equal 0,        covered_entry[:uncovered_minutes]
    assert_nil covered_entry[:first_gap]
    assert_equal bare_entry[:first_gap][:start], @slots.first.start_time
  end

  test "summary orders same-state programs by uncovered minutes, worst first" do
    @slots.first(6).each { |slot| slot.update_column(:current_volunteers_count, 1) }  # 30 bare min left
    big_gap = ConferenceProgram.create!(
      conference: @conference,
      program: Program.create!(name: "All Day Bare", village: @village),
      day_schedules: { "0" => { "enabled" => true, "start" => "09:00", "end" => "12:00" } }
    )

    summary = CoverageProjection.summary(@conference, @day)

    assert_equal [ big_gap.id, @cp.id ], summary.map { |entry| entry[:conference_program].id }
  end

  test "summary uses a bounded number of queries" do
    3.times do |i|
      ConferenceProgram.create!(
        conference: @conference,
        program: Program.create!(name: "Prog #{i}", village: @village),
        day_schedules: { "0" => { "enabled" => true, "start" => "09:00", "end" => "10:00" } }
      )
    end

    queries = 0
    counter = ->(*, payload) { queries += 1 unless payload[:name] == "SCHEMA" }
    ActiveSupport::Notifications.subscribed(counter, "sql.active_record") do
      CoverageProjection.summary(@conference, @day)
    end

    assert_operator queries, :<=, 3, "summary should not N+1 across programs (ran #{queries} queries)"
  end
end
