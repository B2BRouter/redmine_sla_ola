# frozen_string_literal: true

require 'rails_helper'

RSpec.describe LevelAgreementPolicy, type: :model do
  let(:project) { Project.create!(name: 'Test Project', identifier: 'test-project') }

  describe 'validations' do
    it 'is valid with all required attributes' do
      policy = described_class.new(
        name: 'Standard SLA',
        project: project,
        products: ['basic'],
        sla_delay: 60,
        ola_delay: 120
      )
      expect(policy).to be_valid
    end

    it 'is invalid without project' do
      policy = described_class.new(name: 'No Project')
      expect(policy).not_to be_valid
      expect(policy.errors[:project].join).to match(/blank/)
    end
  end

  describe '#business_time_hours_between' do
    let(:start_time) { Time.parse('2024-07-18 10:00') }
    let(:end_time)   { Time.parse('2024-07-18 12:00') }

    it 'returns full duration when no business hours are set (24/7)' do
      policy = described_class.new
      expect(policy.business_time_hours_between(start_time, end_time)).to eq 2
    end

    it 'calculates minutes only within business hours' do
      policy = described_class.new(
        business_hours_start: '09:00',
        business_hours_end: '17:00',
        business_days: '1,2,3,4,5'
      )

      expect(policy.business_time_hours_between(start_time, end_time)).to eq 2
    end

    it 'returns only overlapping minutes when partially outside business hours' do
      policy = described_class.new(
        business_hours_start: '09:00',
        business_hours_end: '17:00',
        business_days: '1,2,3,4,5'
      )

      from = Time.parse('2024-07-18 16:00')
      to   = Time.parse('2024-07-18 18:00')
      expect(policy.business_time_hours_between(from, to)).to eq 1
    end

    it 'skips weekends when business days exclude them' do
      policy = described_class.new(
        business_hours_start: '09:00',
        business_hours_end: '17:00',
        business_days: '1,2,3,4,5'
      )

      from = Time.parse('2024-07-19 16:00')
      to   = Time.parse('2024-07-22 10:00')
      expect(policy.business_time_hours_between(from, to)).to eq 2
    end

    it 'allows 24h service on working days' do
      policy = described_class.new(
        business_days: '1,2,3,4,5'
      )

      from = Time.parse('2024-07-19 16:00')
      to   = Time.parse('2024-07-22 10:00')
      expect(policy.business_time_hours_between(from, to)).to eq 18
    end

    it 'allows 24/7 service' do
      policy = described_class.new

      from = Time.parse('2024-07-19 16:00')
      to   = Time.parse('2024-07-22 10:00')
      expect(policy.business_time_hours_between(from, to)).to eq 66
    end
  end
end
