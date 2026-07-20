# Renders conference-scoped requests in the conference's time zone (#252):
# every server-formatted time (schedule labels, flash messages, reports,
# exports) comes out in conference-local wall clock. Client code never
# formats times itself (#250), so this is the single display chokepoint.
module ConferenceTimeZone
  extend ActiveSupport::Concern

  included do
    around_action :use_conference_time_zone
  end

  private

  def use_conference_time_zone(&block)
    conference = @conference
    conference ||= Conference.find_by(id: params[:conference_id]) if params[:conference_id]
    return yield unless conference

    Time.use_zone(conference.time_zone, &block)
  end
end
