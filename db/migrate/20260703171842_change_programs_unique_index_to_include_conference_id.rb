class ChangeProgramsUniqueIndexToIncludeConferenceId < ActiveRecord::Migration[8.1]
  # A program name only needs to be unique within a village *and conference
  # scope*: a conference-specific program may reuse a village-wide name (or a
  # name used by another conference's program). The old [village_id, name] index
  # forbade that at the DB level even though the model allowed it, causing an
  # unhandled RecordNotUnique (500) on save. Include conference_id so the index
  # matches the model's uniqueness scope.
  def change
    remove_index :programs, column: [ :village_id, :name ], unique: true,
                            name: "index_programs_on_village_id_and_name"
    add_index :programs, [ :village_id, :conference_id, :name ], unique: true,
                         name: "index_programs_on_village_id_and_conference_id_and_name"
  end
end
