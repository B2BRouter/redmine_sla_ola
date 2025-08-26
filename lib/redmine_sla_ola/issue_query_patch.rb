module RedmineSlaOla
  module IssueQueryPatch
    def self.included(base)
      base.prepend InstanceMethods
    end

    module InstanceMethods
      def initialize_available_filters
        super

        add_available_filter 'sla_breached',
                             type: :list,
                             name: l(:label_attribute_sla_breached),
                             values: [[l(:general_text_yes), '1'], [l(:general_text_no), '0']]

        add_available_filter 'ola_breached',
                             type: :list,
                             name: l(:label_attribute_ola_breached),
                             values: [[l(:general_text_yes), '1'], [l(:general_text_no), '0']]
      end

      def sql_for_sla_breached_field(_field, operator, value)
        sql_for_breached_datetime(:sla_limit, operator, value)
      end

      def sql_for_ola_breached_field(_field, operator, value)
        sql_for_breached_datetime(:ola_limit, operator, value)
      end

      private

      def sql_for_breached_datetime(column, operator, value)
        breached_sql = <<~SQL
          issues.id IN (
            SELECT issues.id
            FROM issues
            INNER JOIN issue_statuses ON issue_statuses.id = issues.status_id
            WHERE issue_statuses.is_closed = false
              AND issues.#{column} IS NOT NULL
              AND issues.#{column} <= '#{Time.now}'
          )
        SQL

        not_breached_sql = <<~SQL
          issues.id IN (
            SELECT issues.id
            FROM issues
            INNER JOIN issue_statuses ON issue_statuses.id = issues.status_id
            WHERE issue_statuses.is_closed = false
              AND (issues.#{column} IS NULL OR issues.#{column} > '#{Time.now}')
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
