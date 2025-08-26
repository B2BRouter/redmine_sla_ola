require 'rails_helper'

def as_time(datetime_string)
  Time.zone.parse(datetime_string).utc
end

RSpec.describe 'Issue SLA/OLA limits on create' do
  include ActiveSupport::Testing::TimeHelpers

  self.fixture_path = Rails.root.join('plugins', 'redmine_sla_ola', 'spec', 'fixtures')

  fixtures :users, :issue_priorities, :issue_statuses, :trackers, :projects,
           :custom_fields, :custom_values, :issues, :level_agreement_policies

  let(:issue) { issues(:issue_a) }
  let(:project) { projects(:projects_001) }
  let(:author)  { users(:users_001) }
  let(:tracker) { trackers(:trackers_003) }
  let(:prod_cf) { custom_fields(:products_field) }

  before do
    project.trackers << tracker unless project.trackers.include?(tracker)
  end

  def build_issue_with_product(product_value, attributes = {})
    issue = Issue.new({
                        project: project,
                        tracker: tracker,
                        author:  author,
                        subject: "Spec - #{product_value}",
                        priority: IssuePriority.first
                      }.merge(attributes))
    issue.custom_values << CustomValue.new(customized: issue, value: product_value, custom_field: prod_cf)
    issue
  end

  def policy_for(product_value)
    LevelAgreementPolicy
      .where(project_id: project.id)
      .where('products LIKE ?', "%- #{product_value}%")
      .first
  end

  describe 'OLA/SLA assignation' do
    shared_examples 'assigns limits for product' do |product:, travel_time:, expected_sla:, expected_ola:|
      it "asigna límites correctos para #{product} en #{travel_time}" do
        travel_to Time.zone.parse(travel_time) do
          pol = policy_for(product)
          expect(pol).to be_present

          issue = build_issue_with_product(product)
          issue.save!
          issue.reload

          expect(issue.sla_limit).to be_within(1.second).of(as_time(expected_sla)) if expected_sla.present?
          expect(issue.ola_limit).to be_within(1.second).of(as_time(expected_ola))
        end
      end
    end

    include_examples 'assigns limits for product',
                     product:      'product_immediate',
                     travel_time:  '2025-07-24 15:00',
                     expected_sla: '2025-07-24 16:00',
                     expected_ola: '2025-07-24 15:30'

    include_examples 'assigns limits for product',
                     product:      'product_urgent',
                     travel_time:  '2025-07-24 10:00',
                     expected_sla: '2025-07-24 16:00',
                     expected_ola: '2025-07-24 13:00'

    include_examples 'assigns limits for product',
                     product:      'product_high',
                     travel_time:  '2025-07-24 10:00',
                     expected_sla: '2025-07-25 13:00',
                     expected_ola: '2025-07-24 16:00'

    include_examples 'assigns limits for product',
                     product:      'product_normal',
                     travel_time:  '2025-07-21 09:00',
                     expected_sla: nil,
                     expected_ola: '2025-07-23 15:00'
  end

  describe 'OLA/SLA elimination on new journal helpdesk' do
    let(:admin)   { users(:users_001) }
    let(:excluded_user) { users(:api_user) }
    let(:issue) {
      travel_to Time.zone.parse('2025-07-21 09:00') do
        build_issue_with_product('product_immediate', sla_limit: '2025-07-24 16:00', ola_limit: '2025-07-24 15:30')
      end
    }

    context 'api user excluded from jounal users' do
      before do
        Setting.plugin_redmine_sla_ola['excluded_journal_user_ids'] = [2]
      end

      it 'preserve ola/sla limits on journal created by excluded user' do
        expect(issue.sla_limit).to be_present
        expect(issue.ola_limit).to be_present

        Journal.create!(journalized: issue,
                        user: excluded_user,
                        notes: 'Excluded user comment')

        issue.reload
        expect(issue.sla_limit).to be_present
        expect(issue.ola_limit).to be_present
      end

      it 'remove ola/sla limits on journal created by a non excluded user' do
        expect(issue.sla_limit).to be_present
        expect(issue.ola_limit).to be_present

        Journal.create!(journalized: issue,
                        user: admin,
                        notes: 'Normal user comment')

        issue.reload
        expect(issue.sla_limit).to be_nil
        expect(issue.ola_limit).to be_nil
      end
    end
  end
end
