class ScheduleController < ApplicationController
  before_action :authenticate_user!
  before_action :set_conference

  # The schedule IS the coverage view (#244): per-activity claim stack
  # rendered from CoverageProjection for one selected day, with the
  # "where you're needed" triage. The legacy time-x-activity grid is retired.
  def show
    authorize @conference, :show?, policy_class: ConferencePolicy

    @days = (@conference.start_date..@conference.end_date).to_a
    @day = resolve_day
    @stack = CoverageProjection.stack(@conference, @day)
    @can_manage_any = manageable_program_ids.any?

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

  # The coverage view moved to the main schedule URL when the grid retired
  # (#244); keep old links working.
  def coverage
    redirect_to conference_schedule_path(
      @conference,
      params.permit(:day, :hide_full, around: []).to_h.symbolize_keys
    )
  end

  # Admin coverage board (#243): every manageable activity x every conference
  # day at a glance, plus a manage panel (roster / add / remove / needed)
  # wired to the #242 bulk endpoints. The panel opens via a plain Drive
  # navigation (?manage=cp_id&day=) and closes via a link that drops the
  # params — no Turbo Frames (see #241's chromedriver finding), no new JS.
  def board
    authorize @conference, :show?, policy_class: ConferencePolicy

    @manageable_program_ids = manageable_program_ids
    if @manageable_program_ids.empty?
      redirect_to conference_schedule_coverage_path(@conference),
                  alert: "You don't manage any activities at this conference."
      return
    end

    @days = (@conference.start_date..@conference.end_date).to_a

    # Rows: manageable activities x days, each cell a projection (or nil when
    # not scheduled that day). Built from the same bounded per-day loads the
    # volunteer stack uses.
    per_day = @days.index_with { |day| CoverageProjection.stack(@conference, day) }
    row_cps = per_day.values.flatten.map { |entry| entry[:conference_program] }.uniq
                     .select { |cp| @manageable_program_ids.include?(cp.program_id) }
                     .sort_by { |cp| cp.program.name }
    @rows = row_cps.map do |cp|
      cells = @days.index_with do |day|
        per_day[day].find { |entry| entry[:conference_program].id == cp.id }&.fetch(:projection)
      end
      { conference_program: cp, cells: cells }
    end

    # The ribbon partial is shared with the volunteer view; the board renders
    # it read-only, so there are no "mine" markers to compute.
    @my_timeslot_ids = Set.new

    load_manage_panel if params[:manage].present?
  end

  private

  def set_conference
    @conference = Conference.find(params[:conference_id])
  end

  # Manage-panel data for one activity+day. Denies activity leads reaching for
  # an activity that isn't theirs (same chokepoint as the #242 endpoints).
  def load_manage_panel
    @manage_cp = @conference.conference_programs.find(params[:manage])
    authorize @manage_cp, :update?, policy_class: ConferenceProgramPolicy

    @manage_day = begin
      day = Date.iso8601(params[:day].to_s)
      (@conference.start_date..@conference.end_date).cover?(day) ? day : @days.first
    rescue Date::Error
      @days.first
    end
    @manage_projection = CoverageProjection.for(@manage_cp, @manage_day)
    @manage_roster = manage_roster(@manage_cp, @manage_day)
    @users = User.order(:handle)
  end

  # The day's signups for one activity, grouped into contiguous ranges per
  # user: [{ user:, starts_at:, ends_at:, start_timeslot_id:, minutes: }]
  def manage_roster(conference_program, day)
    signups = VolunteerSignup.joins(:timeslot)
                             .where(timeslots: { conference_program_id: conference_program.id })
                             .where(timeslots: { start_time: day.in_time_zone.all_day })
                             .includes(:user, :timeslot)
                             .sort_by { |signup| signup.timeslot.start_time }

    signups.group_by(&:user).flat_map do |user, user_signups|
      user_signups.chunk_while { |a, b| a.timeslot.end_time == b.timeslot.start_time }.map do |run|
        {
          user: user,
          starts_at: run.first.timeslot.start_time,
          ends_at: run.last.timeslot.end_time,
          start_timeslot_id: run.first.timeslot.id,
          minutes: run.size * 15
        }
      end
    end.sort_by { |range| [ range[:starts_at], range[:user].display_name ] }
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
