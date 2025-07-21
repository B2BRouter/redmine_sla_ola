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
        matched_issue_ids = []
        policies = LevelAgreementPolicy.all.to_a
        custom_field_products_id = CustomField.find_by(name: 'Products')&.id

        return '1=0' if custom_field_products_id.nil?

        Issue.where(first_reply: false).find_each do |issue|
          products = issue.custom_field_value(custom_field_products_id)
          next unless issue.created_on && products.any?

          policy = policies.find { |p| (p.products & products).any? }
          next unless policy && policy.send(delay_type)

          hours_elapsed = policy.business_time_hours_between(issue.created_on, Time.current)
          breached = hours_elapsed > policy.send(delay_type)

          matched_issue_ids << issue.id if breached
        end

        case operator
        when '='
          if value.include?('1')
            return matched_issue_ids.any? ? "issues.id IN (#{matched_issue_ids.uniq.join(',')})" : '1=0'
          elsif value.include?('0')
            return matched_issue_ids.any? ? "issues.id NOT IN (#{matched_issue_ids.uniq.join(',')})" : '1=1'
          end
        when '!'
          if value.include?('1')
            return matched_issue_ids.any? ? "issues.id NOT IN (#{matched_issue_ids.uniq.join(',')})" : '1=1'
          elsif value.include?('0')
            return matched_issue_ids.any? ? "issues.id IN (#{matched_issue_ids.uniq.join(',')})" : '1=0'
          end
        end

        '1=0'  # fallback: no matching operator
      end
    end
  end
end
