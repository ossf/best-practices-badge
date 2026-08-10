# frozen_string_literal: true

# Generate /feed view.
# IMPORTANT: This view uses selective field loading for performance.
# If you add new fields to be displayed, be sure to add them to
# ProjectsController::FEED_DISPLAY_FIELDS. Typically the callers will
# only retrieve the fields necessary for display.
#
# We cache the feed based on projects.first.updated_at, the time of first entry.
# If there's any later activity, there will be a different time and
# this will invalidate the cache. The title depends on the locale, and
# other data might also, so the cache must be locale-specific.
#
# Disable cache for Rails.env.test?. There is a bug in the
# test framework that doesn't handle caching correctly in tests.
cache_frozen_if (!Rails.env.test? && !@projects.empty?),
                ['feed-index', I18n.locale, @projects.first.updated_at] do
  atom_feed(language: I18n.locale) do |feed|
    feed.title(t('feed_title'))
    feed.updated(@projects.first.updated_at) unless @projects.empty?

    @projects.each do |project|
      cache_frozen_if !Rails.env.test?, [project, I18n.locale] do
        feed.entry(project) do |entry|
          entry.title project.name.presence || t('project_name_unknown')
          status = "<p><strong>#{project.badge_level.titleize}"
          if project.badge_level == 'in_progress'
            status += ": #{project.badge_percentage_0}%"
          end
          status += "</strong> (Tiered #{project.tiered_percentage}%)</p>"
          url = project.homepage_url.presence || project.repo_url
          link = "<p><a href='#{url}'>#{url}</a></p>"
          description = "<span lang=\"#{ERB::Util.html_escape(project.entry_locale)}\">" +
                        markdown(project.description || '') +
                        '</span>'
          content = status + link + description
          entry.content(type: 'html') { entry.cdata! content }
          entry.author { |author| author.name(project.user_display_name) }
        end
      end
    end
  end
end
