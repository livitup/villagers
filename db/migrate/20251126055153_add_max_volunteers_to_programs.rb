class AddMaxVolunteersToPrograms < ActiveRecord::Migration[8.1]
  def change
    add_column :programs, :max_volunteers, :integer, default: 1, null: false
    # Make conference_program.max_volunteers nullable so it can inherit from program
    change_column_null :conference_programs, :max_volunteers, true
    change_column_default :conference_programs, :max_volunteers, nil
  end
end
