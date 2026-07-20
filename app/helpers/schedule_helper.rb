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
end
