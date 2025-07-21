# Redmine SLA OLA plugin

###### A Redmine plugin that allows assigning SLA (Service Level Agreement) and OLA (Operational Level Agreement) by product and project.
###### It adds new filters to the issue list to identify which issues are SLA/OLA compliant or non-compliant.

## Installation

   1. Navigate to your Redmine root folder
      (example: cd /var/www/html/redmine)
   2. Clone the plugin into the plugins directory
      git clone https://github.com/noahlio/redmine_sla_ola.git plugins
   3. Run the plugin migrations
      bundle exec rake redmine:plugins:migrate NAME=redmine_sla_ola RAILS_ENV=production
   4. Restart the web server
      sudo service apache2 restart

## How to use

   1. Create LevelAgreementPolicy records from the Rails console
      rails console
   2. Go to Issues and use the new SLA and OLA filters to find compliant and non-compliant issues.

## Considerations

   1. Issues must have a custom field called products (as a string), which is used to match against the products defined in each LevelAgreementPolicy. 
   2. Issues must have a boolean field called first_reply that indicates whether the issue has already received a first response.
   3. To show a counter to the right of the query issues set the plugin_redmine_sla_ola/show_count_projects configuration with the projects identifiers:
      - Setting.plugin_redmine_sla_ola = {'show_count_projects' => ['b2brouter-suport'] }
   4. If plugin_redmine_sla_ola/show_count_projects is equal to ['all'] all the projects show the issue counter at his query issues:
      - Setting.plugin_redmine_sla_ola = {'show_count_projects' => ['all'] }
