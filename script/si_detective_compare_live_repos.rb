# frozen_string_literal: true

# Run the SecurityInsightsDetective comparison across several real-world repos
# that have security-insights.yml files, without needing pre-existing badge entries.
#
# Usage:
#   rails runner script/si_detective_compare_live_repos.rb
#
# Each repo is tested in turn. A temporary (unsaved) Project is created for
# each, Chief is run twice (with and without SecurityInsightsDetective), and
# the differences are printed.

TEST_REPOS = [
  { name: 'openfga/openfga',        url: 'https://github.com/openfga/openfga' },
  { name: 'dragonflyoss/Dragonfly', url: 'https://github.com/dragonflyoss/Dragonfly' },
  { name: 'ossf/alpha-omega',       url: 'https://github.com/ossf/alpha-omega' }
].freeze

client_factory = ->(token = nil) { Octokit::Client.new(access_token: token) }

def status_label(val)
  {
    CriterionStatus::MET => 'Met', CriterionStatus::UNMET => 'Unmet',
    CriterionStatus::NA => 'N/A', CriterionStatus::UNKNOWN => '?'
  }[val] || val.to_s
end

# rubocop:disable Metrics/MethodLength, Metrics/AbcSize
def print_comparison(repo_name, with_si, without_si)
  si_outputs = SecurityInsightsDetective::OUTPUTS.to_set

  only_with =
    with_si.reject { |k, _| without_si.key?(k) }
           .select { |k, v| si_outputs.include?(k) && v[:confidence].to_f > 0 }
  only_without = without_si.reject { |k, _| with_si.key?(k) }
  changed =
    with_si.select do |k, v|
      si_outputs.include?(k) && v[:confidence].to_f > 0 &&
        without_si.key?(k) && v[:confidence] != without_si[k][:confidence]
    end

  puts "\n#{'=' * 70}"
  puts "REPO: #{repo_name}"
  puts "  With SI: #{with_si.size} proposals  |  Without SI: #{without_si.size} proposals"

  if only_with.any?
    puts "\n  NEW proposals from SI detective (#{only_with.size}):"
    only_with.sort_by { |k, v| [-v[:confidence], k.to_s] }.each do |k, v|
      puts format('    conf %<conf>-4s  %<status>-8s  %<key>s',
                  conf: v[:confidence], status: status_label(v[:value]), key: k)
    end
  else
    puts "\n  NEW proposals from SI detective: (none)"
  end

  if changed.any?
    puts "\n  CONFIDENCE RAISED by SI detective (#{changed.size}):"
    changed.sort_by { |k, _| k.to_s }.each do |k, v|
      puts "    #{k}: conf #{without_si[k][:confidence]} -> #{v[:confidence]}  #{status_label(v[:value])}"
    end
  else
    puts "\n  CONFIDENCE RAISED by SI detective: (none)"
  end

  return if only_without.none?

  puts "\n  LOST when SI enabled — sanity check, should be empty (#{only_without.size}):"
  only_without.each_key { |k| puts "    #{k}" }
end
# rubocop:enable Metrics/MethodLength, Metrics/AbcSize

pool_without_si = Chief::ALL_DETECTIVES.reject { |d| d == SecurityInsightsDetective }

TEST_REPOS.each do |repo|
  print "\nTesting #{repo[:name]}... "
  project = Project.new(repo_url: repo[:url])

  begin
    with_si = Chief.new(project, client_factory).propose_changes
    print "with SI: #{with_si.size} proposals. "

    without_si = Chief.new(project, client_factory, detectives: pool_without_si).propose_changes
    puts "without SI: #{without_si.size} proposals."

    print_comparison(repo[:name], with_si, without_si)
  rescue StandardError => e
    puts "ERROR: #{e.message}"
    puts e.backtrace.first(3).map { |l| "  #{l}" }.join("\n")
  end
end

puts "\n#{'=' * 70}"
puts 'Done.'
