require 'redmine'

Redmine::Plugin.register :redmine_sla_ola do
  name 'Redmine SLA OLA'
  author 'Noah Bobis Ramos'
  description 'Defines SLA and OLA time delays for support tickets'
  version '1.0.0'
  requires_redmine version_or_higher: '5.0.0'

  settings default: { 'show_count_projects' => [] }
end

require File.expand_path('lib/redmine_sla_ola', __dir__)

RedmineApp::Application.config.after_initialize do
  unless Issue.included_modules.include?(RedmineSlaOla::IssueSlaOlaPatch)
    Issue.include RedmineSlaOla::IssueSlaOlaPatch
  end
  unless Journal.included_modules.include?(RedmineSlaOla::JounalSlaOlaPatch)
    Journal.include RedmineSlaOla::JounalSlaOlaPatch
  end
  unless IssueQuery.included_modules.include?(RedmineSlaOla::IssueQueryPatch)
    IssueQuery.include RedmineSlaOla::IssueQueryPatch
  end
  unless QueriesHelper.included_modules.include?(RedmineSlaOla::QueriesHelperPatch)
    QueriesHelper.include RedmineSlaOla::QueriesHelperPatch
  end
end