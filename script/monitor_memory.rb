#!/usr/bin/env ruby
# frozen_string_literal: true

# Copyright the Linux Foundation and the
# OpenSSF Best Practices badge contributors
# SPDX-License-Identifier: MIT

# Memory monitoring script for Rails process.
# Continuously monitors RSS memory and reports growth.
#
# Usage: script/monitor_memory.rb [pid] [interval_seconds]
# Example: script/monitor_memory.rb 12345 5
#
# If PID is not provided, attempts to find Rails server process.

INTERVAL = (ARGV[1] || 5).to_i

# Find Rails server PID
def find_rails_pid
  pid_arg = ARGV.first
  return pid_arg.to_i unless pid_arg.nil?

  # Try to find puma (default Rails server)
  pids = `pgrep -f 'puma.*3000' 2>/dev/null`.strip.split
  return pids.first.to_i if pids.any?

  # Try rails s
  pids = `pgrep -f 'rails s' 2>/dev/null`.strip.split
  return pids.first.to_i if pids.any?

  nil
end

# Get memory usage in KB
def get_memory_kb(pid)
  if File.exist?("/proc/#{pid}/status")
    status = File.read("/proc/#{pid}/status")
    rss = status[/VmRSS:\s+(\d+)/, 1].to_i
    swap = status[/VmSwap:\s+(\d+)/, 1].to_i
    { rss: rss, swap: swap, total: rss + swap }
  else
    rss = `ps -o rss= -p #{pid}`.to_i
    { rss: rss, swap: 0, total: rss }
  end
rescue StandardError
  nil
end

def format_mb(kb)
  (kb / 1024.0).round(2)
end

# Main execution
pid = find_rails_pid

unless pid&.positive?
  puts 'Usage: script/monitor_memory.rb [pid] [interval_seconds]'
  puts
  puts 'Could not find Rails server process.'
  puts 'Either provide PID as argument or start Rails server first:'
  puts '  rails s -p 3000'
  puts
  puts 'Then find PID with:'
  puts "  pgrep -f 'puma.*3000'"
  exit 1
end

puts '=' * 75
puts 'Memory Monitor for Rails Process'
puts '=' * 75
puts "PID: #{pid}"
puts "Interval: #{INTERVAL}s"
puts 'Press Ctrl+C to stop'
puts
puts '-' * 75
puts 'Time                 |   RSS (MB) |  Swap (MB) | Total (MB) |   Delta (MB)'
puts '-' * 75

initial_mem = nil
previous_total = nil
measurements = []

# rubocop:disable Metrics/BlockLength
loop do
  mem = get_memory_kb(pid)

  unless mem
    puts "Process #{pid} not found - exiting"
    break
  end

  initial_mem ||= mem[:total]
  previous_total ||= mem[:total]

  delta = mem[:total] - previous_total
  now = Time.now.getlocal
  measurements << { time: now, total: mem[:total], delta: delta }

  timestamp = now.strftime('%Y-%m-%d %H:%M:%S')
  puts format(
    '%<time>-20s | %<rss>10.2f | %<swap>10.2f | %<total>10.2f | %<delta>+12.2f',
    time: timestamp,
    rss: format_mb(mem[:rss]),
    swap: format_mb(mem[:swap]),
    total: format_mb(mem[:total]),
    delta: format_mb(delta)
  )

  previous_total = mem[:total]
  sleep INTERVAL
rescue Interrupt
  puts
  puts '-' * 75
  puts 'SUMMARY'
  puts '-' * 75

  if measurements.length > 1
    duration = measurements.last[:time] - measurements.first[:time]
    total_growth = measurements.last[:total] - measurements.first[:total]
    growth_rate = duration.positive? ? total_growth / (duration / 60.0) : 0

    puts "Monitoring duration: #{duration.round(1)}s"
    puts "Initial memory:      #{format_mb(initial_mem)} MB"
    puts "Final memory:        #{format_mb(measurements.last[:total])} MB"
    puts "Total growth:        #{format_mb(total_growth)} MB"
    puts "Growth rate:         #{format_mb(growth_rate)} MB/min"

    puts
    if total_growth > 10_000 # > 10MB in KB
      puts 'WARNING: Memory is growing. This may indicate a leak.'
    elsif total_growth.negative?
      puts 'Memory decreased during monitoring (GC activity?).'
    else
      puts 'Memory stable during monitoring period.'
    end
  end

  puts '=' * 75
  break
end
# rubocop:enable Metrics/BlockLength
