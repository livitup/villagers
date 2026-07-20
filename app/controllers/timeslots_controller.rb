class TimeslotsController < ApplicationController
  before_action :authenticate_user!
  before_action :set_conference
  before_action :set_timeslot, only: [ :update, :add_volunteer, :remove_volunteer ]
  before_action :set_conference_program, only: [ :bulk_add_volunteer, :bulk_remove_volunteer, :bulk_update_capacity ]

  def update
    authorize @timeslot.conference_program, :update?, policy_class: ConferenceProgramPolicy

    if @timeslot.update(timeslot_params)
      redirect_to conference_schedule_path(@conference), notice: "Timeslot updated successfully."
    else
      redirect_to conference_schedule_path(@conference), alert: @timeslot.errors.full_messages.join(", ")
    end
  end

  def add_volunteer
    authorize @timeslot.conference_program, :update?, policy_class: ConferenceProgramPolicy

    user = User.find(params[:user_id])
    signup = VolunteerSignup.new(user: user, timeslot: @timeslot)

    if signup.save
      redirect_to conference_schedule_path(@conference), notice: "#{user.email} added to shift."
    else
      redirect_to conference_schedule_path(@conference), alert: signup.errors.full_messages.join(", ")
    end
  end

  def remove_volunteer
    authorize @timeslot.conference_program, :update?, policy_class: ConferenceProgramPolicy

    signup = @timeslot.volunteer_signups.find_by!(user_id: params[:user_id])
    user_email = signup.user.email
    signup.destroy

    redirect_to conference_schedule_path(@conference), notice: "#{user_email} removed from shift."
  end

  # --- Window/day-scoped admin operations (#242) ---
  # A "window" is start_timeslot_id + duration_minutes, mirroring the volunteer
  # bulk_create contract. All three are gated by ConferenceProgramPolicy#update?
  # (conference managers + this activity's lead).

  # Add a user to every slot in the window. Skips slots they're already on.
  # Admin placements may over-cover (exceed needed) — that's the settled
  # decision — but overlap and qualification rules still apply, and one bad
  # slot rolls back the whole window.
  def bulk_add_volunteer
    authorize @conference_program, :update?, policy_class: ConferenceProgramPolicy

    user = User.find(params[:user_id])
    slots = window_timeslots
    already_on = user.volunteer_signups.where(timeslot_id: slots.map(&:id)).pluck(:timeslot_id).to_set

    begin
      ActiveRecord::Base.transaction do
        slots.reject { |slot| already_on.include?(slot.id) }.each do |slot|
          VolunteerSignup.create!(user: user, timeslot: slot, allow_over_capacity: true)
        end
      end
      redirect_back fallback_location: conference_schedule_path(@conference),
                    notice: "#{helpers.display_name_with_callsign(user)} added #{window_label(slots)}."
    rescue ActiveRecord::RecordInvalid => e
      redirect_back fallback_location: conference_schedule_path(@conference),
                    alert: "Could not add #{user.display_name}: #{e.record.errors.full_messages.to_sentence}"
    end
  end

  # Remove a user from every slot in the window they're signed up for.
  def bulk_remove_volunteer
    authorize @conference_program, :update?, policy_class: ConferenceProgramPolicy

    user = User.find(params[:user_id])
    slots = window_timeslots
    signups = user.volunteer_signups.where(timeslot_id: slots.map(&:id))
    removed = signups.size

    ActiveRecord::Base.transaction { signups.destroy_all }

    redirect_back fallback_location: conference_schedule_path(@conference),
                  notice: "#{helpers.display_name_with_callsign(user)} removed from #{removed} slot#{'s' unless removed == 1}."
  end

  # Set needed (max_volunteers) for every slot of the activity on one date —
  # one value per day (settled decision).
  def bulk_update_capacity
    authorize @conference_program, :update?, policy_class: ConferenceProgramPolicy

    new_max = params[:max_volunteers].to_i
    if new_max < 1
      redirect_back fallback_location: conference_schedule_path(@conference),
                    alert: "Needed volunteers must be at least 1."
      return
    end

    date = Date.iso8601(params[:date].to_s)
    updated = @conference_program.timeslots.where(start_time: date.in_time_zone.all_day)
                                 .update_all(max_volunteers: new_max)

    redirect_back fallback_location: conference_schedule_path(@conference),
                  notice: "Needed set to #{new_max} for #{updated} slot#{'s' unless updated == 1} on #{date.strftime('%A, %B %-d')}."
  rescue Date::Error
    redirect_back fallback_location: conference_schedule_path(@conference), alert: "Invalid date."
  end

  private

  def set_conference
    @conference = Conference.find(params[:conference_id])
  end

  def set_conference_program
    @conference_program = @conference.conference_programs.find(params[:conference_program_id])
  end

  # Ordered slots of the window [start, start + duration) for this activity.
  def window_timeslots
    start_slot = @conference_program.timeslots.find(params[:start_timeslot_id])
    end_time = start_slot.start_time + params[:duration_minutes].to_i.minutes
    @conference_program.timeslots
                       .where("start_time >= ? AND start_time < ?", start_slot.start_time, end_time)
                       .order(:start_time)
                       .to_a
  end

  def window_label(slots)
    return "to 0 slots" if slots.empty?

    "#{slots.first.start_time.strftime('%-l:%M %p')} – #{slots.last.end_time.strftime('%-l:%M %p')}"
  end

  def set_timeslot
    @timeslot = @conference.timeslots.find(params[:id])
  end

  def timeslot_params
    params.require(:timeslot).permit(:max_volunteers)
  end
end
