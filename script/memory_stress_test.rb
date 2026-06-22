#!/usr/bin/env ruby
# frozen_string_literal: true

# This is a standalone Ruby script, not Rails code, so disable Rails cops
# rubocop:disable Rails/Pluck, Rails/TimeZone, Rails/Present
# rubocop:disable Metrics/BlockLength, Style/GlobalVars
# rubocop:disable Lint/RedundantSafeNavigation, Style/RedundantFormat

# Copyright the Linux Foundation and the
# OpenSSF Best Practices badge contributors
# SPDX-License-Identifier: MIT

# Memory stress test script for reproducing memory growth issues.
# Sends repeated GET requests to simulate production traffic patterns.
#
# Usage:
#   script/memory_stress_test.rb [options] [iterations] [base_url]
#
# Options:
#   --crawler            Simulate web crawler: discover links, prefer unvisited pages
#   --duration DURATION  Run for specified duration instead of iterations
#                        Format: 30s, 10m, 6h, 1d (seconds, minutes, hours, days)
#   --shuffle            Shuffle paths for randomized order (default for duration mode)
#   --no-shuffle         Use sequential path order (default for iteration mode)
#   --report-interval N  Report progress every N requests (default: 100, or 500 for long runs)
#   --help               Show this help message
#
# Examples:
#   script/memory_stress_test.rb --crawler --duration 6h  # Realistic crawler simulation
#   script/memory_stress_test.rb 1000                     # 1000 iterations (legacy mode)
#   script/memory_stress_test.rb --duration 6h            # Run for 6 hours
#   script/memory_stress_test.rb --duration 30m --shuffle # 30 minutes, shuffled
#
# Crawler mode simulates real web crawlers that:
#   - Discover links from each page visited
#   - Prefer unvisited URLs over previously visited ones
#   - Cover all projects, sections, and locales systematically
#   - Restart from beginning after visiting all pages (like real crawlers)
#
# Path sources (in order of priority):
#   1. Files matching requested-paths-*.txt (real production paths)
#   2. Generated paths cycling through projects/sections
#
# Prerequisites:
#   - Rails server running in development mode
#   - Rate limits disabled (change `unless Rails.env.test?` to
#     `if Rails.env.production?` in config/initializers/rack_attack.rb)

require 'net/http'
require 'uri'
require 'json'
require 'optparse'

# Default configuration
DEFAULT_ITERATIONS = 500
DEFAULT_BASE_URL = 'http://localhost:3000'
# Use multiple locales like production traffic
LOCALES = %w[en fr de zh-CN ja ru].freeze
SECTIONS = %w[passing silver gold].freeze

# Percentage of generated requests that should be JSON
JSON_REQUEST_PERCENT = 10

# Percentage of generated requests that should be edit pages (requires login)
# Set to 0 if not logged in
EDIT_PAGE_PERCENT = 0

# Pattern for path files
PATH_FILE_PATTERN = 'requested-paths-*.txt'

# Crawler state class - tracks visited/unvisited URLs
class CrawlerState
  attr_reader :visited_count, :discovered_count, :restart_count

  def initialize(base_url, locales, sections)
    @base_url = base_url
    @locales = locales
    @sections = sections
    @visited = Set.new
    @queue = []
    @visited_count = 0
    @discovered_count = 0
    @restart_count = 0
    seed_queue
  end

  def seed_queue
    # Start with homepage and project list in all locales
    @locales.each do |locale|
      add_to_queue("/#{locale}/")
      add_to_queue("/#{locale}/projects")
      add_to_queue("/#{locale}/projects?page=1")
    end
    add_to_queue('/projects.json')
  end

  def add_to_queue(path)
    return unless path && !path.empty?

    # Normalize path
    path = path.split('#').first # Remove fragment
    path = path.split('?').first if path.include?('?') && !path.include?('page=')
    return unless path&.start_with?('/')
    return if @visited.include?(path) || @queue.include?(path)

    @queue << path
    @discovered_count += 1
  end

  def next_path
    if @queue.empty?
      # Restart crawl - revisit everything
      @restart_count += 1
      @visited.clear
      seed_queue
    end
    path = @queue.shift
    @visited.add(path)
    @visited_count += 1
    path
  end

  def queue_size
    @queue.size
  end

  # rubocop:disable Metrics/AbcSize, Metrics/MethodLength
  def extract_links_from_html(html, current_path)
    return unless html

    links_added = 0
    # Extract href links
    html.scan(/href=["']([^"']+)["']/).each do |match|
      link = match.first
      next if link.start_with?('http') && !link.include?(@base_url.sub(%r{https?://}, ''))
      next if link.start_with?('mailto:', 'javascript:')

      # Convert relative to absolute
      if link.start_with?('/')
        path = link
      elsif !link.start_with?('http')
        # Relative path
        base = current_path.sub(%r{/[^/]*$}, '')
        path = "#{base}/#{link}"
      else
        # Absolute URL to our domain - extract path
        path = link.sub(%r{https?://[^/]+}, '')
      end

      # Only include app paths, not assets
      next if /\.(css|js|png|jpg|jpeg|gif|svg|ico|woff|ttf)$/i.match?(path)
      next if path.start_with?('/assets/')

      add_to_queue(path)
      links_added += 1
    end
    links_added
  end
  # rubocop:enable Metrics/AbcSize, Metrics/MethodLength

  # rubocop:disable Metrics/MethodLength
  def extract_links_from_json(json_str)
    return unless json_str

    links_added = 0
    begin
      data = JSON.parse(json_str)
      # Handle array of projects
      projects = data.is_a?(Array) ? data : [data]
      projects.each do |proj|
        next unless proj.is_a?(Hash) && proj['id']

        id = proj['id']
        @locales.each do |locale|
          @sections.each do |section|
            add_to_queue("/#{locale}/projects/#{id}/#{section}")
            links_added += 1
          end
        end
      end
    rescue JSON::ParserError
      # Ignore parse errors
    end
    links_added
  end
  # rubocop:enable Metrics/MethodLength
end

# Parse duration string into seconds
# Supports: 30s, 10m, 6h, 1d
def parse_duration(str)
  return unless str

  match = str.match(/\A(\d+(?:\.\d+)?)\s*(s|m|h|d)?\z/i)
  return unless match

  value = match[1].to_f
  unit = (match[2] || 's').downcase

  case unit
  when 's' then value
  when 'm' then value * 60
  when 'h' then value * 3600
  when 'd' then value * 86_400
  end
end

# Format duration in human-readable form
# rubocop:disable Metrics/MethodLength
def format_duration(seconds)
  return '0s' if seconds.nil? || seconds <= 0

  parts = []
  if seconds >= 86_400
    days = (seconds / 86_400).to_i
    parts << "#{days}d"
    seconds %= 86_400
  end
  if seconds >= 3600
    hours = (seconds / 3600).to_i
    parts << "#{hours}h"
    seconds %= 3600
  end
  if seconds >= 60
    mins = (seconds / 60).to_i
    parts << "#{mins}m"
    seconds %= 60
  end
  parts << "#{seconds.round}s" if seconds.positive? || parts.empty?
  parts.join(' ')
end
# rubocop:enable Metrics/MethodLength

# Check if a path is valid for use in URLs
# Must be ASCII-only and start with /
def valid_path?(path)
  return false unless path.start_with?('/')
  return false unless path.ascii_only?
  # Reject paths with obvious corruption (embedded URLs, quotes, etc.)
  return false if path.include?('"') || path.include?("'")
  return false if path =~ %r{https?:/} && path !~ %r{\A/}

  true
end

# Load paths from requested-paths-*.txt files
# rubocop:disable Metrics/MethodLength
def load_paths_from_files
  paths = []
  skipped = 0
  files = Dir.glob(PATH_FILE_PATTERN).sort # rubocop:disable Lint/RedundantDirGlobSort

  if files.empty?
    puts 'No requested-paths-*.txt files found'
    return paths
  end

  files.each do |file|
    puts "Loading paths from #{file}..."
    File.readlines(file, chomp: true).each do |line|
      # Skip empty lines and comments
      next if line.empty? || line.start_with?('#')

      # Validate path before adding
      if valid_path?(line)
        paths << line
      else
        skipped += 1
      end
    end
  end

  puts "Loaded #{paths.length} paths from #{files.length} file(s)"
  puts "Skipped #{skipped} invalid paths" if skipped.positive?
  paths
end
# rubocop:enable Metrics/MethodLength

# Fetch project IDs from the server for generating additional paths
# rubocop:disable Metrics/MethodLength
def fetch_project_ids(base_url)
  uri = URI("#{base_url}/#{LOCALES.first}/projects.json")
  response = Net::HTTP.get_response(uri)
  unless response.is_a?(Net::HTTPSuccess)
    warn "Failed to fetch projects: #{response.code}"
    return [1]
  end

  data = JSON.parse(response.body)
  ids = data.map { |p| p['id'] }
            .first(50)
  ids.empty? ? [1] : ids
rescue StandardError => e
  warn "Failed to fetch project IDs: #{e.message}"
  [1]
end
# rubocop:enable Metrics/MethodLength

# Generate a random path for iteration i
# Uses multiple locales to simulate real production traffic
def generate_path(i, project_ids)
  project_id = project_ids[i % project_ids.length]
  section = SECTIONS[i % SECTIONS.length]
  locale = LOCALES[i % LOCALES.length]

  roll = rand(100)

  if roll < JSON_REQUEST_PERCENT
    # JSON request (no locale prefix)
    "/projects/#{project_id}.json"
  elsif roll < JSON_REQUEST_PERCENT + EDIT_PAGE_PERCENT
    # Edit page (requires login to actually work, but tests cache behavior)
    "/#{locale}/projects/#{project_id}/#{section}/edit"
  else
    # Normal show page with varying locales
    "/#{locale}/projects/#{project_id}/#{section}"
  end
end

# Determine if path is a JSON request
def json_path?(path)
  path.end_with?('.json')
end

# Make a single HTTP GET request
def make_request(url, accept_json: false)
  uri = URI(url)
  Net::HTTP.start(uri.host, uri.port, read_timeout: 30) do |http|
    request = Net::HTTP::Get.new(uri)
    request['Accept'] = accept_json ? 'application/json' : 'text/html'
    request['User-Agent'] = 'MemoryStressTest/1.0'
    http.request(request)
  end
rescue StandardError => e
  warn "  Request failed: #{e.message}"
  nil
end

# Get server process memory in MB (if accessible)
def server_memory_mb
  # Try to find Rails/Puma server PID
  pid = `pgrep -f 'puma.*3000' 2>/dev/null`.strip.split.first
  pid ||= `pgrep -f 'rails s' 2>/dev/null`.strip.split.first
  return unless pid && !pid.empty?

  if File.exist?("/proc/#{pid}/status")
    status = File.read("/proc/#{pid}/status")
    rss = status[/VmRSS:\s+(\d+)/, 1].to_i
    (rss / 1024.0).round(2)
  else
    (`ps -o rss= -p #{pid}`.to_i / 1024.0).round(2)
  end
rescue StandardError
  nil
end

# Parse command line options
options = {
  duration: nil,
  shuffle: nil, # nil means auto-detect based on mode
  report_interval: nil,
  iterations: nil,
  base_url: DEFAULT_BASE_URL,
  crawler: false
}

parser =
  OptionParser.new do |opts|
    opts.banner = "Usage: #{$PROGRAM_NAME} [options] [iterations] [base_url]"

    opts.on('--crawler', 'Simulate web crawler behavior (discover links, prefer unvisited)') do
      options[:crawler] = true
    end

    opts.on('--duration DURATION', 'Run for specified duration (e.g., 30s, 10m, 6h, 1d)') do |d|
      options[:duration] = parse_duration(d)
      if options[:duration].nil?
        warn "Invalid duration format: #{d}"
        exit 1
      end
    end

    opts.on('--shuffle', 'Shuffle paths for randomized order') do
      options[:shuffle] = true
    end

    opts.on('--no-shuffle', 'Use sequential path order') do
      options[:shuffle] = false
    end

    opts.on('--report-interval N', Integer, 'Report progress every N requests') do |n|
      options[:report_interval] = n
    end

    opts.on('-h', '--help', 'Show this help message') do
      puts opts
      exit
    end
  end

# Parse options, leaving positional args
begin
  parser.parse!
rescue OptionParser::InvalidOption => e
  warn e.message
  warn parser
  exit 1
end

# Handle positional arguments (iterations and base_url)
ARGV.each do |arg|
  if arg.match?(/\A\d+\z/)
    options[:iterations] = arg.to_i
  elsif arg.match?(%r{\Ahttps?://})
    options[:base_url] = arg
  end
end

# Determine mode and set defaults
duration_mode = !options[:duration].nil?
iterations = options[:iterations] || (duration_mode ? nil : DEFAULT_ITERATIONS)
duration_seconds = options[:duration]
base_url = options[:base_url]

# Auto-detect shuffle mode if not specified
shuffle_paths = options[:shuffle].nil? ? duration_mode : options[:shuffle]

# Auto-detect report interval if not specified
report_interval = options[:report_interval]
if report_interval.nil?
  report_interval =
    if duration_mode && duration_seconds >= 3600
      500 # Every 500 requests for long runs
    else
      100 # Every 100 requests for short runs
    end
end

# Hourly summary interval (for duration mode)
hourly_summary_interval = 3600

# Track if we should stop (for Ctrl+C handling)
$stop_requested = false
Signal.trap('INT') do
  if $stop_requested
    puts "\nForce quit."
    exit 1
  end
  puts "\nGraceful shutdown requested. Finishing current request..."
  $stop_requested = true
end

# Crawler mode setup
crawler_mode = options[:crawler]
crawler = nil

# Main execution
puts '=' * 70
puts 'Memory Stress Test for Best Practices Badge'
puts '=' * 70
if crawler_mode
  puts "Mode:         Crawler simulation#{" (#{format_duration(duration_seconds)})" if duration_mode}"
elsif duration_mode
  puts "Mode:         Duration-based (#{format_duration(duration_seconds)})"
else
  puts "Mode:         Iteration-based (#{iterations} requests)"
end
puts "Base URL:     #{base_url}"
puts "Path order:   #{if crawler_mode
                        'Crawler (prefer unvisited)'
                      else
                        (shuffle_paths ? 'Shuffled' : 'Sequential')
                      end}"
puts "Locales:      #{LOCALES.join(', ')}"
puts "Report every: #{report_interval} requests"
puts

# Initialize path sources based on mode
file_paths = []
paths_from_files = 0
project_ids = nil

if crawler_mode
  # Crawler mode - initialize crawler state
  puts 'Initializing crawler...'
  crawler = CrawlerState.new(base_url, LOCALES, SECTIONS)

  # Seed with project IDs from JSON endpoint
  print 'Fetching all project IDs... '
  uri = URI("#{base_url}/projects.json")
  response = Net::HTTP.get_response(uri)
  if response.is_a?(Net::HTTPSuccess)
    crawler.extract_links_from_json(response.body)
    puts "seeded queue with #{crawler.queue_size} URLs"
  else
    puts 'failed, using default seeds'
  end
else
  # Legacy mode - load paths from files
  file_paths = load_paths_from_files
  paths_from_files = file_paths.length

  # Shuffle if requested
  file_paths.shuffle! if shuffle_paths && file_paths.any?

  # Fetch project IDs for generating additional paths if needed
  need_generated = duration_mode || (iterations && paths_from_files < iterations)
  if need_generated
    print 'Fetching project IDs for generated paths... '
    project_ids = fetch_project_ids(base_url)
    puts "found #{project_ids.length} projects"
    if !duration_mode && iterations
      generated_needed = [0, iterations - paths_from_files].max
      puts "Will generate #{generated_needed} additional paths" if generated_needed.positive?
    end
  end
end

puts
initial_memory = server_memory_mb
puts "Initial server memory: #{initial_memory || 'unknown'} MB"
puts
puts '-' * 70
puts format(
  '%<iter>8s | %<path>-35s | %<src>4s | %<status>6s | %<mem>8s',
  iter: 'Iter',
  path: 'Path',
  src: 'Src',
  status: 'Status',
  mem: 'Mem MB'
)
puts '-' * 70

start_time = Time.now
last_hourly_summary = start_time
success_count = 0
error_count = 0
file_path_count = 0
generated_path_count = 0
path_index = 0
generated_index = 0

# Memory tracking for hourly summaries
hourly_memories = [{ time: start_time, mem: initial_memory }]

# Main loop - either iteration or duration based
i = 0
loop do
  # Check stop conditions
  break if $stop_requested

  if duration_mode
    elapsed = Time.now - start_time
    break if elapsed >= duration_seconds
  elsif i >= iterations
    break
  end

  # Get next path based on mode
  if crawler_mode
    path = crawler.next_path
    source = crawler.restart_count.positive? ? 'REV' : 'NEW'
    file_path_count += 1 # Reuse counter for crawler visited count
  elsif file_paths.any? && (duration_mode || path_index < file_paths.length)
    # Cycle through file paths
    actual_index = path_index % file_paths.length
    path = file_paths[actual_index]
    source = 'FILE'
    file_path_count += 1
    path_index += 1

    # Re-shuffle when we've gone through all paths (duration mode only)
    if duration_mode && shuffle_paths && (path_index % file_paths.length).zero? && path_index.positive?
      file_paths.shuffle!
    end
  else
    path = generate_path(generated_index, project_ids)
    source = 'GEN'
    generated_path_count += 1
    generated_index += 1
  end

  use_json = json_path?(path)
  url = "#{base_url}#{path}"

  response = make_request(url, accept_json: use_json)

  # Crawler mode: extract links from response
  if crawler_mode && response&.is_a?(Net::HTTPSuccess)
    if use_json
      crawler.extract_links_from_json(response.body)
    else
      crawler.extract_links_from_html(response.body, path)
    end
  end

  if response&.is_a?(Net::HTTPSuccess)
    success_count += 1
    status = 'OK'
  elsif response
    error_count += 1
    status = response.code
  else
    error_count += 1
    status = 'FAIL'
  end

  i += 1

  # Progress report
  show_progress = (i % report_interval).zero? ||
                  (!duration_mode && i == iterations)

  if show_progress
    mem = server_memory_mb
    mem_str = mem ? format('%.1f', mem) : '?'

    # Truncate path for display
    display_path = path.length > 35 ? "...#{path[-32..]}" : path

    # Add elapsed time for duration mode
    if duration_mode
      elapsed = Time.now - start_time
      time_info = " | #{format_duration(elapsed.to_i)}/#{format_duration(duration_seconds.to_i)}"
    else
      time_info = ''
    end

    puts format(
      '%<iter>8d | %<path>-35s | %<src>4s | %<status>6s | %<mem>8s',
      iter: i,
      path: display_path,
      src: source,
      status: status,
      mem: mem_str
    ) + time_info
  end

  # Hourly summary (for long runs)
  now = Time.now
  next unless duration_mode && (now - last_hourly_summary) >= hourly_summary_interval

  mem = server_memory_mb
  hourly_memories << { time: now, mem: mem }
  elapsed = now - start_time

  puts
  puts '-' * 70
  puts "HOURLY SUMMARY (#{format_duration(elapsed.to_i)} elapsed)"
  puts '-' * 70
  puts "Requests so far: #{i} (#{success_count} OK, #{error_count} errors)"
  puts "Request rate:    #{(i / elapsed).round(1)} req/s"
  puts "Current memory:  #{mem || 'unknown'} MB"
  if initial_memory && mem
    growth = mem - initial_memory
    puts "Memory growth:   #{growth.round(2)} MB since start"
    if hourly_memories.length >= 2
      prev = hourly_memories[-2]
      hourly_growth = mem - prev[:mem] if prev[:mem]
      puts "Last hour:       #{hourly_growth&.round(2) || 'unknown'} MB"
    end
  end
  puts '-' * 70
  puts

  last_hourly_summary = now
end

# Final report
elapsed = Time.now - start_time
final_memory = server_memory_mb
total_requests = success_count + error_count

puts
puts '-' * 70
puts 'FINAL SUMMARY'
puts '-' * 70
puts "Total requests:   #{total_requests}"
if crawler_mode
  puts "  URLs visited:   #{crawler.visited_count}"
  puts "  URLs discovered: #{crawler.discovered_count}"
  puts "  Crawl restarts: #{crawler.restart_count}"
  puts "  Queue remaining: #{crawler.queue_size}"
else
  puts "  From files:     #{file_path_count}"
  puts "  Generated:      #{generated_path_count}"
end
puts "Successful:       #{success_count}"
puts "Errors:           #{error_count}"
puts "Total time:       #{format_duration(elapsed.to_i)} (#{elapsed.round(2)}s)"
puts "Request rate:     #{(total_requests / elapsed).round(1)} req/s"
puts
puts "Initial memory:   #{initial_memory || 'unknown'} MB"
puts "Final memory:     #{final_memory || 'unknown'} MB"

if initial_memory && final_memory
  growth = final_memory - initial_memory
  growth_per_1k = total_requests.positive? ? (growth / total_requests) * 1000 : 0
  growth_per_hour = elapsed >= 60 ? (growth / elapsed) * 3600 : nil
  puts "Memory growth:    #{growth.round(2)} MB"
  puts "Growth per 1K req: #{growth_per_1k.round(2)} MB"
  puts "Growth per hour:  #{growth_per_hour&.round(2) || 'N/A'} MB" if growth_per_hour

  # Memory timeline for long runs
  if hourly_memories.length > 2
    puts
    puts 'Memory timeline:'
    hourly_memories.each_with_index do |snapshot, idx|
      elapsed_at = snapshot[:time] - start_time
      mem_str = snapshot[:mem] ? "#{snapshot[:mem].round(1)} MB" : '?'
      label = idx.zero? ? 'Start' : format_duration(elapsed_at.to_i)
      puts "  #{label.ljust(12)} #{mem_str}"
    end
    # Add final if not already there
    if (Time.now - hourly_memories.last[:time]) > 60
      puts "  #{'End'.ljust(12)} #{final_memory&.round(1) || '?'} MB"
    end
  end

  puts
  if growth > 50
    puts 'WARNING: Significant memory growth detected.'
    puts 'This may indicate a memory leak.'
  elsif growth > 10
    puts 'Note: Moderate memory growth observed.'
    puts 'May be normal warmup or slow leak.'
  elsif growth > 0
    puts 'Note: Minor memory growth observed (likely normal warmup).'
  else
    puts 'Memory stable or decreased during test.'
  end
end

if $stop_requested
  puts
  puts 'Test interrupted by user (Ctrl+C).'
end

puts '=' * 70
