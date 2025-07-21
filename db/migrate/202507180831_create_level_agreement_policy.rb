class CreateLevelAgreementPolicy < ActiveRecord::Migration[5.1]
  def self.up
    create_table :level_agreement_policies, force: true do |t|
      t.column :project_id, :integer, null: false
      t.column :name, :string, limit: 30, default: '', null: false
      t.column :products, :text
      t.column :sla_delay, :float
      t.column :ola_delay, :float
      t.column :business_hours_start, :time
      t.column :business_hours_end, :time
      t.column :business_days, :string
    end
  end

  def self.down
    drop_table :level_agreement_policies
  end
end
