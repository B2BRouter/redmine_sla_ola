# frozen_string_literal: true

require 'rails_helper'

# Helper global disponible en todos los contextos
def as_time(datetime_string)
  Time.zone.parse(datetime_string).utc
end

RSpec.describe RedmineSlaOla::IssueQueryPatch do
  include ActiveSupport::Testing::TimeHelpers

  self.fixture_path = Rails.root.join('plugins', 'redmine_sla_ola', 'spec', 'fixtures')

  fixtures :users, :issue_priorities, :issue_statuses, :trackers, :projects,
           :custom_fields, :custom_values, :issues, :level_agreement_policies, :journals

  let(:issue) { issues(:issue_a) }
  let(:query) { IssueQuery.new(project: projects(:projects_001)) }

  def sql_with_frozen_now(sql, current_time)
    sql.gsub('CURRENT_TIMESTAMP', "'#{current_time}'")
  end

  before do
    IssueQuery.include RedmineSlaOla::IssueQueryPatch unless IssueQuery.included_modules.include?(RedmineSlaOla::IssueQueryPatch)
  end

  shared_examples 'SLA breached check' do |created_on_string:, expected_breached:, current_time: '2025-07-24 17:00:00'|
    it "returns #{expected_breached ? '' : 'no '}results when SLA is #{expected_breached ? 'breached' : 'not breached'}" do
      issue.update_column(:created_on, as_time(created_on_string))
      sql = sql_with_frozen_now(query.sql_for_sla_breached_field('sla_breached', '=', ['1']), current_time)
      result_ids = Issue.where(sql).pluck(:id)
      expect(result_ids.include?(issue.id)).to eq(expected_breached)
    end

    it "returns #{expected_breached ? 'no ' : ''}results when querying 'not breached'" do
      issue.update_column(:created_on, as_time(created_on_string))
      sql = sql_with_frozen_now(query.sql_for_sla_breached_field('sla_breached', '!', ['1']), current_time)
      result_ids = Issue.where(sql).pluck(:id)
      expect(result_ids.include?(issue.id)).to eq(!expected_breached)
    end
  end

  describe '#sql_for_sla_breached_field' do
    context 'with immediate policy (1h SLA, 24/7)' do
      before do
        issue.custom_values.where(custom_field_id: custom_fields(:products_field).id)
             .first.update_column(:value, 'product_immediate')
      end

      context 'journal from excluded user' do
        before do
          Setting.plugin_redmine_sla_ola = { 'excluded_journal_user_ids' => [users(:users_001).id] }
          journals(:journal_001).update_column(:created_on, as_time('2025-07-24 15:00 +0200'))
          issue.update_column(:created_on, as_time('2025-07-24 15:00 +0200'))
        end

        include_examples 'SLA breached check', created_on_string: '2025-07-24 15:00 +0200', expected_breached: true
      end

      include_examples 'SLA breached check', created_on_string: '2025-07-24 15:00 +0200', expected_breached: true
      include_examples 'SLA breached check', created_on_string: '2025-07-24 16:30 +0200', expected_breached: false
    end

    context 'with urgent policy (6h SLA, business hours)' do
      before do
        issue.custom_values.where(custom_field_id: custom_fields(:products_field).id)
             .first.update_column(:value, 'product_urgent')
      end

      include_examples 'SLA breached check', created_on_string: '2025-07-24 10:00 +0200', expected_breached: true
      include_examples 'SLA breached check', created_on_string: '2025-07-24 15:00 +0200', expected_breached: false

      context 'created at night (fuera de horario)' do
        include_examples 'SLA breached check',
                         created_on_string: '2025-07-23 23:00 +0200',
                         current_time: '2025-07-24 11:00',
                         expected_breached: false
      end

      context 'created on weekend (fuera de días laborales)' do
        include_examples 'SLA breached check',
                         created_on_string: '2025-07-26 10:00 +0200',
                         expected_breached: false
      end

      context 'created before horario laboral, pero pasan 6h laborales' do
        include_examples 'SLA breached check',
                         created_on_string: '2025-07-24 08:00 +0200',
                         expected_breached: true
      end

      context 'created justo al final del horario laboral' do
        include_examples 'SLA breached check',
                         created_on_string: '2025-07-24 17:59 +0200',
                         expected_breached: false
      end

      context 'created el viernes por la tarde, termina el lunes' do
        include_examples 'SLA breached check',
                         created_on_string: '2025-07-25 17:00 +0200',
                         expected_breached: false
      end
    end

    context 'with normal policy (no SLA delay)' do
      before do
        issue.custom_values.where(custom_field_id: custom_fields(:products_field).id)
             .first.update_column(:value, 'product_normal')
      end

      include_examples 'SLA breached check', created_on_string: '2025-07-17 17:00 +0200', expected_breached: false
    end
  end
end
