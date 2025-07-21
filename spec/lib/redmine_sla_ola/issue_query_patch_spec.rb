# frozen_string_literal: true

require 'rails_helper'

RSpec.describe RedmineSlaOla::IssueQueryPatch do
  let(:query_class) { Class.new(IssueQuery).prepend(described_class::InstanceMethods) }

  let!(:author)  { User.create!(login: 'testuser', firstname: 'Test', lastname: 'User', mail: 'test@example.com') }
  let!(:priority){ IssuePriority.create!(name: 'Normal', is_default: true, active: true) }
  let!(:status)  { IssueStatus.create!(name: 'New', is_closed: false) }

  let!(:tracker) do
    Tracker.create!(
      name: 'Bug',
      default_status: status
    ).tap { |t| t.issue_statuses << status }
  end

  let!(:project) do
    Project.create!(name: 'Test Project', identifier: 'test-project').tap do |p|
      p.trackers << tracker unless p.trackers.include?(tracker)
    end
  end

  let!(:cf_products) do
    IssueCustomField.create!(
      name: 'Products',
      field_format: 'list',
      is_for_all: true,
      multiple: true,
      possible_values: ['basic', 'pro']
    ).tap do |cf|
      cf.projects << project unless cf.projects.include?(project)
      cf.trackers << tracker unless cf.trackers.include?(tracker)
    end
  end

  let!(:issue) do
    Issue.create!(
      project: project,
      tracker: tracker,
      author: author,
      subject: 'Test issue',
      first_reply: false,
      custom_field_values: { cf_products.id => ['basic'] }
    )
  end

  let!(:sla_policy) do
    LevelAgreementPolicy.create!(
      name: 'Basic SLA',
      project: project,
      products: ['basic'],
      sla_delay: 2,
      business_hours_start: '00:00',
      business_hours_end: '23:59',
      business_days: '0,1,2,3,4,5,6'
    )
  end

  before do
    issue.update_column(:created_on, 3.hours.ago)
    IssueQuery.include RedmineSlaOla::IssueQueryPatch unless IssueQuery.included_modules.include?(RedmineSlaOla::IssueQueryPatch)
  end

  describe '#sql_for_sla_breached_field' do
    it 'returns issue ID when SLA is breached' do
      issue_id = issue.id.to_s
      query = IssueQuery.new
      sql = query.sql_for_sla_breached_field('sla_breached', '=', ['1'])

      expect(sql).to include("issues.id IN")
      expect(sql).to include(issue_id)
    end

    it 'does not return issue ID when SLA is not breached' do
      sla_policy.update!(sla_delay: 5)

      query = IssueQuery.new
      sql = query.sql_for_sla_breached_field('sla_breached', '=', ['1'])

      expect(sql).not_to include(issue.id.to_s)
    end
  end
end
