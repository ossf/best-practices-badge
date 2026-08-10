# frozen_string_literal: true

# Copyright 2015-2017, the Linux Foundation, IDA, and the
# OpenSSF Best Practices badge contributors
# SPDX-License-Identifier: MIT

# rubocop:disable Metrics/ClassLength
# We ".freeze" a lot of results here, in part to optimize and in part
# to prevent potential threading issues, so this isn't worth it:
# rubocop: disable Style/MethodCalledOnDoEndBlock
class ProjectStatsController < ApplicationController
  # Our graphing component (chartkick) requires exceptions in our
  # content security policy (CSP), so poke holes in the policy.
  # This isn't so bad, because this page only displays data that is
  # numbers and dates, so even if there's a failure to escape the data
  # it would be challenging to exploit.
  SecureHeaders::Configuration.override(:headers_stats_index) do |config|
    config.csp[:script_src] = ["'self'", "'unsafe-inline'"]
    config.csp[:style_src] = ["'self'", "'unsafe-inline'"]
  end

  # These actions (endpoints) are special and do NOT take a locale.
  # These actions report JSON that is locale-independent; by always
  # omitting the locale, we create a single cacheable URL
  # that is used regardless of the locale. As a result, users who
  # use these are more likely to get a quick answer, and we also
  # save a few cycles on the server.
  # This is *only* acceptable if the called routine never calls I18n.t.
  skip_before_action :redir_missing_locale,
                     only: %i[total_projects nontrivial_projects silver gold]

  CSV_FILENAME = 'project_stats.csv'

  # The time, in number of seconds since midnight, when we log
  # project statistics. This is currently 23:30 UTC, set by Heroku scheduler;
  # change this value if you change the time of day we log statistics.
  LOG_TIME = ((23 * 60) + 30) * 60

  # If the "current time" is within this number of seconds to
  # seconds_since_midnight_log_time, presume that we're about to change
  # and thus do not cache statistics for long.
  LOG_TIME_SLOP = 5 * 60 # 5 minutes

  # Only cache for 120 seconds if we're about to do an update
  CACHE_TIME_WITHIN_SLOP = 120

  SECONDS_IN_A_DAY = 24 * 60 * 60 # 24 hours, 60 minutes, 60 seconds

  ACTIONS_CREATED_UPDATED = %w[created updated].freeze

  USER_STATS_LINE_CHART_FIELDS = %w[
    users
    github_users
    local_users
    users_created_since_yesterday
    users_updated_since_yesterday
    users_with_projects
    users_without_projects
    users_with_multiple_projects
    users_with_passing_projects
    users_with_silver_projects
    users_with_gold_projects
  ].freeze

  # Report the time we should cache, given seconds since midnight and
  # the fact that a log event will occur at "log_time". If the current
  # time and log time are within CACHE_TIME_WITHIN_SLOP, return a small
  # cache value.
  # @param seconds_since_midnight [Number] Seconds elapsed since midnight
  def cache_time(seconds_since_midnight)
    time_left = LOG_TIME - seconds_since_midnight
    if time_left.abs < LOG_TIME_SLOP
      CACHE_TIME_WITHIN_SLOP
    else
      time_left += SECONDS_IN_A_DAY if time_left.negative?
      time_left
    end
  end

  # Set the cache (including the CDN) to be used for cache_time
  # Sets HTTP header 'Cache-Control' to "max-age=#{seconds_left}, public"
  def cache_until_next_stat
    seconds_left = cache_time(Time.now.utc.seconds_since_midnight)
    # We can't just set Cache-Control directly like this:
    # headers['Cache-Control'] = "max-age=#{seconds_left}"
    # The problem is that Rails will quietly add 'private'
    # to the value of Cache-Control value. An easy solution is to
    # just use the built-in Rails mechanism for setting Cache-Control:
    expires_in seconds_left, public: true
  end

  # These controllers often generate a lot of JSON. More info:
  # https://guides.rubyonrails.org/layouts_and_rendering.html
  # https://buttercms.com/blog/json-serialization-in-rails-a-complete-guide
  # https://dev.to/caicindy87/rendering-json-in-a-rails-api-25fd
  # We *could* use other gems to speed JSON generation further
  # (e.g., oj), but that would add yet more dependencies; we think
  # the performance we get with "boring built-in tools" is adequate.
  # That's especially the case because there's been recent efforts to
  # improve the built-in Ruby json library to perform well. See
  # https://byroot.github.io/ruby/json/2024/12/15/optimizing-ruby-json-part-1.html

  # *Rapidly* render a JSON dataset which we know does *NOT* have cycles.
  # We *know* that there are no cycles in the JSON datasets we create,
  # so historically we used "fast_generate" instead of the default
  # JSON "generate" method here. At the time this improved performance by
  # skipping an unnecessary complicated check.
  # We justified this via benchmarks done in 2021.
  # However, the Ruby JSON library has been heavily optimized since then
  # (esp. in 2024), and the fast_generate method is now deprecated.
  # The "generate" method we use has a "max_nesting" parameter that provides
  # safety similar to the cycle-checker, but it has very low overhead.
  # We could disable it (with max_nesting=false), but since it has low
  # overhead it really isn't worth disabling. We don't *mind* having a
  # belt-and-suspenders approach to protect ourselves from errors, we
  # simply don't want to use *costly* extra defensive measures when they
  # aren't necessary.
  # Technically this method includes a view, not only a controller,
  # but this method is so small that for simplicity we include
  # this method in this controller.
  # @param dataset [Object] The data collection to process
  def render_json_fast(dataset)
    headers['Content-Type'] = 'application/json'
    render body: JSON.generate(dataset)
  end

  # GET /project_stats
  # GET /project_stats.json
  # rubocop:disable Metrics/MethodLength, Metrics/AbcSize
  def index
    use_secure_headers_override :headers_stats_index
    # Only load the full set of project stats if we need to
    respond_to do |format|
      format.csv do
        cache_until_next_stat
        headers['Content-Disposition'] =
          "attachment; filename=\"#{CSV_FILENAME}\""
        # No longer need this: @project_stats = ProjectStat.all
        @model = ProjectStat
        render format: :csv, filename: CSV_FILENAME
      end
      format.json do
        cache_until_next_stat
        # Use direct SQL like CSV export to avoid ActiveRecord overhead
        # Benchmarked improvement: 50-70% reduction in allocations
        raw_data = ProjectStat.connection.select_all(
          "SELECT * FROM #{ProjectStat.table_name} ORDER BY created_at"
        )
        # Process each record: ensure id is first, exclude nil values
        # This matches the original Jbuilder behavior
        stat_data =
          raw_data.map do |row|
            result = { 'id' => row['id'] }
            row.each do |key, value|
              result[key] = value unless value.nil? || key == 'id'
            end
            result
          end
        render_json_fast stat_data
      end
      # { render :show, status: :created, location: @project_stat }
      format.html do
        @is_normal = (params[:type] != 'uncommon')
        # We don't get project stats when generating HTML, but instead
        # send that separately via JSON. If you needed to get that in
        # some case, you could get it this way:
        # @project_stats = ProjectStat.all unless @is_normal
        render
      end
    end
  end
  # rubocop:enable Metrics/MethodLength, Metrics/AbcSize

  # Use separate JSON endpoints for charts.
  # This greatly speeds graph display & makes it easy to cache the data on the CDN
  # (we can't use the CDN on the HTML, because it varies by who's logged in)
  # For more information, see:
  # https://chartkick.com/

  # GET /project_stats/total_projects.json
  # Dataset of total number of project entries.
  # Path is total_projects_project_stats_path
  # Note that this does NOT take a locale.
  def total_projects
    cache_until_next_stat

    stat_data = ProjectStat.select(:created_at, :percent_ge_0)
    dataset =
      stat_data.each_with_object(Hash.new(capacity: stat_data.length)) do |e, h|
        h[e.created_at] = e.percent_ge_0
      end.freeze
    render_json_fast dataset
  end

  # Database fieldnames >0% for level 0 (passing)
  LEVEL0_GT0_FIELDS =
    ProjectStat::STAT_VALUES_GT0.map do |e|
      :"percent_ge_#{e}"
    end.freeze

  # Pre-computed field name strings to avoid repeated allocations in hot paths
  LEVEL0_GT0_FIELD_NAMES =
    ProjectStat::STAT_VALUES_GT0.map { |e| "percent_ge_#{e}".freeze }
                                .freeze

  # Pre-computed series names for nontrivial_projects chart
  NONTRIVIAL_SERIES_NAMES =
    ProjectStat::STAT_VALUES_GT0.map { |e| ">=#{e}%".freeze }
                                .freeze

  # Pre-computed field names for daily activity
  DAILY_ACTIVITY_FIELDS =
    ACTIONS_CREATED_UPDATED.map { |action| "#{action}_since_yesterday".freeze }
                           .freeze

  # Pre-computed field names for percent_earning (levels 0-2, always 100%)
  # Level 0 uses "percent_ge_100", levels 1-2 use "percent_N_ge_100"
  PERCENT_EARNING_FIELDS =
    ProjectStat::BADGE_LEVELS.map do |level|
      if level.zero?
        'percent_ge_100'
      else
        "percent_#{level}_ge_100".freeze
      end
    end.freeze

  # Pre-computed field names for silver_and_gold (levels 1-2, always 100%)
  SILVER_GOLD_FIELDS = %w[percent_1_ge_100 percent_2_ge_100].freeze

  # Badge level identifiers for silver and gold as strings (for I18n lookups)
  SILVER_GOLD_LEVELS = %w[1 2].freeze

  # GET /project_stats/nontrivial_projects.json
  # Dataset of nontrivial project entries
  # Note that this does NOT take a locale.
  # rubocop:disable Metrics/MethodLength, Metrics/AbcSize
  def nontrivial_projects
    cache_until_next_stat

    # Ask the database *once* for the data we need, then reorganize it
    stat_data = ProjectStat.select(:created_at, *LEVEL0_GT0_FIELDS)
    stat_data_len = stat_data.length

    # Show project counts; skip 0% because that makes chart scale unusable
    dataset =
      LEVEL0_GT0_FIELD_NAMES.zip(NONTRIVIAL_SERIES_NAMES).map do |field_name, series_name|
        series_dataset =
          stat_data.each_with_object(Hash.new(capacity: stat_data_len)) do |e, h|
            h[e.created_at] = e[field_name]
          end.freeze
        { name: series_name, data: series_dataset }.freeze
      end.freeze

    render_json_fast dataset
  end
  # rubocop:enable Metrics/MethodLength, Metrics/AbcSize

  # GET /:locale/project_stats/activity_30.json
  # Dataset of activity
  # Note: The names of the datasets are translated
  # rubocop:disable Metrics/MethodLength, Metrics/AbcSize
  def activity_30
    cache_until_next_stat
    dataset = []

    # Ask the database *once* for the data we need, then reorganize it
    stat_data = ProjectStat.select(
      :created_at,
      :active_projects, :active_in_progress,
      :active_edited_projects, :active_edited_in_progress
    )
    stat_data_len = stat_data.length

    # Active projects
    active_dataset =
      stat_data.each_with_object(Hash.new(capacity: stat_data_len)) do |e, h|
        h[e.created_at] = e.active_projects
      end.freeze
    dataset << {
      name: I18n.t('project_stats.index.active_projects'),
                data: active_dataset
    }

    # Active in-progress projects
    active_in_progress_dataset =
      stat_data.each_with_object(Hash.new(capacity: stat_data_len)) do |e, h|
        h[e.created_at] = e.active_in_progress
      end.freeze
    dataset << {
      name: I18n.t('project_stats.index.active_in_progress'),
                data: active_in_progress_dataset
    }

    # Active edited projects
    active_edited_dataset =
      stat_data.each_with_object(Hash.new(capacity: stat_data_len)) do |e, h|
        h[e.created_at] = e.active_edited_projects
      end.freeze
    dataset << {
      name: I18n.t('project_stats.index.active_edited'),
                data: active_edited_dataset
    }

    # Active edited in-progress projects
    active_edited_in_progress_dataset =
      stat_data.each_with_object(Hash.new(capacity: stat_data_len)) do |e, h|
        h[e.created_at] = e.active_edited_in_progress
      end.freeze
    dataset << {
      name: I18n.t('project_stats.index.active_edited_in_progress'),
                data: active_edited_in_progress_dataset
    }

    render_json_fast dataset
  end
  # rubocop:enable Metrics/MethodLength, Metrics/AbcSize

  # GET /:locale/project_stats/daily_activity.json
  # Dataset of daily activity
  # Note: The names of the datasets are translated
  # rubocop:disable Metrics/MethodLength, Metrics/AbcSize, Metrics/BlockLength
  def daily_activity
    # Show new and edited projects
    # These are expected to be smaller numbers, and show detailed activity,
    # so showing them separately will let us use scales that show more info.

    cache_until_next_stat

    dataset = []
    ndays = 7 # Days for calculated moving average

    # Retrieve just the data we need
    stat_data = ProjectStat.select(
      :created_at,
      :created_since_yesterday, :updated_since_yesterday
    )
    stat_data_len = stat_data.length

    ACTIONS_CREATED_UPDATED.zip(DAILY_ACTIVITY_FIELDS).each do |action, field_name|
      # Build both series_dataset and series_counts in single iteration
      # to avoid redundant pluck query (eliminates 2 queries per request)
      series_dataset = Hash.new(capacity: stat_data_len)
      series_counts = []
      stat_data.each do |e|
        value = e[field_name]
        series_dataset[e.created_at] = value
        series_counts << value
      end
      series_dataset.freeze
      dataset << {
        name: I18n.t("project_stats.index.projects_#{action}_since_yesterday"),
        data: series_dataset
      }.freeze
      # Calculate moving average over ndays
      series_moving_average =
        series_counts.each_cons(ndays).map do |e|
          e.sum.to_f / ndays
        end
      # Preallocate capacity for moving average dataset
      moving_average_dataset = Hash.new(capacity: stat_data_len - ndays)
      stat_data.each_with_index do |e, index|
        if index >= ndays
          moving_average_dataset[e.created_at] =
            series_moving_average[index - ndays]
        end
      end
      dataset << {
        name: I18n.t("project_stats.index.projects_#{action}_average_7_days"),
        data: moving_average_dataset,
        library: { borderDash: [5, 5] }
      }
    end

    render_json_fast dataset.freeze
  end
  # rubocop:enable Metrics/MethodLength, Metrics/AbcSize, Metrics/BlockLength

  # GET /:locale/project_stats/reminders.json
  # Reminders sent, reactivated after reminders
  # Note: The names of the datasets are translated
  # rubocop:disable Metrics/MethodLength, Metrics/AbcSize
  def reminders
    cache_until_next_stat
    dataset = []

    # Retrieve just the data we need
    stat_data = ProjectStat.select(
      :created_at, :reminders_sent, :reactivated_after_reminder
    )
    stat_data_len = stat_data.length

    # Reminders sent
    reminders_dataset =
      stat_data.each_with_object(Hash.new(capacity: stat_data_len)) do |e, h|
        h[e.created_at] = e.reminders_sent
      end.freeze
    dataset << {
      name: I18n.t('project_stats.index.reminders_sent_since_yesterday'),
      data: reminders_dataset
    }.freeze
    # Reactivated after reminders
    reactivated_dataset =
      stat_data.each_with_object(Hash.new(capacity: stat_data_len)) do |e, h|
        h[e.created_at] = e.reactivated_after_reminder
      end.freeze
    dataset << {
      name: I18n.t('project_stats.index.reactivated_projects'),
      data: reactivated_dataset
    }

    render_json_fast dataset
  end
  # rubocop:enable Metrics/MethodLength, Metrics/AbcSize

  # Level 1 (silver) database fields that are more than 25%
  LEVEL1_GT25_FIELDS =
    ProjectStat::STAT_VALUES_GT25.map do |e|
      :"percent_1_ge_#{e}"
    end.freeze

  # GET /project_stats/silver.json
  # rubocop:disable Metrics/MethodLength, Metrics/AbcSize
  def silver
    # Show project counts, but skip 25% because that makes chart scale unusable
    # The 25% value is a little misleading (because of overlaps), and messes
    # the scale, so show starting at 50%.

    cache_until_next_stat

    # Retrieve just the data we need
    stat_data = ProjectStat.select(:created_at, *LEVEL1_GT25_FIELDS)
    stat_data_len = stat_data.length

    dataset =
      ProjectStat::STAT_VALUES_GT25.map do |minimum|
        desired_field = "percent_1_ge_#{minimum}"
        series_dataset =
          stat_data.each_with_object(Hash.new(capacity: stat_data_len)) do |e, h|
            h[e.created_at] = e[desired_field]
          end.freeze
        { name: ">=#{minimum}%", data: series_dataset }.freeze
      end

    render_json_fast dataset
  end
  # rubocop:enable Metrics/MethodLength, Metrics/AbcSize

  # Level 2 (gold) database fields that are more than 25%
  LEVEL2_GT25_FIELDS =
    ProjectStat::STAT_VALUES_GT25.map do |e|
      :"percent_2_ge_#{e}"
    end.freeze

  # GET /project_stats/gold.json
  # rubocop:disable Metrics/MethodLength, Metrics/AbcSize
  def gold
    # Show project counts, but skip 25% because that makes chart scale unusable
    # The 25% value is a little misleading (because of overlaps), and messes
    # the scale, so show starting at 50%.

    cache_until_next_stat

    # Retrieve just the data we need
    stat_data = ProjectStat.select(:created_at, *LEVEL2_GT25_FIELDS)
    stat_data_len = stat_data.length

    dataset =
      ProjectStat::STAT_VALUES_GT25.map do |minimum|
        desired_field = "percent_2_ge_#{minimum}"
        series_dataset =
          stat_data.each_with_object(Hash.new(capacity: stat_data_len)) do |e, h|
            h[e.created_at] = e[desired_field]
          end.freeze
        { name: ">=#{minimum}%", data: series_dataset }
      end

    render_json_fast dataset
  end
  # rubocop:enable Metrics/MethodLength, Metrics/AbcSize

  # GET /:locale/project_stats/silver_and_gold.json
  # rubocop:disable Metrics/MethodLength, Metrics/AbcSize
  def silver_and_gold
    cache_until_next_stat

    # Retrieve just the data we need
    stat_data = ProjectStat.select(
      :created_at, :percent_1_ge_100, :percent_2_ge_100
    )
    stat_data_len = stat_data.length

    dataset =
      SILVER_GOLD_LEVELS.zip(SILVER_GOLD_FIELDS).map do |level, field_name|
        series_dataset =
          stat_data.each_with_object(Hash.new(capacity: stat_data_len)) do |e, h|
            h[e.created_at] = e[field_name]
          end.freeze
        {
          name: I18n.t("projects.form_early.level.#{level}"),
          data: series_dataset
        }
      end.freeze

    render_json_fast dataset
  end

  # rubocop:enable Metrics/MethodLength, Metrics/AbcSize
  # GET /:locale/project_stats/percent_earning.json
  # rubocop:disable Metrics/MethodLength, Metrics/AbcSize
  def percent_earning
    cache_until_next_stat

    # Retrieve just the data we need
    stat_data = ProjectStat.select(
      :created_at, :percent_ge_0,
      :percent_ge_100, :percent_1_ge_100, :percent_2_ge_100
    )
    stat_data_len = stat_data.length

    dataset =
      ProjectStat::BADGE_LEVELS.zip(PERCENT_EARNING_FIELDS).map do |level, field_name|
        series_dataset =
          stat_data.each_with_object(Hash.new(capacity: stat_data_len)) do |e, h|
            h[e.created_at] =
              e[field_name].to_i * 100.0 / e['percent_ge_0'].to_i
          end.freeze
        {
          name: I18n.t("projects.form_early.level.#{level}"),
           data: series_dataset
        }
      end.freeze

    render_json_fast dataset
  end
  # @param fields [Array] Array of field names for chart creation

  # Return JSON-formatted chart data with the given fields
  # rubocop: disable Metrics/MethodLength
  def create_line_chart(fields)
    # Retrieve just the data we need
    database_fields = [:created_at] + fields.map(&:to_sym)
    stat_data = ProjectStat.select(*database_fields)
    stat_data_len = stat_data.length

    dataset = []
    fields.each do |field|
      # Add "field" to dataset
      active_dataset =
        stat_data.each_with_object(Hash.new(capacity: stat_data_len)) do |e, h|
          h[e.created_at] = e[field]
        end.freeze
      dataset << {
        name: I18n.t("project_stats.index.#{field}"),
        data: active_dataset
      }
    end
    dataset.freeze
  end
  # rubocop:enable Metrics/MethodLength

  # rubocop:enable Metrics/MethodLength, Metrics/AbcSize
  # GET /:locale/project_stats/user_statistics.json
  # rubocop:disable Metrics/MethodLength, Metrics/AbcSize
  def user_statistics
    cache_until_next_stat

    dataset = create_line_chart(USER_STATS_LINE_CHART_FIELDS)

    render_json_fast dataset
  end

  # Forbidden:
  # GET /project_stats/new
  # def new
  # end

  # GET /project_stats/1/edit
  # def edit
  # end

  # POST /project_stats
  # POST /project_stats.json
  # def create
  # end

  # PATCH/PUT /project_stats/1
  # PATCH/PUT /project_stats/1.json
  # def update
  # end

  # DELETE /project_stats/1
  # DELETE /project_stats/1.json
  # def destroy
  # end

  # private

  # Never trust parameters from the scary internet,
  # only allow the white list through.
  # def project_stat_params
  #   params.require(:project_stat).permit(:when, :all, :percent_ge_25,
  #     :percent_ge_50, :percent_ge_75, :percent_ge_90, :percent_ge_100)
  # end
end
# rubocop: enable Style/MethodCalledOnDoEndBlock
# rubocop:enable Metrics/ClassLength
