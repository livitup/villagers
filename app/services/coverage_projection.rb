# Projects existing Timeslot data into coverage over time (#239).
#
# An activity is a position staffed continuously while the village is open;
# this read model answers "how covered is it, and where are the holes?" for
# one activity-day (.for) or a whole conference-day (.summary). It reads only
# what Timeslot already stores — max_volunteers ("needed") and the
# denormalized current_volunteers_count ("on") — so there are no counting
# queries and no schema changes.
#
#   projection = CoverageProjection.for(conference_program, date)
#   projection.ticks # => [{ timeslot_id:, start:, end:, needed:, on:, state: }, ...]
#   projection.gaps  # => [{ start:, end:, needed:, start_timeslot_id:, minutes: }, ...]
#
# States: on >= needed -> :covered, on == 0 -> :bare, otherwise :short.
# A gap is a time-contiguous run of ticks where on < needed — exactly the
# windows a volunteer may claim (the server already restricts self-signup to
# non-full slots, so gaps and claimable windows coincide).
class CoverageProjection
  TICK_MINUTES = 15
  STATE_RANK = { bare: 0, short: 1, covered: 2 }.freeze

  attr_reader :ticks, :gaps

  def self.for(conference_program, date)
    new(conference_program.timeslots.where(start_time: date.in_time_zone.all_day).order(:start_time))
  end

  # Every program scheduled on the date with its full projection, ordered by
  # program name — the volunteer claim stack renders straight from this.
  # Same bounded-query load as .summary (no per-program N+1).
  def self.stack(conference, date)
    slots = Timeslot.joins(:conference_program)
                    .where(conference_programs: { conference_id: conference.id })
                    .where(start_time: date.in_time_zone.all_day)
                    .order(:start_time)
                    .preload(conference_program: :program)

    slots.group_by(&:conference_program)
         .map { |conference_program, program_slots| { conference_program: conference_program, projection: new(program_slots) } }
         .sort_by { |entry| entry[:conference_program].program.name }
  end

  # One entry per conference program scheduled on the date, worst coverage
  # first (any bare beats any short beats covered; ties broken by uncovered
  # minutes, descending). Programs with no slots that day are omitted — the
  # admin board renders those as "not scheduled" itself.
  def self.summary(conference, date)
    slots = Timeslot.joins(:conference_program)
                    .where(conference_programs: { conference_id: conference.id })
                    .where(start_time: date.in_time_zone.all_day)
                    .order(:start_time)
                    .preload(conference_program: :program)

    slots.group_by(&:conference_program).map do |conference_program, program_slots|
      projection = new(program_slots)
      {
        conference_program: conference_program,
        program_name: conference_program.program.name,
        worst_state: projection.worst_state,
        uncovered_minutes: projection.uncovered_minutes,
        first_gap: projection.gaps.first
      }
    end.sort_by { |entry| [ STATE_RANK.fetch(entry[:worst_state]), -entry[:uncovered_minutes] ] }
  end

  def initialize(timeslots)
    @ticks = timeslots.map { |slot| tick_for(slot) }
    @gaps = build_gaps(@ticks)
  end

  def worst_state
    ticks.min_by { |tick| STATE_RANK.fetch(tick[:state]) }&.fetch(:state) || :covered
  end

  def uncovered_minutes
    gaps.sum { |gap| gap[:minutes] }
  end

  private

  def tick_for(slot)
    {
      timeslot_id: slot.id,
      start: slot.start_time,
      end: slot.end_time,
      needed: slot.max_volunteers,
      on: slot.current_volunteers_count,
      state: state_of(slot)
    }
  end

  def state_of(slot)
    return :covered if slot.current_volunteers_count >= slot.max_volunteers
    return :bare if slot.current_volunteers_count.zero?

    :short
  end

  # Merge consecutive under-covered ticks into runs. "Consecutive" is by time,
  # not array position: a break in the schedule (no slot for a window) ends the
  # run even though the next under-covered tick is adjacent in the array.
  def build_gaps(ticks)
    gaps = []
    current = nil

    ticks.each do |tick|
      under = tick[:on] < tick[:needed]

      if under && current && current[:end] == tick[:start]
        current[:end] = tick[:end]
        current[:needed] = [ current[:needed], tick[:needed] ].max
        current[:minutes] += TICK_MINUTES
      elsif under
        gaps << current if current
        current = {
          start: tick[:start],
          end: tick[:end],
          needed: tick[:needed],
          start_timeslot_id: tick[:timeslot_id],
          minutes: TICK_MINUTES
        }
      elsif current
        gaps << current
        current = nil
      end
    end

    gaps << current if current
    gaps
  end
end
