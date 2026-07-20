module ApplicationHelper
  # A person's Display Name with their callsign appended when they have one,
  # e.g. "Radio Ray (W1AW)". Use this wherever we identify a volunteer.
  def display_name_with_callsign(user)
    if user.callsign.present?
      "#{user.display_name} (#{user.callsign})"
    else
      user.display_name
    end
  end
end
