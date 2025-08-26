
module RedmineSlaOla
  module JounalSlaOlaPatch
    def self.included(base)
      base.class_eval do
        after_create :check_and_reset_sla_ola_limits
      end
    end

    private

    def check_and_reset_sla_ola_limits
      return unless self.journalized.is_a?(Issue)

      issue = self.journalized

      excluded_ids = Array(Setting.plugin_redmine_sla_ola['excluded_journal_user_ids']).map(&:to_i)

      if issue && (issue.sla_limit.present? || issue.ola_limit.present?) && !excluded_ids.include?(self.user_id)
        issue.update_columns(
          sla_limit: nil,
          ola_limit: nil
        )
      end
    end
  end
end
