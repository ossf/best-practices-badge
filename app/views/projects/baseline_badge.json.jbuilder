# frozen_string_literal: true

# JSON data doesn't depend on locale
json.cache! ['baseline-badge-json', @project], expires_in: 10.minutes do
  json.id @project.id
  json.name @project.name
  json.updated_at @project.updated_at
  json.badge_level @project.baseline_badge_value
  json.badge_percentage @project.badge_percentage_for('baseline-1')
end
