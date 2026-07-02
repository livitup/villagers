class ScheduleController < ApplicationController
  before_action :authenticate_user!
  before_action :set_conference

  def show
    authorize @conference, :show?, policy_class: ConferencePolicy

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

    # Get all users for admin dropdown
    @users = User.order(:email) if @can_see_all_volunteers
  end

  private

  def set_conference
    @conference = Conference.find(params[:conference_id])
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
