# frozen_string_literal: true

require 'rails_helper'

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

  before do
    IssueQuery.include RedmineSlaOla::IssueQueryPatch unless IssueQuery.included_modules.include?(RedmineSlaOla::IssueQueryPatch)
  end

  shared_examples 'breached check' do |field:, expected_breached:|
    it "returns #{expected_breached ? '' : 'no '}results when #{field.upcase} is #{expected_breached ? 'breached' : 'not breached'}" do
      sql = query.public_send("sql_for_#{field}_breached_field", "#{field}_breached", '=', ['1'])
      result_ids = Issue.where(sql).pluck(:id)
      expect(result_ids.include?(issue.id)).to eq(expected_breached)
    end

    it "returns #{expected_breached ? 'no ' : ''}results when querying 'not breached'" do
      sql = query.public_send("sql_for_#{field}_breached_field", "#{field}_breached", '!', ['1'])
      result_ids = Issue.where(sql).pluck(:id)
      expect(result_ids.include?(issue.id)).to eq(!expected_breached)
    end
  end

  %w[sla ola].each do |field|
    describe "#sql_for_#{field}_breached_field" do
      [
        { label: 'limit lower than actual date',   value: -> { Time.now - 1.minute }, expected: true },
        { label: 'limit equal to actual date',      value: -> { Time.now },            expected: true },
        { label: 'limit higher than actual date',    value: -> { Time.now + 1.minute }, expected: false },
        { label: 'limit nil',                       value: -> { nil },                 expected: false }
      ].each do |scenario|
        context "#{field}_#{scenario[:label]}" do
          before { issue.update_column("#{field}_limit", instance_exec(&scenario[:value])) }
          include_examples 'breached check', field: field, expected_breached: scenario[:expected]
        end
      end
    end
  end
end
