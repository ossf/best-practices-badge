# frozen_string_literal: true

# Compare Chief's proposals with and without SecurityInsightsDetective
# for a badge project that already exists in the database.
#
# Usage:
#   rails runner script/si_detective_compare_by_project_id.rb PROJECT_ID
#
# PROJECT_ID: numeric badge project ID whose repo_url points to the project
# you want to test (e.g. a project pointing to github.com/openfga/openfga).
#
# Output shows three sections:
#   ONLY WITH SI   - criteria proposed only when SI detective is active
#   CHANGED BY SI  - criteria proposed by both, but SI produces higher confidence
#   ONLY WITHOUT   - criteria proposed only when SI detective is absent (sanity check)

project_id = ARGV.first&.to_i
unless project_id&.positive?
  warn 'Usage: rails runner script/si_detective_compare_by_project_id.rb PROJECT_ID'
  exit 1
end

project = Project.find(project_id)
puts "Project: #{project.name} (#{project.repo_url})"
puts

client_factory = ->(token = nil) { Octokit::Client.new(access_token: token) }

def status_label(val)
  {
    CriterionStatus::MET => 'Met', CriterionStatus::UNMET => 'Unmet',
    CriterionStatus::NA => 'N/A', CriterionStatus::UNKNOWN => '?'
  }[val] || val.to_s
end

pool_without_si = Chief::ALL_DETECTIVES.reject { |d| d == SecurityInsightsDetective }

puts '--- Running Chief WITHOUT SecurityInsightsDetective ---'
without_si = Chief.new(project, client_factory, detectives: pool_without_si).propose_changes
puts "  #{without_si.size} proposals"

puts '--- Running Chief WITH SecurityInsightsDetective ---'
with_si = Chief.new(project, client_factory).propose_changes
puts "  #{with_si.size} proposals"

puts
puts '=' * 60

only_with = with_si.reject { |k, _| without_si.key?(k) }
only_without = without_si.reject { |k, _| with_si.key?(k) }
changed =
  with_si.select do |k, v|
    without_si.key?(k) && v[:confidence] != without_si[k][:confidence]
  end

if only_with.any?
  puts "\nONLY WITH SI (#{only_with.size} new proposals):"
  only_with.sort_by { |k, v| [-v[:confidence], k.to_s] }.each do |k, v|
    puts format('  conf %<conf>-4s  %<status>-8s  %<key>s',
                conf: v[:confidence], status: status_label(v[:value]), key: k)
    puts "         #{v[:explanation]}" if v[:explanation].present?
  end
else
  puts "\nONLY WITH SI: (none)"
end

if changed.any?
  puts "\nCHANGED BY SI (#{changed.size} higher-confidence proposals):"
  changed.sort_by { |k, _| k.to_s }.each do |k, v|
    puts "  #{k}: conf #{without_si[k][:confidence]} -> #{v[:confidence]}  #{status_label(v[:value])}"
  end
else
  puts "\nCHANGED BY SI: (none)"
end

if only_without.any?
  puts "\nONLY WITHOUT SI (#{only_without.size} — sanity check, should be empty):"
  only_without.each_key { |k| puts "  #{k}" }
else
  puts "\nONLY WITHOUT SI: (none — good)"
end
