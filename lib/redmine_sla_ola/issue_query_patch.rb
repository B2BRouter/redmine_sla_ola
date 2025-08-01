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

        excluded_user_ids = Array(Setting.plugin_redmine_sla_ola['excluded_journal_user_ids']).map(&:to_i)
        excluded_user_condition =
          if excluded_user_ids.any?
            "AND j.user_id NOT IN (#{excluded_user_ids.join(',')})"
          else
            ""
          end

        delay_column = delay_type == :sla_delay ? 'sla_delay' : 'ola_delay'

        breached_sql = <<~SQL
          issues.id IN (
            SELECT issues.id FROM issues
            INNER JOIN issue_statuses ON issue_statuses.id = issues.status_id
            INNER JOIN custom_values cv ON cv.customized_type = 'Issue'
              AND cv.customized_id = issues.id
              AND cv.custom_field_id = #{custom_field.id}
            INNER JOIN level_agreement_policies policies ON policies.project_id = issues.project_id
              AND policies.products LIKE CONCAT('%- ', cv.value, '%')
            WHERE issue_statuses.is_closed = false AND (
              CASE
                WHEN policies.business_hours_start IS NULL OR policies.business_hours_end IS NULL OR policies.business_days IS NULL THEN
                  TIMESTAMPDIFF(
                    SECOND,
                    issues.created_on,
                    COALESCE(
                      (
                        SELECT MIN(j.created_on) FROM journals j
                        WHERE j.journalized_type = 'Issue'
                          AND j.journalized_id = issues.id
                          #{excluded_user_condition}
                          AND j.private_notes = false
                          AND j.notes IS NOT NULL AND j.notes != ''
                      ),
                      CURRENT_TIMESTAMP
                    )
                  ) / 3600.0
                ELSE
                  working_hours_between(
                    issues.created_on,
                    COALESCE(
                      (
                        SELECT MIN(j.created_on) FROM journals j
                        WHERE j.journalized_type = 'Issue'
                          AND j.journalized_id = issues.id
                          #{excluded_user_condition}
                          AND j.private_notes = false
                          AND j.notes IS NOT NULL AND j.notes != ''
                      ),
                      CURRENT_TIMESTAMP
                    ),
                    policies.business_hours_start,
                    policies.business_hours_end,
                    policies.business_days
                  )
              END
            ) >= policies.#{delay_column}
          )
        SQL

        def extract_subquery_body(sql_in_clause)
          sql_in_clause.strip[/\Aissues\.id IN \((.*)\)\z/m, 1]
        end

        not_breached_sql = <<~SQL
          issues.id NOT IN (
            #{extract_subquery_body(breached_sql)}
          )
        SQL

        if (operator == '=' && value.include?('1')) || (operator == '!' && value.include?('0'))
          breached_sql.strip
        else
          not_breached_sql.strip
        end
      end
    end
  end
end
