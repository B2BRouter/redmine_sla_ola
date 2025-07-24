# frozen_string_literal: true

require 'rails_helper'

RSpec.describe RedmineSlaOla::IssueQueryPatch do
  include ActiveSupport::Testing::TimeHelpers
  let(:query_class) { Class.new(IssueQuery).prepend(described_class::InstanceMethods) }
  self.fixture_path = Rails.root.join('plugins', 'redmine_sla_ola', 'spec', 'fixtures')

  fixtures :users, :issue_priorities, :issue_statuses, :trackers, :projects, :custom_fields, :custom_values,
           :issues, :level_agreement_policies, :journals

  let(:issue) { issues(:issue_a) }
  let(:query) { IssueQuery.new(project: projects(:projects_001)) }

  before { IssueQuery.include RedmineSlaOla::IssueQueryPatch unless IssueQuery.included_modules.include?(RedmineSlaOla::IssueQueryPatch) }

  describe '#sql_for_sla_breached_field' do
    around do |example|
      travel_to Time.zone.parse('2025-07-24 17:00') do
        example.run
      end
    end

    context 'issue with immediate level_agreement_policy (1h sla, 24/7)' do
      before do
        issue.custom_values
             .where(custom_field_id: custom_fields(:products_field).id)
             .first
             .update_column(:value, 'product_immediate')
      end

      context 'journal created by excluded user is ignored for SLA breach' do
        before do
          Setting.plugin_redmine_sla_ola = { 'excluded_journal_user_ids' => [users(:users_001).id] }
          journals(:journal_001).update_column(:created_on, 2.hours.ago)
        end

        it 'includes the issue as SLA breached because journal is from excluded user' do
          sql = query.sql_for_sla_breached_field('sla_breached', '=', ['1'])
          expect(sql).to eq(query.sql_for_sla_breached_field('sla_breached', '!', ['0']))
          expect(sql).to include(issue.id.to_s)
        end

        it 'does not include issue as not breached (!)' do
          sql = query.sql_for_sla_breached_field('sla_breached', '!', ['1'])
          expect(sql).to eq(query.sql_for_sla_breached_field('sla_breached', '=', ['0']))
          expect(sql).not_to include(issue.id.to_s)
        end
      end

      it 'returns issue ID when SLA is breached' do
        issue.update_column(:created_on, 2.hours.ago)
        sql = query.sql_for_sla_breached_field('sla_breached', '=', ['1'])
        expect(sql).to eq(query.sql_for_sla_breached_field('sla_breached', '!', ['0']))
        expect(sql).to include(issue.id.to_s)
      end

      it 'does not return issue ID when SLA is not breached' do
        issue.update_column(:created_on, 30.minutes.ago)
        sql = query.sql_for_sla_breached_field('sla_breached', '=', ['1'])
        expect(sql).to eq(query.sql_for_sla_breached_field('sla_breached', '!', ['0']))
        expect(sql).not_to include(issue.id.to_s)
      end

      it 'excludes breached issue ID when asking for not breached' do
        issue.update_column(:created_on, 2.hours.ago)
        sql = query.sql_for_sla_breached_field('sla_breached', '!', ['1'])
        expect(sql).to eq(query.sql_for_sla_breached_field('sla_breached', '=', ['0']))
        expect(sql).not_to include(issue.id.to_s)
      end

      it 'includes issue ID when SLA is not breached' do
        issue.update_column(:created_on, 30.minutes.ago)
        sql = query.sql_for_sla_breached_field('sla_breached', '!', ['1'])
        expect(sql).to eq(query.sql_for_sla_breached_field('sla_breached', '=', ['0']))
        expect(sql).to include(issue.id.to_s)
      end
    end

    context 'issue with urgent level_agreement_policy (6h sla, monday to friday, 9:00 to 18:00)' do
      before do
        issue.custom_values
             .where(custom_field_id: custom_fields(:products_field).id)
             .first
             .update_column(:value, 'product_urgent')
      end

      it 'returns issue ID when SLA is breached' do
        issue.update_column(:created_on, 7.hours.ago)
        sql = query.sql_for_sla_breached_field('sla_breached', '=', ['1'])
        expect(sql).to eq(query.sql_for_sla_breached_field('sla_breached', '!', ['0']))
        expect(sql).to include(issue.id.to_s)
      end

      it 'does not return issue ID when SLA is not breached' do
        issue.update_column(:created_on, 2.hours.ago.change(hour: 11))
        sql = query.sql_for_sla_breached_field('sla_breached', '=', ['1'])
        expect(sql).to eq(query.sql_for_sla_breached_field('sla_breached', '!', ['0']))
        expect(sql).not_to include(issue.id.to_s)
      end

      it 'excludes breached issue ID when asking for not breached' do
        issue.update_column(:created_on, 7.hours.ago)
        sql = query.sql_for_sla_breached_field('sla_breached', '!', ['1'])
        expect(sql).to eq(query.sql_for_sla_breached_field('sla_breached', '=', ['0']))
        expect(sql).not_to include(issue.id.to_s)
      end

      it 'includes not-breached issue ID when asking for not breached' do
        issue.update_column(:created_on, 2.hours.ago.change(hour: 11))
        sql = query.sql_for_sla_breached_field('sla_breached', '!', ['1'])
        expect(sql).to eq(query.sql_for_sla_breached_field('sla_breached', '=', ['0']))
        expect(sql).to include(issue.id.to_s)
      end
    end

    context 'issue with normal level_agreement_policy (no SLA delay)' do
      before do
        issue.custom_values
             .where(custom_field_id: custom_fields(:products_field).id)
             .first
             .update_column(:value, 'product_normal')
      end

      it 'never returns issue ID because it has no SLA delay' do
        issue.update_column(:created_on, 1.week.ago.change(hour: 10))
        sql = query.sql_for_sla_breached_field('sla_breached', '=', ['1'])
        expect(sql).to eq(query.sql_for_sla_breached_field('sla_breached', '!', ['0']))
        expect(sql).not_to include(issue.id.to_s)
      end

      it 'includes issue ID when querying "not breached"' do
        issue.update_column(:created_on, 1.week.ago.change(hour: 10))
        sql = query.sql_for_sla_breached_field('sla_breached', '!', ['1'])
        expect(sql).to eq(query.sql_for_sla_breached_field('sla_breached', '=', ['0']))
        expect(sql).to include(issue.id.to_s)
      end
    end
  end
end
