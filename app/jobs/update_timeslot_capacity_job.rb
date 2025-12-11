class UpdateTimeslotCapacityJob < ApplicationJob
  queue_as :default

  def perform(conference_program_id, new_max_volunteers)
    conference_program = ConferenceProgram.find_by(id: conference_program_id)
    return { updated: 0, skipped: 0 } unless conference_program

    updated_count = 0
    skipped_count = 0

    conference_program.timeslots.find_each do |timeslot|
      # Don't reduce capacity below current signups
      if timeslot.current_volunteers_count > new_max_volunteers
        skipped_count += 1
        next
      end

      timeslot.update!(max_volunteers: new_max_volunteers)
      updated_count += 1
    end

    { updated: updated_count, skipped: skipped_count }
  end
end
