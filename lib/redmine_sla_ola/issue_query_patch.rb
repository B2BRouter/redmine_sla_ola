module RedmineSlaOla
  module IssueQueryPatch
    def self.included(base)
      base.prepend InstanceMethods
    end

    module InstanceMethods
      def initialize_available_filters
        super

        add_available_filter 'sla_breached', type: :list, name: l(:label_attribute_sla_breached), values: [[l(:general_text_yes), '1'], [l(:general_text_no), '0']]
        add_available_filter 'ola_breached', type: :list, name: l(:label_attribute_ola_breached), values: [[l(:general_text_yes), '1'], [l(:general_text_no), '0']]
      end

      def sql_for_sla_breached_field(field, operator, value)
        sql_for_breached_field(field, operator, value, :sla_delay)
      end

      def sql_for_ola_breached_field(field, operator, value)
        sql_for_breached_field(field, operator, value, :ola_delay)
      end

      private

      def sql_for_breached_field(_field, operator, value, delay_type)
        custom_field = CustomField.find_by(name: 'Products')
        return '1=0' unless custom_field

        user_ids = Setting.plugin_redmine_sla_ola['excluded_journal_user_ids']
        policies = LevelAgreementPolicy.where(project_id: project.id)
        return '1=0' if policies.empty?

        policy_by_product = {}
        policies.each do |p|
          p.products.each do |product|
            policy_by_product[product] ||= p
          end
        end

        matched_ids = []
        unmatched_ids = []

        Issue.includes(:custom_values, :journals).where(project_id: project.id).find_in_batches(batch_size: 500) do |issues|
          issues.each do |issue|
            product_values = issue.custom_values.select { |cv| cv.custom_field_id == custom_field.id }.map(&:value).flatten
            product_values = [product_values].flatten.compact

            policy = product_values.map { |p| policy_by_product[p] }.compact.first
            unless policy&.send(delay_type)
              unmatched_ids << issue.id
              next
            end

            relevant_journal = issue.journals
                                    .where.not(user_id: user_ids)
                                    .where.not(notes: [nil, ''])
                                    .where(private_notes: false)
                                    .limit(1)
                                    .first

            unless product_values.any? && policy&.send(delay_type) && (issue.journals.empty? || relevant_journal.nil?)
              unmatched_ids << issue.id
              next
            end

            hours_elapsed = policy.business_time_hours_between(issue.created_on, Time.current)
            if hours_elapsed > policy.send(delay_type)
              matched_ids << issue.id
            else
              unmatched_ids << issue.id
            end
          end
        end

        filtered_ids =
          if (operator == '=' && value.include?('1')) || (operator == '!' && value.include?('0'))
            matched_ids
          else
            unmatched_ids
          end

        filtered_ids.uniq!
        filtered_ids.any? ? "issues.id IN (#{filtered_ids.join(',')})" : '1=0'
      end

    end
  end
end
