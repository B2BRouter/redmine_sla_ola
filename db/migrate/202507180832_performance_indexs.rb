class PerformanceIndexs < ActiveRecord::Migration[5.1]
  def up
    add_index :journals, [:journalized_id, :journalized_type, :user_id, :private_notes],
              name: 'index_journals_for_relevant_lookup'
    add_index :level_agreement_policies, :project_id
  end

  def down
    remove_index :journals, name: 'index_journals_for_relevant_lookup'
    remove_index :level_agreement_policies, :project_id
  end
end
