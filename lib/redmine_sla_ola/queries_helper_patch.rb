module RedmineSlaOla
  module QueriesHelperPatch
    def self.included(base)
      base.prepend InstanceMethods
    end

    module InstanceMethods
      def query_links(title, queries)
        return '' if queries.empty?

        url_params =
          if controller_name == 'issues'
            { controller: 'issues', action: 'index', project_id: @project }
          else
            {}
          end

        allowed_identifiers = Array(Setting.plugin_redmine_sla_ola['show_count_projects']).map(&:strip)

        default_query_by_class = {}
        content_tag('h3', title) + "\n" +
          content_tag(
            'ul',
            queries.map do |query|
              css = +'query'
              clear_link = +''
              clear_link_param = { set_filter: 1, sort: '', project_id: @project }

              default_query =
                default_query_by_class[query.class] ||= query.class.default(project: @project)

              if query == default_query
                css << ' default'
                clear_link_param[:without_default] = 1
              end

              if query == @query
                css << ' selected'
                clear_link += link_to_clear_query(clear_link_param)
              end

              if @project && (allowed_identifiers.include?(@project.identifier) || allowed_identifiers == ['all'])
                count = query.issue_count
                label = "#{query.name} (#{count})"
              else
                label = query.name
              end

              content_tag(
                'li',
                link_to(label, url_params.merge(query_id: query), class: css) +
                  clear_link.html_safe
              )
            end.join("\n").html_safe,
            class: 'queries'
          ) + "\n"
      end
    end
  end
end
