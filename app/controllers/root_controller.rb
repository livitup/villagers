class RootController < ApplicationController
  def show
    if Village.setup_complete?
      @village = Village.first
      load_dashboard_data if user_signed_in?
      render :show
    else
      redirect_to setup_path
    end
  end

  private

  def load_dashboard_data
    if current_user.village_admin?
      load_village_admin_data
    end

    if current_user.conference_lead_conferences.any? || current_user.conference_admin_conferences.any?
      load_conference_manager_data
    end

    # All users get volunteer data
    load_volunteer_data
  end

  def load_village_admin_data
    @active_conferences = Conference.active.order(start_date: :asc).limit(5)
    @archived_conferences_count = Conference.archived.count
    @total_programs = Program.count
    @total_users = User.count
    @total_volunteer_hours = VolunteerSignup.count * 0.25
    @recent_signups = VolunteerSignup.includes(user: [], timeslot: { conference_program: [ :conference, :program ] })
                                     .order(created_at: :desc)
                                     .limit(5)
  end

  def load_conference_manager_data
    managed_conference_ids = current_user.conference_roles.pluck(:conference_id)
    @managed_conferences = Conference.where(id: managed_conference_ids)
                                     .active
                                     .includes(:conference_programs)
                                     .order(start_date: :asc)

    # Conferences needing attention (low fill rate or upcoming with no programs)
    @conferences_needing_attention = @managed_conferences.select do |conf|
      conf.fill_rate < 50 || conf.programs_count == 0
    end

    @managed_recent_signups = VolunteerSignup.joins(timeslot: :conference_program)
                                             .where(conference_programs: { conference_id: managed_conference_ids })
                                             .includes(user: [], timeslot: { conference_program: [ :conference, :program ] })
                                             .order(created_at: :desc)
                                             .limit(5)
  end

  def load_volunteer_data
    @my_upcoming_shifts = current_user.volunteer_signups
                                      .joins(timeslot: :conference_program)
                                      .includes(timeslot: { conference_program: [ :conference, :program ] })
                                      .where("timeslots.start_time > ?", Time.current)
                                      .order("timeslots.start_time ASC")
                                      .limit(5)

    @my_total_shifts = current_user.total_shifts
    @my_total_hours = current_user.total_volunteer_hours
    @my_conferences_count = current_user.conferences_participated_count

    # My qualifications
    @my_qualifications = current_user.qualifications.order(:name)

    # Open opportunities - conferences with available shifts
    signed_up_conference_ids = current_user.volunteer_signups
                                           .joins(timeslot: :conference_program)
                                           .select("conference_programs.conference_id")
                                           .distinct
                                           .pluck("conference_programs.conference_id")

    @open_conferences = Conference.active
                                  .where("end_date >= ?", Date.current)
                                  .where.not(id: signed_up_conference_ids)
                                  .includes(:conference_programs)
                                  .select { |c| c.unfilled_timeslots > 0 }
                                  .first(3)
  end
end
