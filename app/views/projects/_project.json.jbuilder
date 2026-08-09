# frozen_string_literal: true

# Show project in JSON format.
# This is a partial so "show" and "index" can share this.

# Memory-optimized approach: Add attributes directly to JSON without intermediate hashes
# This avoids allocating:
# - A full duplicate of project.attributes (~636 columns)
# - Intermediate transformed hashes from transform_keys
# Instead, we iterate once and transform keys/values as needed

# Add all project attributes with on-the-fly transformations
project.attributes.each do |key, value|
  # Withhold the columns that describe how we run the badging process
  # rather than the project itself; see Project::BOOKKEEPING_FIELDS.
  next if Project::BOOKKEEPING_FIELDS.include?(key)

  # Transform baseline field names to display form (uppercase with dashes)
  # Uses precomputed mapping for O(1) lookup with no allocations
  transformed_key = ProjectsHelper::BASELINE_FIELD_DISPLAY_NAME_MAP.fetch(key, key)

  # Check if it's a status using pre-computed frozen string set
  # (avoids repeated .to_s allocations)
  if Project::ALL_CRITERIA_STATUS_STRINGS.include?(key)
    # Convert status field values from integer->string for API compatibility
    # Database stores integers (0=?, 1=Unmet, 2=N/A, 3=Met), API returns strings
    json.set! transformed_key, CriterionStatus::STATUS_VALUES[value]
  else
    # Include data EXCEPT empty/null/nil justification fields
    if !(Project::ALL_CRITERIA_JUSTIFICATION_STRINGS.include?(key) &&
         value.blank?)
      json.set! transformed_key, value
    end
  end
end
json.badge_level project.badge_level
json.additional_rights project.additional_rights.pluck(:user_id)

# More than 80 character line to avoid run-time string concatenation
json.project_entry_attribution(
  "Please credit #{project.user.name} and the CII Best Practices badge contributors."
)
if project.show_entry_license?
  json.project_entry_license 'CC-BY-3.0+'
else
  json.project_entry_license 'CC-BY-3.0'
end
