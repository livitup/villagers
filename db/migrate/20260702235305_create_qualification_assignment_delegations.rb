class CreateQualificationAssignmentDelegations < ActiveRecord::Migration[8.1]
  def change
    create_table :qualification_assignment_delegations do |t|
      t.references :user, null: false, foreign_key: true
      t.references :qualification, null: false, foreign_key: true
      t.references :conference, null: false, foreign_key: true

      t.timestamps
    end

    add_index :qualification_assignment_delegations,
              [ :user_id, :qualification_id, :conference_id ],
              unique: true,
              name: "index_qualification_delegations_unique"
  end
end
