#!/usr/bin/env ruby
# frozen_string_literal: true

# Copyright the Linux Foundation and the
# OpenSSF Best Practices badge contributors
# SPDX-License-Identifier: MIT

# Identify cache_frozen calls that are candidates for removal.
# Reads tmp/cache_metrics.json and scores each cache by effectiveness.
#
# Metrics tracked:
#   hit_allocs:  allocations on cache HIT (overhead only: key gen + read)
#   miss_allocs: allocations on cache MISS (overhead + rendering + write)
#
# A cache is worth keeping if:
#   - High hit rate (cache is being reused)
#   - Low hit allocations (overhead is cheap)
#   - High miss allocations (rendering is expensive, worth caching)
#
# Usage: script/cache_removal_candidates.rb [options]
#   --by-source  Group by source file:line (default)
#   --by-key     Show individual cache keys
#   --all        Show all caches, not just removal candidates

# TODO: We use the cache keys themselves to figure out source file:line.
# We should really instead record that during execution (by examining the stack
# frame and recording that). However, since this is purely for
# internal analysis, this is fine for our purposes.

require 'json'

METRICS_FILE = File.join(__dir__, '..', 'tmp', 'cache_metrics.json')
VIEWS_DIR = File.join(__dir__, '..', 'app', 'views')

# Thresholds
MIN_HIT_RATE = 70.0          # Below this hit% is suspect
HIGH_HIT_ALLOC = 40          # Above this allocs/hit is expensive overhead
MIN_SAMPLES = 20             # Need at least this many samples to judge

def build_source_map
  source_map = []
  Dir.glob("#{VIEWS_DIR}/**/*").each do |file|
    next unless File.file?(file)

    File.readlines(file).each_with_index do |line, idx|
      next unless line.include?('cache_frozen') # rubocop:disable Style/InvertibleUnlessCondition

      pattern = extract_key_pattern(line)
      rel_path = file.sub("#{File.dirname(VIEWS_DIR)}/", '')
      source_map << { pattern: pattern, file: rel_path, line: idx + 1, code: line.strip }
    end
  end
  source_map
end

# rubocop:disable Metrics/MethodLength
def extract_key_pattern(line)
  if line =~ /cache_frozen[_a-z]*\s*\[([^\]]+)\]/
    parts =
      Regexp.last_match(1).split(',').map do |p|
        p = p.strip
        if p =~ /^['"](.+)['"]$/
          Regexp.last_match(1) # literal string
        elsif /path|url|fullpath|request\./i.match?(p)
          '**' # multi-segment path variable
        else
          '*' # single-segment variable (locale, project, etc.)
        end
      end
    return parts.join('/')
  end
  return '*' if /cache_frozen[_a-z]*\s+locale\b/.match?(line)
  return 'true' if /cache_frozen[_a-z]*\s+true\b/.match?(line)
  # request.original_fullpath or similar path expressions
  return '**' if /cache_frozen[_a-z]*\s+(request\.|.*path|.*url)/i.match?(line)

  'unknown'
end
# rubocop:enable Metrics/MethodLength

# rubocop:disable Metrics/AbcSize, Metrics/MethodLength, Metrics/CyclomaticComplexity
def find_source(key, source_map)
  # First pass: patterns without ** (exact segment count)
  key_seg_count = key.split('/').length
  source_map.each do |src|
    pattern = src[:pattern]
    next if pattern.include?('**')

    pattern_parts = pattern.split('/')
    next unless pattern_parts.length == key_seg_count

    parts = pattern_parts.map { |p| p == '*' ? '[^/]+' : Regexp.escape(p) }
    regex_str = parts.join('/')
    return "#{src[:file]}:#{src[:line]}" if /^#{regex_str}$/.match?(key)
  end

  # Second pass: patterns with ** (sorted by specificity - more literals first)
  patterns_with_stars = source_map.select { |s| s[:pattern].include?('**') }
  patterns_with_stars.sort_by! { |s| -s[:pattern].gsub(/\*+/, '').length }

  patterns_with_stars.each do |src|
    pattern = src[:pattern]
    # Build regex: ** = any chars including /, * = segment without /
    regex_parts =
      pattern.split('/').map do |p|
        case p
        when '**' then '.*'
        when '*' then '[^/]+'
        else Regexp.escape(p)
        end
      end
    regex_str = regex_parts.join('/')
    return "#{src[:file]}:#{src[:line]}" if /^#{regex_str}$/.match?(key)
  end

  'unknown'
end
# rubocop:enable Metrics/AbcSize, Metrics/MethodLength, Metrics/CyclomaticComplexity

# Score: higher = better cache, lower = candidate for removal
# Good cache: high hit rate, low overhead per hit, expensive to render
def calc_score(hit_pct, avg_hit_alloc, avg_miss_alloc)
  # Hit rate contributes 50% (0-50 points)
  hit_score = hit_pct * 0.5

  # Low overhead on hits contributes 30% (0-30 points)
  # 0 allocs = 30 points, 100+ allocs = 0 points
  overhead_score = [30 - (avg_hit_alloc * 0.3), 0].max

  # Expensive rendering contributes 20% (0-20 points)
  # Higher miss allocs = more benefit from caching
  render_score = [avg_miss_alloc * 0.02, 20].min

  hit_score + overhead_score + render_score
end

def calc_problems(hit_pct, avg_hit_alloc, total)
  problems = []
  problems << "hit rate #{hit_pct.round(1)}%" if hit_pct < MIN_HIT_RATE
  problems << "#{avg_hit_alloc.round(0)} allocs/hit (overhead)" if avg_hit_alloc > HIGH_HIT_ALLOC
  problems << "low samples (#{total})" if total < MIN_SAMPLES
  problems
end

unless File.exist?(METRICS_FILE)
  warn "No metrics file: #{METRICS_FILE}"
  exit 1
end

metrics = JSON.parse(File.read(METRICS_FILE), symbolize_names: true)
show_all = ARGV.include?('--all')
by_key = ARGV.include?('--by-key')
source_map = build_source_map

# Build scored list
scored =
  metrics.map do |m|
    hits = m[:hits] || 0
    misses = m[:misses] || 0
    total = hits + misses
    hit_pct = total.positive? ? (hits * 100.0 / total) : 0.0
    avg_hit_alloc = hits.positive? ? m[:hit_allocs].to_f / hits : 0.0
    avg_miss_alloc = misses.positive? ? m[:miss_allocs].to_f / misses : 0.0
    {
      key: m[:key], source: find_source(m[:key], source_map),
      hits: hits, misses: misses, hit_allocs: m[:hit_allocs] || 0, miss_allocs: m[:miss_allocs] || 0,
      total: total, hit_pct: hit_pct, avg_hit_alloc: avg_hit_alloc, avg_miss_alloc: avg_miss_alloc,
      score: calc_score(hit_pct, avg_hit_alloc, avg_miss_alloc),
      problems: calc_problems(hit_pct, avg_hit_alloc, total)
    }
  end

# rubocop:disable Metrics/BlockLength
if by_key
  candidates = show_all ? scored : scored.select { |c| c[:problems].any? }
  candidates.sort_by! { |c| c[:score] }

  if candidates.empty?
    puts 'No removal candidates found.'
    exit 0
  end

  puts 'CACHE REMOVAL CANDIDATES BY KEY (least effective first)'
  puts '=' * 80
  candidates.each_with_index do |c, i|
    puts
    puts "#{i + 1}. #{c[:key]}"
    puts "   Source: #{c[:source]}"
    puts "   Score: #{c[:score].round(1)}/100 | Hit rate: #{c[:hit_pct].round(1)}%"
    puts "   Hits: #{c[:hits]} (#{c[:avg_hit_alloc].round(1)} allocs/hit overhead)"
    puts "   Misses: #{c[:misses]} (#{c[:avg_miss_alloc].round(1)} allocs/miss = render cost)"
    puts "   Problems: #{c[:problems].join(', ')}" if c[:problems].any?
  end
else
  # Group by source location
  by_source = {}
  scored.each do |c|
    src = c[:source]
    by_source[src] ||= { source: src, hits: 0, misses: 0, hit_allocs: 0, miss_allocs: 0, keys: [] }
    by_source[src][:hits] += c[:hits]
    by_source[src][:misses] += c[:misses]
    by_source[src][:hit_allocs] += c[:hit_allocs]
    by_source[src][:miss_allocs] += c[:miss_allocs]
    by_source[src][:keys] << c[:key]
  end

  # Calculate aggregate stats
  aggregated =
    by_source.values.map do |s|
      total = s[:hits] + s[:misses]
      hit_pct = total.positive? ? (s[:hits] * 100.0 / total) : 0.0
      avg_hit_alloc = s[:hits].positive? ? s[:hit_allocs].to_f / s[:hits] : 0.0
      avg_miss_alloc = s[:misses].positive? ? s[:miss_allocs].to_f / s[:misses] : 0.0
      s.merge(
        total: total, hit_pct: hit_pct,
        avg_hit_alloc: avg_hit_alloc, avg_miss_alloc: avg_miss_alloc,
        score: calc_score(hit_pct, avg_hit_alloc, avg_miss_alloc),
        problems: calc_problems(hit_pct, avg_hit_alloc, total)
      )
    end

  source_code = {}
  source_map.each { |s| source_code["#{s[:file]}:#{s[:line]}"] = s[:code] }

  candidates = show_all ? aggregated : aggregated.select { |c| c[:problems].any? }
  candidates.sort_by! { |c| c[:score] }

  if candidates.empty?
    puts 'No removal candidates found.'
    exit 0
  end

  puts 'CACHE REMOVAL CANDIDATES BY SOURCE (least effective first)'
  puts '=' * 80
  candidates.each_with_index do |c, i|
    puts
    puts "#{i + 1}. #{c[:source]}"
    puts "   Code: #{source_code[c[:source]] || '(not found)'}"
    puts "   Score: #{c[:score].round(1)}/100 | Hit rate: #{c[:hit_pct].round(1)}%"
    puts "   Hits: #{c[:hits]} (#{c[:avg_hit_alloc].round(1)} allocs/hit = overhead cost)"
    puts "   Misses: #{c[:misses]} (#{c[:avg_miss_alloc].round(1)} allocs/miss = render cost)"
    puts "   Problems: #{c[:problems].join(', ')}" if c[:problems].any?
    puts "   Unique keys: #{c[:keys].length}"
  end
end
# rubocop:enable Metrics/BlockLength

puts
puts '-' * 80
puts "Total source locations: #{source_map.length}, Analyzed: #{scored.length} keys"
puts
puts 'Score interpretation:'
puts '  - Low score + high allocs/hit: expensive overhead, consider removing'
puts '  - Low score + low hit rate: cache not being reused, consider removing'
puts '  - High allocs/miss: rendering is expensive, cache may still be valuable'
