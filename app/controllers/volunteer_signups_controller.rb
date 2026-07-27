class VolunteerSignupsController < ApplicationController
  before_action :authenticate_user!
  include ConferenceTimeZone
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
      redirect_to signup_return_path(conference_schedule_path(@conference)),
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

    # Time conflicts with other shifts (#267): don't silently fail — send the
    # volunteer to the schedule's swap-or-keep confirmation modal. The modal
    # posts back here with replace_conflicts=1 to swap.
    conflicting_signups = VolunteerSignup.conflicting_for(
      current_user, conference_program, start_timeslot.start_time, end_time
    ).to_a
    if conflicting_signups.any? && params[:replace_conflicts] != "1"
      redirect_to conference_schedule_path(
        @conference,
        day: params[:return_day].presence || start_timeslot.start_time.to_date.iso8601,
        confirm_swap: start_timeslot.id, swap_minutes: requested_minutes
      )
      return
    end

    # Everything requested is already theirs: say so instead of celebrating a
    # zero-shift signup (#267).
    if timeslots_to_signup.empty?
      redirect_to signup_return_path(conference_schedule_path(@conference)),
                  alert: "You're already signed up for this window — nothing was changed."
      return
    end

    # Check if any timeslot is full
    full_timeslots = timeslots_to_signup.select(&:full?)
    if full_timeslots.any?
      redirect_to signup_return_path(conference_schedule_path(@conference)),
                  alert: "Cannot sign up: Some timeslots are full (#{full_timeslots.first.start_time.strftime('%l:%M %p').strip})"
      return
    end

    # Swap atomically: cancel the conflicting shifts and create the new ones in
    # one transaction, so a failed signup leaves the old shifts untouched.
    # (ActiveRecord::Rollback is swallowed by the transaction block, so the
    # failure must be carried out via a local — previously it fell through to
    # the success notice, the "signed up for 0 shifts" bug.)
    created_signups = []
    failure_message = nil
    ActiveRecord::Base.transaction do
      conflicting_signups.each(&:destroy!)
      timeslots_to_signup.each do |timeslot|
        signup = VolunteerSignup.new(user: current_user, timeslot: timeslot)
        if signup.save
          created_signups << signup
        else
          failure_message = signup.errors.full_messages.join(", ")
          raise ActiveRecord::Rollback
        end
      end
    end

    if failure_message
      redirect_to signup_return_path(conference_schedule_path(@conference)),
                  alert: "Could not sign up: #{failure_message}. Your existing shifts are unchanged."
      return
    end

    # Send single consolidated notification for all signups
    NotificationService.notify_shift_signups(user: current_user, signups: created_signups)

    created_count = created_signups.size
    total_minutes = created_count * 15
    hours = total_minutes / 60
    minutes = total_minutes % 60
    duration_str = hours > 0 ? "#{hours} hour#{'s' if hours > 1}" : ""
    duration_str += " #{minutes} minutes" if minutes > 0

    notice = "Successfully signed up for #{created_count} shifts (#{duration_str.strip})."
    if conflicting_signups.any?
      notice = "Cancelled #{conflicting_signups.size} conflicting shift#{'s' if conflicting_signups.size != 1}. #{notice}"
    end

    redirect_to signup_return_path(conference_volunteer_signups_path(@conference)), notice: notice
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

  # Where bulk_create sends the user afterward. The schedule's claim forms
  # post return_to=coverage (+ return_day) so claims land back on the ribbon
  # they came from; other callers keep the legacy destinations.
  def signup_return_path(default)
    return default unless params[:return_to] == "coverage"

    conference_schedule_path(@conference, day: params[:return_day].presence)
  end

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
