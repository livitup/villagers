class UpdateTimeslotCapacityJob < ApplicationJob
  queue_as :default

  # new_min_volunteers is optional so jobs queued before the coverage band
  # existed (#259) still run; without it, each slot keeps its min, clamped
  # down to the new max.
  def perform(conference_program_id, new_max_volunteers, new_min_volunteers = nil)
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

      new_min = [ new_min_volunteers || timeslot.min_volunteers, new_max_volunteers ].min
      timeslot.update!(min_volunteers: new_min, max_volunteers: new_max_volunteers)
      updated_count += 1
    end

    { updated: updated_count, skipped: skipped_count }
  end
end
