class ScheduleController < ApplicationController
  before_action :authenticate_user!
  before_action :set_conference

  def show
    authorize @conference, :show?, policy_class: ConferencePolicy

    # Conference managers manage every activity; an activity lead manages only
    # their own. @manageable_program_ids is the set of Program ids whose columns
    # the current user may administer (see full volunteer names, add/remove
    # volunteers, edit capacity). @can_see_all_volunteers stays true only for
    # full conference managers (used for the page-level view badge).
    @manageable_program_ids = manageable_program_ids
    @can_see_all_volunteers = current_user.can_manage_conference?(@conference)

    # Build time slots for each day (15-minute increments)
    @schedule_data = build_schedule_data

    # Get user's signups for highlighting
    @user_signups = current_user.volunteer_signups
                                .where(timeslot_id: @conference.timeslots.pluck(:id))
                                .pluck(:timeslot_id)
                                .to_set

    # Get all programs for this conference
    @programs = @conference.programs.order(:name)

    # Build qualification data for programs
    @program_qualifications = build_program_qualifications

    # Build user's effective qualifications for this conference
    @user_qualification_ids = build_user_qualification_ids

    # Get all users for admin dropdown (needed whenever the user can manage at
    # least one activity, so activity leads get the add-volunteer picker too)
    @users = User.order(:email) if @manageable_program_ids.any?
  end

  # Coverage-based volunteer view (#240): per-activity claim stack rendered
  # from CoverageProjection for one selected day. Ships alongside the legacy
  # grid (#show) until the redesign reaches parity (#244).
  def coverage
    authorize @conference, :show?, policy_class: ConferencePolicy

    @days = (@conference.start_date..@conference.end_date).to_a
    @day = resolve_day
    @stack = CoverageProjection.stack(@conference, @day)

    @program_qualifications = build_program_qualifications
    @user_qualification_ids = build_user_qualification_ids

    # "Where you're needed" triage (#241): every uncovered gap across the days
    # the volunteer is around (all days when unfiltered), worst first.
    @around_days = parse_around_days
    triage_days = @around_days.presence || @days
    @triage = triage_days.flat_map do |day|
      CoverageProjection.summary(@conference, day).map { |entry| entry.merge(day: day) }
    end
    @triage = @triage.reject { |entry| entry[:worst_state] == :covered }
                     .sort_by { |entry| [ CoverageProjection::STATE_RANK.fetch(entry[:worst_state]), -entry[:uncovered_minutes] ] }

    @hide_full = params[:hide_full] == "1"
    @stack = @stack.reject { |entry| entry[:projection].gaps.empty? } if @hide_full

    # My signups for the day: a Set of timeslot ids for ribbon marking, and
    # contiguous ranges per activity for the "Your shifts" card.
    day_signups = current_user.volunteer_signups
                              .joins(timeslot: { conference_program: :program })
                              .where(conference_programs: { conference_id: @conference.id })
                              .where(timeslots: { start_time: @day.in_time_zone.all_day })
                              .includes(timeslot: { conference_program: :program })
                              .sort_by { |signup| signup.timeslot.start_time }
    @my_timeslot_ids = day_signups.map(&:timeslot_id).to_set
    @my_shift_ranges = group_signups_into_ranges(day_signups)
  end

  private

  def set_conference
    @conference = Conference.find(params[:conference_id])
  end

  # The selected day: ?day= if it falls inside the conference, else today
  # clamped into the conference range.
  def resolve_day
    requested = begin
      Date.iso8601(params[:day].to_s)
    rescue Date::Error
      nil
    end
    return requested if requested && (@conference.start_date..@conference.end_date).cover?(requested)

    Date.current.clamp(@conference.start_date, @conference.end_date)
  end

  # Valid conference days from around[] params, in conference order.
  def parse_around_days
    requested = Array(params[:around]).filter_map do |value|
      Date.iso8601(value.to_s)
    rescue Date::Error
      nil
    end
    @days & requested
  end

  # Collapse a day's signups into contiguous ranges per activity:
  # [{ program_name:, starts_at:, ends_at: }, ...]
  def group_signups_into_ranges(signups)
    signups.group_by { |signup| signup.timeslot.conference_program }.flat_map do |conference_program, program_signups|
      program_signups.chunk_while { |a, b| a.timeslot.end_time == b.timeslot.start_time }.map do |run|
        {
          program_name: conference_program.program.name,
          starts_at: run.first.timeslot.start_time,
          ends_at: run.last.timeslot.end_time
        }
      end
    end.sort_by { |range| range[:starts_at] }
  end

  # Set of Program ids the current user may administer on this schedule.
  # Conference managers get all of them; activity leads get only the programs
  # they lead at this conference.
  def manageable_program_ids
    if current_user.can_manage_conference?(@conference)
      return @conference.conference_programs.pluck(:program_id).to_set
    end

    ConferenceProgram.where(conference: @conference)
                     .joins(:conference_program_roles)
                     .where(conference_program_roles: {
                              user_id: current_user.id,
                              role_name: ConferenceProgramRole::ACTIVITY_LEAD
                            })
                     .pluck(:program_id)
                     .to_set
  end

  def build_schedule_data
    schedule = {}

    (@conference.start_date..@conference.end_date).each do |date|
      schedule[date] = {
        time_slots: build_time_slots_for_day(date),
        programs: {}
      }

      # Get timeslots for this day grouped by program
      @conference.conference_programs.includes(:program).each do |cp|
        program = cp.program
        timeslots = {}

        cp.timeslots.where("DATE(start_time) = ?", date).includes(:volunteer_signups, :users).each do |timeslot|
          timeslots[timeslot.start_time.strftime("%H:%M")] = {
            timeslot: timeslot,
            volunteers: timeslot.users,
            signed_up_count: timeslot.current_volunteers_count,
            max_volunteers: timeslot.max_volunteers,
            full: timeslot.full?
          }
        end

        # Skip programs that have no timeslots on this day so empty columns are
        # not rendered (issue #181).
        next if timeslots.empty?

        schedule[date][:programs][program.id] = {
          name: program.name,
          timeslots: timeslots
        }
      end
    end

    schedule
  end

  def build_time_slots_for_day(date)
    slots = []
    start_hour = @conference.conference_hours_start&.hour || 8
    start_min = @conference.conference_hours_start&.min || 0
    end_hour = @conference.conference_hours_end&.hour || 18
    end_min = @conference.conference_hours_end&.min || 0

    current_time = Time.zone.local(date.year, date.month, date.day, start_hour, start_min)
    end_time = Time.zone.local(date.year, date.month, date.day, end_hour, end_min)

    while current_time < end_time
      slots << current_time.strftime("%H:%M")
      current_time += 15.minutes
    end

    slots
  end

  # Build a hash of program_id => [qualifications] for efficient lookup
  def build_program_qualifications
    program_ids = @conference.conference_programs.pluck(:program_id)
    Program.where(id: program_ids)
           .includes(:qualifications)
           .index_by(&:id)
           .transform_values(&:qualifications)
  end

  # Build a set of qualification IDs the user effectively has for this conference
  # (i.e., qualifications they have minus any removed for this conference)
  def build_user_qualification_ids
    user_qual_ids = current_user.user_qualifications.pluck(:qualification_id).to_set
    removed_qual_ids = current_user.qualification_removals
                                   .where(conference: @conference)
                                   .pluck(:qualification_id)
                                   .to_set
    user_qual_ids - removed_qual_ids
  end
end
