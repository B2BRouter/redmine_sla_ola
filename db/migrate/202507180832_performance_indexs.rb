class PerformanceIndexs < ActiveRecord::Migration[5.1]
  def up
    unless index_exists?(:journals, [:journalized_id, :journalized_type, :user_id, :private_notes], name: 'index_journals_for_relevant_lookup')
      add_index :journals, [:journalized_id, :journalized_type, :user_id, :private_notes], name: 'index_journals_for_relevant_lookup'
    end
    unless index_exists?(:level_agreement_policies, :project_id)
      add_index :level_agreement_policies, :project_id
    end
  end

  def down
    if index_exists?(:journals, [:journalized_id, :journalized_type, :user_id, :private_notes], name: 'index_journals_for_relevant_lookup')
      remove_index :journals, name: 'index_journals_for_relevant_lookup'
    end
    if index_exists?(:level_agreement_policies, :project_id)
      remove_index :level_agreement_policies, :project_id
    end
  end
end
