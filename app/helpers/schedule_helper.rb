module ScheduleHelper
  # Params for coverage-view links that preserve the current day filters
  # (#241): around[] and hide_full survive day switches and Cover jumps.
  # Overrides win; nil values drop out.
  def coverage_link_params(overrides = {})
    {
      around: @around_days.presence&.map(&:iso8601),
      hide_full: (@hide_full ? "1" : nil)
    }.merge(overrides).compact
  end

  # 120 -> "2h", 90 -> "1h 30m", 45 -> "45m"
  def coverage_duration(minutes)
    hours, mins = minutes.divmod(60)
    return "#{mins}m" if hours.zero?
    return "#{hours}h" if mins.zero?

    "#{hours}h #{mins}m"
  end
  # Classifies a single timeslot cell for a volunteer, so the wide table and the
  # collapsed mobile view render identical status/badge logic.
  SlotStatus = Struct.new(:state, :missing_quals, keyword_init: true) do
    def signed_up? = state == :signed_up
    def unqualified? = state == :unqualified
    def full? = state == :full
    def needs_staff? = state == :needs_staff
    def partial? = state == :partial

    # A slot the current user can actually sign up for.
    def signable? = state == :needs_staff || state == :partial

    # CSS modifier appended to the table cell / collapsed row.
    def css_modifier
      {
        signed_up: "user-signed-up",
        full: "slot-full",
        needs_staff: "slot-empty",
        partial: "slot-partial",
        unqualified: "slot-unqualified"
      }[state]
    end
  end

  # Returns a SlotStatus for the given slot_data, or nil when there is no slot.
  # Precedence matches the original table logic: a slot the user is signed up for
  # always reads as "signed up", even if they lack a qualification.
  def slot_status(slot_data, program_id, program_qualifications:, user_qualification_ids:, user_signups:)
    return nil unless slot_data

    missing_quals = (program_qualifications[program_id] || []).reject do |qual|
      user_qualification_ids.include?(qual.id)
    end
    signed_up = user_signups.include?(slot_data[:timeslot].id)

    state =
      if signed_up
        :signed_up
      elsif missing_quals.any?
        :unqualified
      elsif slot_data[:full]
        :full
      elsif slot_data[:signed_up_count].zero?
        :needs_staff
      else
        :partial
      end

    SlotStatus.new(state: state, missing_quals: missing_quals)
  end
end
