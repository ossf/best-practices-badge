# frozen_string_literal: true

# Copyright 2015-2017, the Linux Foundation and the
# OpenSSF Best Practices badge contributors
# SPDX-License-Identifier: MIT

# Checks if precompiled assets are stale by comparing modification times.
# Simple approach: if any file in app/assets/ is newer than the newest
# file in public/assets/, then assets need recompiling.
class AssetStalenessChecker
  # @param source_paths [Array<String, Pathname>] Paths containing source
  #   assets (e.g., app/assets/javascripts, app/assets/stylesheets)
  # @param compiled_assets_path [String, Pathname] Path to compiled assets dir
  #   (e.g., public/assets)
  # @param output [IO] Output stream for warnings (default: $stderr)
  def initialize(
    source_paths:,
    compiled_assets_path:,
    output: $stderr
  )
    @source_paths = source_paths.map { |p| Pathname.new(p) }
    @compiled_assets_path = Pathname.new(compiled_assets_path)
    @output = output
  end

  # Check for stale assets and warn if any are found
  # @param env [String, Symbol, nil] Rails environment. If 'development' or
  #   'test', raises on stale assets. Otherwise just warns.
  # @return [Boolean] true if stale assets were found
  # rubocop:disable Naming/PredicateMethod
  def check_and_warn(env: nil)
    return false unless assets_stale?

    # In dev/test, fail fast with error message
    if env && %w[development test].include?(env.to_s)
      raise build_error_message
    end

    # In production, just warn to stderr
    warn_about_stale_assets
    true
  end
  # rubocop:enable Naming/PredicateMethod

  # Check if assets are stale
  # @return [Boolean] true if any source file is newer than newest compiled
  def assets_stale?
    _newest_source_path, newest_source_time = find_newest_file(@source_paths)
    _newest_compiled_path, newest_compiled_time = find_newest_file([@compiled_assets_path])

    # If no source files or no compiled files, not stale
    return false unless newest_source_time && newest_compiled_time

    # Stale if any source file is newer than (after) the newest compiled file
    newest_source_time > newest_compiled_time
  end

  private

  # Find the newest file (by mtime) in the given paths
  # @param paths [Array<Pathname>] Paths to search recursively
  # @return [String, Time] Path to newest and its modification time
  # rubocop:disable Metrics/MethodLength
  def find_newest_file(paths)
    newest = nil
    found_path = nil

    paths.each do |path|
      next unless path.exist?

      # Find *all* files recursively
      # We need to include "DOTMATCH" so we truly include all files.
      # For example, the en.yml source text file is considered a "source"
      # file so editing it by itself suggests we should regenerate things.
      # That's okay, because after regenerating we'll regenerate a
      # .sprockets-manifest-*.json file, so after asset precompilation the
      # manifest file will be updates. HOWEVER, to *see* that manifest file,
      # we need to do a dotmatch. This check is conservative - sometimes
      # we don't need to do a precompile - but it's better to make sure
      # we do it when needed.
      Dir.glob(path.join('**', '*'), File::FNM_DOTMATCH).each do |file|
        next unless File.file?(file)

        mtime = File.mtime(file)
        if newest.nil? || mtime > newest
          newest = mtime
          found_path = path
        end
      end
    end

    [found_path, newest]
  end
  # rubocop:enable Metrics/MethodLength

  # Build error message for development/test environments
  # @return [String] Error message
  def build_error_message
    newest_source_path, _newest_source_time = find_newest_file(@source_paths)
    newest_compiled_path, _newest_compiled_time = find_newest_file([@compiled_assets_path])

    <<~MSG
      Stale precompiled assets detected! Run: rake assets:precompile

      Newest source file modified: #{newest_source_path}
      Newest compiled file: #{newest_compiled_path}

      Source files have been modified since the last precompilation.
    MSG
  end

  # Output warning message about stale assets
  def warn_about_stale_assets
    @output.puts
    @output.puts '=' * 80
    @output.puts 'WARNING: Stale precompiled assets detected!'
    @output.puts '=' * 80
    @output.puts
    @output.puts "Run 'rake assets:precompile' to fix this problem."
    @output.puts '=' * 80
    @output.puts
  end

  class << self
    # Create a checker from Rails application configuration
    # @param rails_app [Rails::Application] Rails application instance
    # @param output [IO] Output stream for warnings
    # @return [AssetStalenessChecker, nil] Configured checker instance or nil
    def from_rails_config(rails_app, output: $stderr)
      # Get asset source paths from Rails config
      source_paths = rails_app.config.assets.paths

      # Get compiled assets path
      assets_path = rails_app.paths['public'].first
      compiled_path = Pathname.new(assets_path).join('assets')

      # Only create checker if compiled assets directory exists
      return unless compiled_path.exist?

      new(
        source_paths: source_paths,
        compiled_assets_path: compiled_path,
        output: output
      )
    end
  end
end
