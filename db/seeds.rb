# frozen_string_literal: true

# This file should contain all the record creation needed to seed the database
# with its default values.
# The data can then be loaded with the rake db:seed (or created alongside the db
# with db:setup).
#
# Examples:
#
#   cities = City.create([{ name: 'Chicago' }, { name: 'Copenhagen' }])
#   Mayor.create(name: 'Emanuel', city: cities.first)
User.create!(
  name: 'Admin User', email: 'admin@example.org',
  password: 'p@$$w0rd',
  password_confirmation: 'p@$$w0rd',
  provider: 'local',
  role: 'admin', activated: true,
  activated_at: Time.zone.now
)

User.create!(
  name:  'Test User',
  email: 'test@example.org',
  password:              'p@$$word',
  password_confirmation: 'p@$$word',
  provider: 'local',
  activated: true,
  activated_at: Time.zone.now
)

100.times do |n|
  name  = "First#{n + 1} Last#{n + 1}"
  email = "test-#{n + 1}@example.org"
  password = 'p@$$word'
  User.create!(
    name:  name,
    email: email,
    password:              password,
    password_confirmation: password,
    provider: 'local',
    activated: true,
    activated_at: Time.zone.now
  )
end

ProjectStat.create!

# Projects for testing
user = User.find_by(email: 'test@example.org')
user.projects.create!(
  user_id: user.id,
  name:  'BadgeApp',
  description: 'Badge Application',
  homepage_url:
                          'https://github.com/ossf/best-practices-badge',
  repo_url:
                          'https://github.com/ossf/best-practices-badge',
  license: 'MIT',
  badge_percentage_0: 0,
  homepage_url_status: 0,
  sites_https_status: 0,
  description_good_status: 0,
  interact_status: 0,
  contribution_status: 0,
  contribution_requirements_status: 0,
  license_location_status: 0,
  floss_license_status: 0,
  floss_license_osi_status: 0,
  documentation_basics_status: 0,
  documentation_interface_status: 0,
  discussion_status: 0,
  english_status: 0,
  repo_public_status: 0,
  repo_track_status: 0,
  repo_interim_status: 0,
  repo_distributed_status: 0,
  version_unique_status: 0,
  version_semver_status: 0,
  version_tags_status: 0,
  release_notes_status: 0,
  release_notes_vulns_status: 0,
  report_url_status: 0,
  report_tracker_status: 0,
  report_process_status: 0,
  report_responses_status: 0,
  enhancement_responses_status: 0,
  report_archive_status: 0,
  vulnerability_report_process_status: 0,
  vulnerability_report_private_status: 0,
  vulnerability_report_response_status: 0,
  build_status: 0,
  build_common_tools_status: 0,
  build_floss_tools_status: 0,
  test_status: 0,
  test_invocation_status: 0,
  test_most_status: 0,
  test_policy_status: 0,
  tests_are_added_status: 0,
  tests_documented_added_status: 0,
  warnings_status: 0,
  warnings_fixed_status: 0,
  warnings_strict_status: 0,
  know_secure_design_status: 0,
  know_common_errors_status: 0,
  crypto_published_status: 0,
  crypto_call_status: 0,
  crypto_floss_status: 0,
  crypto_keylength_status: 0,
  crypto_working_status: 0,
  crypto_pfs_status: 0,
  crypto_password_storage_status: 0,
  crypto_random_status: 0,
  delivery_mitm_status: 0,
  delivery_unsigned_status: 0,
  vulnerabilities_fixed_60_days_status: 0,
  vulnerabilities_critical_fixed_status: 0,
  hardening_status: 0,
  no_leaked_credentials_status: 0,
  static_analysis_status: 0,
  static_analysis_common_vulnerabilities_status: 0,
  static_analysis_fixed_status: 0,
  static_analysis_often_status: 0,
  dynamic_analysis_status: 0,
  dynamic_analysis_unsafe_status: 0,
  dynamic_analysis_enable_assertions_status: 0,
  dynamic_analysis_fixed_status: 0
)

ProjectStat.create!

# rubocop:disable Metrics/BlockLength
100.times do |n|
  name = "test-name-#{n + 1}"
  description = "test-description#{n + 1}"
  homepage_url = 'https://' + "test-project-url-#{n + 1}.org"
  repo_url = 'https://' + "test-repo-url-#{n + 1}.org"
  license = [
    'MIT', 'Apache-2.0', 'GPL-2.0', 'GPL-2.0+', 'GPL-3.0+', 'MPL-2.0',
    'BSD-3-Clause', 'BSD-2-Clause', '(Apache-2.0 OR GPL-2.0+)'
  ].sample
  user.projects.create!(
    user_id: user.id,
    name: name,
    description: description,
    homepage_url: homepage_url,
    repo_url: repo_url,
    license: license,
    badge_percentage_0: 0,
    homepage_url_status: 0,
    sites_https_status: 0,
    description_good_status: 0,
    interact_status: 0,
    contribution_status: 0,
    contribution_requirements_status: 0,
    license_location_status: 0,
    floss_license_status: 0,
    floss_license_osi_status: 0,
    documentation_basics_status: 0,
    documentation_interface_status: 0,
    discussion_status: 0,
    english_status: 0,
    repo_public_status: 0,
    repo_track_status: 0,
    repo_interim_status: 0,
    repo_distributed_status: 0,
    version_unique_status: 0,
    version_semver_status: 0,
    version_tags_status: 0,
    release_notes_status: 0,
    release_notes_vulns_status: 0,
    report_url_status: 0,
    report_tracker_status: 0,
    report_process_status: 0,
    report_responses_status: 0,
    enhancement_responses_status: 0,
    report_archive_status: 0,
    vulnerability_report_process_status: 0,
    vulnerability_report_private_status: 0,
    vulnerability_report_response_status: 0,
    build_status: 0,
    build_common_tools_status: 0,
    build_floss_tools_status: 0,
    test_status: 0,
    test_invocation_status: 0,
    test_most_status: 0,
    test_policy_status: 0,
    tests_are_added_status: 0,
    tests_documented_added_status: 0,
    warnings_status: 0,
    warnings_fixed_status: 0,
    warnings_strict_status: 0,
    know_secure_design_status: 0,
    know_common_errors_status: 0,
    crypto_published_status: 0,
    crypto_call_status: 0,
    crypto_floss_status: 0,
    crypto_keylength_status: 0,
    crypto_working_status: 0,
    crypto_pfs_status: 0,
    crypto_password_storage_status: 0,
    crypto_random_status: 0,
    delivery_mitm_status: 0,
    delivery_unsigned_status: 0,
    vulnerabilities_fixed_60_days_status: 0,
    vulnerabilities_critical_fixed_status: 0,
    hardening_status: 0,
    no_leaked_credentials_status: 0,
    static_analysis_status: 0,
    static_analysis_common_vulnerabilities_status: 0,
    static_analysis_fixed_status: 0,
    static_analysis_often_status: 0,
    dynamic_analysis_status: 0,
    dynamic_analysis_unsafe_status: 0,
    dynamic_analysis_enable_assertions_status: 0,
    dynamic_analysis_fixed_status: 0
  )
end
# rubocop:enable Metrics/BlockLength

ProjectStat.create!
