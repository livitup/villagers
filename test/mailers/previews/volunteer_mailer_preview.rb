class VolunteerMailerPreview < ActionMailer::Preview
  # Preview: http://localhost:3000/rails/mailers/volunteer_mailer/shift_signup_confirmation
  def shift_signup_confirmation
    user, conference, signups = build_preview_data
    VolunteerMailer.shift_signup_confirmation(
      user: user,
      signups: signups,
      conference: conference
    )
  end

  # Preview: http://localhost:3000/rails/mailers/volunteer_mailer/shift_reminder
  def shift_reminder
    user, conference, signups = build_preview_data
    VolunteerMailer.shift_reminder(
      user: user,
      signups: signups,
      conference: conference
    )
  end

  # Preview: http://localhost:3000/rails/mailers/volunteer_mailer/admin_signup_notification
  def admin_signup_notification
    admin = User.first || User.new(email: "admin@example.com", handle: "Conference Admin")
    volunteer = User.second || User.new(email: "volunteer@example.com", handle: "New Volunteer")
    conference = Conference.first || Conference.new(
      name: "Preview Conference",
      city: "Las Vegas",
      state: "NV",
      country: "US"
    )
    program = Program.first || Program.new(name: "Preview Program")
    conference_program = ConferenceProgram.new(conference: conference, program: program)
    timeslot = Timeslot.new(
      conference_program: conference_program,
      start_time: Time.current.beginning_of_day + 10.hours,
      max_volunteers: 5,
      current_volunteers_count: 2
    )
    signup = VolunteerSignup.new(user: volunteer, timeslot: timeslot)

    VolunteerMailer.admin_signup_notification(
      admin: admin,
      volunteer: volunteer,
      signup: signup,
      conference: conference
    )
  end

  private

  def build_preview_data
    user = User.first || User.new(email: "preview@example.com", handle: "Preview User")
    conference = Conference.first || Conference.new(
      name: "Preview Conference",
      city: "Las Vegas",
      state: "NV",
      country: "US"
    )
    program = Program.first || Program.new(name: "Preview Program")
    conference_program = ConferenceProgram.new(conference: conference, program: program)

    signups = 3.times.map do |i|
      timeslot = Timeslot.new(
        conference_program: conference_program,
        start_time: Time.current.beginning_of_day + 10.hours + (i * 15).minutes,
        max_volunteers: 5
      )
      VolunteerSignup.new(user: user, timeslot: timeslot)
    end

    [ user, conference, signups ]
  end
end
