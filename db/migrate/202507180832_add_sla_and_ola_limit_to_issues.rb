class AddSlaAndOlaLimitToIssues < ActiveRecord::Migration[5.1]
  def change
    add_column :issues, :sla_limit, :timestamp, after: :lock_version, default: nil
    add_column :issues, :ola_limit, :timestamp, after: :sla_limit, default: nil
  end
end
