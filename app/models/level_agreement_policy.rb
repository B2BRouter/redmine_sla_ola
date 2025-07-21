class LevelAgreementPolicy < ActiveRecord::Base
  belongs_to :project, :class_name => 'Project', :foreign_key => 'project_id'

  serialize :products, type: Array

  validates_presence_of :project
  validates_numericality_of :sla_delay, :ola_delay, :allow_nil => true

  def business_time_hours_between(start_time, end_time)
    days = business_days&.split(',')&.map(&:to_i) || (0..6).to_a

    if business_hours_start.nil? || business_hours_end.nil?
      total_seconds = 0
      current_time = start_time

      while current_time < end_time
        if days.include?(current_time.wday)
          period_end = [end_time, current_time.end_of_day].min
          total_seconds += (period_end - current_time)
        end
        current_time = (current_time + 1.day).beginning_of_day
      end

      return (total_seconds / 3600.0).round(2)
    end

    total_minutes = 0
    current_time = start_time
    business_start = business_hours_start
    business_end   = business_hours_end

    while current_time < end_time
      if days.include?(current_time.wday)
        day_start = current_time.change(hour: business_start.hour, min: business_start.min)
        day_end   = current_time.change(hour: business_end.hour, min: business_end.min)

        period_start = [current_time, day_start].max
        period_end   = [end_time, day_end].min

        if period_start < period_end
          total_minutes += ((period_end - period_start) / 60).to_i
        end
      end

      current_time = (current_time + 1.day).beginning_of_day
    end

    (total_minutes.to_f / 60).round(2)
  end
end
