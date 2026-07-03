class VolunteerSignupsController < ApplicationController
  before_action :authenticate_user!
  before_action :set_conference
  before_action :set_timeslot, only: [ :create ]
  before_action :set_volunteer_signup, only: [ :destroy ]

  def index
    authorize @conference, :show?, policy_class: ConferencePolicy
    @my_signups = current_user.volunteer_signups.joins(:timeslot)
                              .where(timeslots: { conference_program_id: @conference.conference_programs.pluck(:id) })
                              .includes(timeslot: [ :conference_program, :program ])
                              .order("timeslots.start_time")

    @shift_groups = group_consecutive_signups(@my_signups)
  end

  def create
    @volunteer_signup = VolunteerSignup.new(user: current_user, timeslot: @timeslot)

    if @volunteer_signup.save
      NotificationService.notify_shift_signups(user: current_user, signups: [ @volunteer_signup ])
      redirect_to conference_volunteer_signups_path(@timeslot.conference), notice: "Successfully signed up for this shift."
    else
      redirect_to conference_volunteer_signups_path(@timeslot.conference), alert: @volunteer_signup.errors.full_messages.join(", ")
    end
  end

  def bulk_create
    start_timeslot = Timeslot.find(params[:timeslot_id])
    conference_program = start_timeslot.conference_program

    # Calculate end time from duration or use provided end_time
    if params[:duration_minutes].present?
      requested_minutes = params[:duration_minutes].to_i
      end_time = start_timeslot.start_time + requested_minutes.minutes
    else
      end_time = Time.zone.parse(params[:end_time])
      requested_minutes = ((end_time - start_timeslot.start_time) / 60).to_i
    end

    # Enforce the conference shift block: durations must be at least one block
    # and a whole number of blocks (e.g. 30-min blocks => 30, 60, 90, ...).
    block_minutes = @conference.effective_minimum_shift_duration
    if requested_minutes < block_minutes || (requested_minutes % block_minutes).nonzero?
      redirect_to conference_schedule_path(@conference),
                  alert: "Shifts must be booked in #{block_minutes}-minute blocks for this conference."
      return
    end

    # Find all timeslots in the range for this program
    timeslots = conference_program.timeslots
                                  .where("start_time >= ? AND start_time < ?", start_timeslot.start_time, end_time)
                                  .order(:start_time)

    # Get user's existing signups for these timeslots
    existing_signup_ids = current_user.volunteer_signups
                                      .where(timeslot_id: timeslots.pluck(:id))
                                      .pluck(:timeslot_id)
                                      .to_set

    # Filter to timeslots user isn't already signed up for
    timeslots_to_signup = timeslots.reject { |ts| existing_signup_ids.include?(ts.id) }

    # Check if any timeslot is full
    full_timeslots = timeslots_to_signup.select(&:full?)
    if full_timeslots.any?
      redirect_to conference_schedule_path(@conference),
                  alert: "Cannot sign up: Some timeslots are full (#{full_timeslots.first.start_time.strftime('%l:%M %p').strip})"
      return
    end

    # Create signups in a transaction
    created_signups = []
    ActiveRecord::Base.transaction do
      timeslots_to_signup.each do |timeslot|
        signup = VolunteerSignup.new(user: current_user, timeslot: timeslot)
        if signup.save
          created_signups << signup
        else
          raise ActiveRecord::Rollback, signup.errors.full_messages.join(", ")
        end
      end
    end

    # Send single consolidated notification for all signups
    NotificationService.notify_shift_signups(user: current_user, signups: created_signups) if created_signups.any?

    created_count = created_signups.size
    total_minutes = created_count * 15
    hours = total_minutes / 60
    minutes = total_minutes % 60
    duration_str = hours > 0 ? "#{hours} hour#{'s' if hours > 1}" : ""
    duration_str += " #{minutes} minutes" if minutes > 0

    redirect_to conference_volunteer_signups_path(@conference),
                notice: "Successfully signed up for #{created_count} shifts (#{duration_str.strip})."
  end

  def available_timeslots
    start_timeslot = Timeslot.find(params[:timeslot_id])
    conference_program = start_timeslot.conference_program

    # Get all future timeslots for this program on the same day
    day_end = start_timeslot.start_time.end_of_day
    timeslots = conference_program.timeslots
                                  .where("start_time >= ? AND start_time < ?", start_timeslot.start_time, day_end)
                                  .order(:start_time)

    # Get user's existing signups
    existing_signup_ids = current_user.volunteer_signups
                                      .where(timeslot_id: timeslots.pluck(:id))
                                      .pluck(:timeslot_id)
                                      .to_set

    # Build available end times (only consecutive available slots)
    available_end_times = []
    timeslots.each do |ts|
      is_available = !ts.full? || existing_signup_ids.include?(ts.id)
      break unless is_available # Stop at first unavailable slot

      available_end_times << {
        end_time: ts.end_time.iso8601,
        display: ts.end_time.strftime("%l:%M %p").strip,
        duration_minutes: ((ts.end_time - start_timeslot.start_time) / 60).to_i,
        slots_count: available_end_times.length + 1
      }
    end

    render json: {
      start_time: start_timeslot.start_time.iso8601,
      start_time_display: start_timeslot.start_time.strftime("%l:%M %p").strip,
      program_name: conference_program.program.name,
      minimum_shift_duration: @conference.effective_minimum_shift_duration,
      available_end_times: available_end_times
    }
  end

  def destroy
    @volunteer_signup.destroy
    redirect_to conference_volunteer_signups_path(@conference), notice: "Signup cancelled successfully."
  end

  def bulk_destroy
    signup_ids = params[:signup_ids] || []
    # Only delete signups that belong to the current user
    signups = current_user.volunteer_signups.where(id: signup_ids)
    count = signups.count
    signups.destroy_all

    redirect_to conference_volunteer_signups_path(@conference),
                notice: "Cancelled #{count} shift#{'s' if count != 1}."
  end

  private

  def set_conference
    @conference = Conference.find(params[:conference_id])
  end

  def set_timeslot
    @timeslot = Timeslot.find(params[:timeslot_id])
  end

  def set_volunteer_signup
    @volunteer_signup = current_user.volunteer_signups.find(params[:id])
  end

  def group_consecutive_signups(signups)
    return [] if signups.empty?

    groups = []
    current_group = nil

    signups.each do |signup|
      timeslot = signup.timeslot
      program_id = timeslot.conference_program.program_id

      if current_group.nil?
        # Start a new group
        current_group = new_group(signup)
      elsif current_group[:program_id] == program_id &&
            current_group[:end_time] == timeslot.start_time
        # Continue the current group (consecutive and same program)
        current_group[:end_time] = timeslot.end_time
        current_group[:signups] << signup
      else
        # Save current group and start a new one
        groups << current_group
        current_group = new_group(signup)
      end
    end

    # Don't forget the last group
    groups << current_group if current_group

    groups
  end

  def new_group(signup)
    timeslot = signup.timeslot
    {
      program_id: timeslot.conference_program.program_id,
      program_name: timeslot.program.name,
      start_time: timeslot.start_time,
      end_time: timeslot.end_time,
      signups: [ signup ]
    }
  end
end
