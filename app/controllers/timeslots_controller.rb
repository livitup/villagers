class TimeslotsController < ApplicationController
  before_action :authenticate_user!
  before_action :set_conference
  before_action :set_conference_program

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
end
