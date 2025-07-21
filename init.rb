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
  unless IssueQuery.included_modules.include?(RedmineSlaOla::IssueQueryPatch)
    IssueQuery.include RedmineSlaOla::IssueQueryPatch
  end
  puts "Patching QueriesHelper..."
  unless QueriesHelper.included_modules.include?(RedmineSlaOla::QueriesHelperPatch)
    QueriesHelper.include RedmineSlaOla::QueriesHelperPatch
    puts "QueriesHelper Patched"
  end
end