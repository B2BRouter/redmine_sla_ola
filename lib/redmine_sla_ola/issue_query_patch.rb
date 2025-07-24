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
        policy_by_product = LevelAgreementPolicy.where(project_id: project.id)
                                                .group_by { |p| p.products }.transform_values(&:first)
        return '1=0' if policy_by_product.empty?
        matched_issue_ids = []
        unmatched_issue_ids = []

        Issue.where(project_id: project.id).find_each do |issue|
          products = issue.custom_values.where(custom_field_id: custom_field.id).pluck(:value).flatten
          policy = policy_by_product.find { |product_list, _| (product_list & products).any? }&.last

          relevant_journal = issue.journals.detect do |journal|
            !user_ids.include?(journal.user_id) &&
              journal.notes.present? &&
              journal.private_notes == false
          end

          unless products.any? && (policy && policy.send(delay_type)) && (issue.journals.empty? || relevant_journal.nil?)
            unmatched_issue_ids << issue.id
            next
          end

          hours_elapsed = policy.business_time_hours_between(issue.created_on, Time.current)
          if hours_elapsed > policy.send(delay_type)
            matched_issue_ids << issue.id
          else
            unmatched_issue_ids << issue.id
          end
        end

        ids =
          if (operator == '=' && value.include?('1')) || (operator == '!' && value.include?('0'))
            matched_issue_ids
          else
            unmatched_issue_ids
          end

        ids.any? ? "issues.id IN (#{ids.uniq.join(',')})" : '1=0'
      end
    end
  end
end
