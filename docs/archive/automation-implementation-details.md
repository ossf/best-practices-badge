# Automation Implementation Details

Supplement to `automation-thoughts.md` with detailed implementation code.

**Note**: This document reflects all decisions from automation-thoughts.md including:

- OVERRIDABLE_OUTPUTS architecture (Decision #6)
- Highlighting rules: orange for overrides, yellow for automation (Decision #2)
- i18n throughout (Decision #5)
- API 200 OK with override details (Decision #1)
- Server-side rendering for accessibility (Decision #4)
- Error handling with selective save (Decision #6)
- Simple logging (Decision #7)

## Controller Implementation: Overridden Field Handling (Decision #2)

When save operations result in forced overrides (confidence >= 4), we must:

1. Save the overridden values
2. Redirect back to edit form (never to show page)
3. Highlight overridden fields in ORANGE (Decision #2)
4. Scroll to first override
5. Show detailed i18n flash message (Decision #5)

**Highlighting Rules**:

- **Orange** (.highlight-overridden): Field was non-'?' → overridden by Chief (needs attention)
- **Yellow** (.highlight-automated): Field was '?' → filled by Chief (helpful suggestion)

### Tracking Overridden and Automated Fields

```ruby
# In projects_controller.rb update action

def update
  # ... existing setup ...

  changed_fields = project_params.keys.map(&:to_sym)

  # Capture original values before Chief analysis
  original_values = {}
  changed_fields.each do |field|
    original_values[field] = @project[field]
  end

  chief = Chief.new(@project, client_factory)

  # Handle potential Chief failure (Decision #6)
  begin
    proposed_changes = chief.propose_changes(
      level: @criteria_level,
      changed_fields: changed_fields
    )
  rescue StandardError => e
    Rails.logger.error("Chief analysis failed: #{e.message}")
    handle_chief_failure(e, changed_fields)
    return
  end

  # Track which fields Chief is overriding vs auto-filling
  overridden_fields = []  # Orange highlight
  automated_fields = []   # Yellow highlight

  proposed_changes.each do |field, data|
    old_value = original_values[field] || @project[field]

    if data[:confidence] >= Chief::CONFIDENCE_OVERRIDE &&
       data[:value] != old_value

      if old_value.present? && old_value != '?'
        # Overriding a real value - ORANGE
        overridden_fields << {
          field: field,
          old_value: old_value,
          new_value: data[:value],
          explanation: data[:explanation],
          confidence: data[:confidence]
        }
      elsif old_value == '?' || old_value.blank?
        # Filling in an unknown - YELLOW
        automated_fields << {
          field: field,
          new_value: data[:value],
          explanation: data[:explanation]
        }
      end
    end
  end

  # Apply changes (including forced overrides)
  chief.apply_changes(@project, proposed_changes)

  # Log overrides for monitoring (Decision #7)
  if overridden_fields.any?
    Rails.logger.info(
      "Chief override: project=#{@project.id} user=#{current_user&.id} "\
      "fields=#{overridden_fields.map { |f| f[:field] }.join(',')}"
    )
  end

  # Save and handle overrides
  if @project.save
    set_level_saved_flag(@criteria_level)

    if overridden_fields.any?
      handle_overridden_fields(overridden_fields, automated_fields)
    elsif automated_fields.any?
      handle_automated_fields(automated_fields)
    else
      # Normal save - exit to show page
      flash[:success] = t('projects.update.updated')
      redirect_to project_path(@project)
    end
  else
    # Validation errors - re-render edit form
    render :edit
  end
end

private

def set_level_saved_flag(level)
  flag_name = case level
              when 'passing' then :passing_saved
              when 'silver' then :silver_saved
              when 'gold' then :gold_saved
              when 'baseline-1' then :baseline_1_saved
              when 'baseline-2' then :baseline_2_saved
              when 'baseline-3' then :baseline_3_saved
              end
  @project.update_column(flag_name, true) if flag_name
end

def handle_overridden_fields(overridden_fields, automated_fields)
  # Build detailed i18n flash message (Decision #5)
  flash[:warning] = t('projects.update.chief_overrode',
    count: overridden_fields.size,
    overrides: overridden_fields.map { |r|
      criterion = Criteria.find_by(name: r[:field].to_s.chomp('_status'))
      criterion_name = criterion&.title || r[:field].to_s.humanize
      t('projects.update.override_detail',
        criterion: criterion_name,
        old: r[:old_value],
        new: r[:new_value],
        explanation: r[:explanation])
    }.join("\n")
  )

  # Redirect back to edit form with highlight info
  first_overridden = overridden_fields.first[:field]
  redirect_to edit_project_path(
    @project,
    level: @criteria_level,
    anchor: first_overridden.to_s,
    overridden: overridden_fields.map { |r| r[:field].to_s }.join(','),
    automated: automated_fields.map { |r| r[:field].to_s }.join(',')
  )
end

def handle_automated_fields(automated_fields)
  # Show informational message for auto-filled fields
  flash[:info] = t('projects.update.chief_automated',
    count: automated_fields.size,
    fields: automated_fields.map { |r|
      criterion = Criteria.find_by(name: r[:field].to_s.chomp('_status'))
      criterion&.title || r[:field].to_s.humanize
    }.join(', ')
  )

  # Continue editing to review automated suggestions
  redirect_to edit_project_path(
    @project,
    level: @criteria_level,
    automated: automated_fields.map { |r| r[:field].to_s }.join(',')
  )
end

def handle_chief_failure(error, changed_fields)
  # Decision #6: Save non-overridable fields, keep user input for overridable ones

  # Find which fields are potentially overridable
  overridable = Set.new
  Chief::ALL_DETECTIVES.each do |detective_class|
    overridable.merge(detective_class::OVERRIDABLE_OUTPUTS)
  end

  potentially_affected = changed_fields.select { |f| overridable.include?(f) }

  # Restore user's original input for overridable fields (don't save Chief's unvalidated changes)
  potentially_affected.each do |field|
    # Already has user's input from params, no need to change
  end

  # Try to save (all non-overridable fields + user input for overridable fields)
  if @project.save
    flash[:warning] = t('projects.update.analysis_failed',
                       count: potentially_affected.size,
                       fields: potentially_affected.join(', '))
    render :edit  # Show edit form with fields they tried to change
  else
    flash[:alert] = t('projects.update.save_failed')
    render :edit
  end
end
```

## View Implementation: Highlighting and Scrolling (Decision #2, #4)

### Server-Side Highlighting (Works Without JavaScript)

**Critical** (Decision #4): CSS classes must be added server-side so highlights work without JavaScript.

**Highlighting Rules** (Decision #2):

- **Orange** (.highlight-overridden): Chief overrode a non-'?' value (needs attention) - includes icon ⚠️
- **Yellow** (.highlight-automated): Chief filled in a '?' value (helpful) - includes icon 🤖

**Accessibility** (Decision #4):

- Color coding (orange/yellow backgrounds)
- Icons (⚠️ for overridden, 🤖 for automated)
- ARIA labels with descriptive text
- All generated server-side

#### Controller: Track Highlighted Fields

```ruby
# In edit action
def edit
  # ... existing setup ...

  # Check if this is first edit (automated fields)
  level_saved_flag = get_level_saved_flag(@criteria_level)

  if !@project[level_saved_flag]
    # Run automation and track what changed (YELLOW highlights)
    chief = Chief.new(@project, client_factory)
    changes = chief.propose_changes(level: @criteria_level)
    @automated_fields = changes.select { |_, data|
      # Only yellow-highlight if we filled in '?' or blank
      old_value = @project[data[:field]]
      old_value.blank? || old_value == '?'
    }.keys
    chief.apply_changes(@project, changes)
  else
    @automated_fields = []
  end

  # Check for overridden fields from save redirect (ORANGE highlights)
  @overridden_fields = []
  if params[:overridden]
    # Parse and validate (security)
    @overridden_fields = params[:overridden].split(',').select do |field|
      field.match?(/\A[a-z_0-9]+\z/)
    end.map(&:to_sym)
  end

  # Check for automated fields from save redirect (YELLOW highlights)
  if params[:automated]
    @automated_fields = params[:automated].split(',').select do |field|
      field.match?(/\A[a-z_0-9]+\z/)
    end.map(&:to_sym)
  end

  # Make these available to view
  @automated_fields = (@automated_fields || []).map(&:to_sym)
  @overridden_fields = (@overridden_fields || []).map(&:to_sym)
end

private

def get_level_saved_flag(level)
  case level
  when 'passing' then :passing_saved
  when 'silver' then :silver_saved
  when 'gold' then :gold_saved
  when 'baseline-1' then :baseline_1_saved
  when 'baseline-2' then :baseline_2_saved
  when 'baseline-3' then :baseline_3_saved
  end
end
```

#### View: Apply CSS Classes Directly in HTML (Decision #4: Server-Side)

```erb
<!-- In app/views/projects/_criterion.html.erb or similar -->
<%
  field_name = :"#{criterion.name}_status"
  css_classes = ['criterion-data']
  aria_label_parts = []

  # Add highlight classes based on server-side data
  if @automated_fields&.include?(field_name)
    css_classes << 'highlight-automated'
    aria_label_parts << t('projects.edit.aria_automated')  # "Automatically filled"
  end

  if @overridden_fields&.include?(field_name)
    css_classes << 'highlight-overridden'
    aria_label_parts << t('projects.edit.aria_overridden')  # "Value was corrected"
  end

  aria_label = aria_label_parts.any? ? " aria-label=\"#{aria_label_parts.join(', ')}\"" : ""
%>

<div class="<%= css_classes.join(' ') %>"
     data-criterion="<%= field_name %>"
     id="criterion-<%= field_name %>"
     <%= aria_label.html_safe %>>

  <% if @automated_fields&.include?(field_name) %>
    <span class="automation-icon" title="<%= t('projects.edit.automated_tooltip') %>" aria-hidden="true">🤖</span>
  <% end %>

  <% if @overridden_fields&.include?(field_name) %>
    <span class="override-icon" title="<%= t('projects.edit.overridden_tooltip') %>" aria-hidden="true">⚠️</span>
  <% end %>

  <%= render_criterion_row(criterion, project) %>
</div>
```

**Accessibility Features** (Decision #4):

- `.highlight-automated` and `.highlight-overridden` CSS classes (color)
- 🤖 and ⚠️ icons (visual indicator)
- ARIA labels (screen reader support)
- i18n for all text (Decision #5)

**Result**: Orange and yellow highlights with icons appear even with JavaScript disabled.

### JavaScript Enhancement (Progressive Enhancement Only)

JavaScript only provides **optional enhancements**:

- Auto-expand panels containing highlighted fields
- Smooth scroll to first overridden field
- Focus management for accessibility

**Critical**: All core functionality works without JavaScript.

```javascript
// Progressive enhancement - only runs if JavaScript enabled
document.addEventListener('DOMContentLoaded', function() {
  // Auto-expand panels with automated or overridden fields
  document.querySelectorAll('.highlight-automated, .highlight-overridden').forEach(field => {
    const panel = field.closest('.panel-collapse');
    if (panel) {
      panel.classList.add('show');
      // Also open parent panels if nested
      let currentElement = panel;
      while (currentElement) {
        const parentCollapse = currentElement.parentElement?.closest('.panel-collapse');
        if (parentCollapse) {
          parentCollapse.classList.add('show');
        }
        currentElement = parentCollapse;
      }
    }
  });

  // Scroll to first overridden field (from URL anchor)
  if (window.location.hash) {
    setTimeout(() => {
      const targetId = 'criterion-' + window.location.hash.substring(1);
      const target = document.getElementById(targetId);
      if (target) {
        target.scrollIntoView({ behavior: 'smooth', block: 'center' });

        // Set focus for keyboard navigation
        const focusable = target.querySelector('input, select, textarea');
        if (focusable) focusable.focus();
      }
    }, 500); // Delay for panel expansion
  }
});
```

**Graceful Degradation Without JavaScript**:

- ✅ Highlights still visible (server-rendered CSS classes)
- ✅ Icons visible (🤖 for automated, ⚠️ for overridden)
- ✅ ARIA labels work (screen readers announce changes)
- ✅ Users can see which fields were changed
- ❌ Panels might be collapsed (users must click to expand)
- ❌ No auto-scroll (users must find highlighted fields manually)
- ❌ URL anchor won't scroll automatically

### CSS for Highlighting (Decision #2: Orange vs Yellow)

Add to `app/assets/stylesheets/projects.scss`:

```scss
// Orange highlight: Chief OVERRODE a non-'?' value (needs attention)
.highlight-overridden {
  border-left: 6px solid #e65c00 !important; // Strong orange
  background-color: #fff4e6; // Light orange background
  padding-left: 16px;
  padding-top: 8px;
  padding-bottom: 8px;
  margin-bottom: 8px;
  animation: pulse-orange 2s ease-in-out 3; // Pulse 3 times
  transition: background-color 0.3s ease;

  &:hover {
    background-color: #ffe6cc; // Slightly darker on hover
  }
}

@keyframes pulse-orange {
  0%, 100% {
    background-color: #fff4e6;
    border-left-width: 6px;
  }
  50% {
    background-color: #ffe6cc;
    border-left-width: 8px;
  }
}

// Yellow highlight: Chief FILLED IN a '?' value (helpful suggestion)
.highlight-automated {
  border-left: 4px solid #ffcc00 !important; // Gold
  background-color: #ffffed; // Very light yellow
  padding-left: 14px;
  padding-top: 6px;
  padding-bottom: 6px;
  margin-bottom: 6px;

  &:hover {
    background-color: #ffffcc; // Slightly darker on hover
  }
}

// Icons (duplicated in HTML for accessibility, styled here)
.automation-icon, .override-icon {
  font-size: 0.9em;
  margin-right: 8px;
  vertical-align: middle;
}

.override-icon {
  opacity: 0.9; // ⚠️ slightly prominent
}

.automation-icon {
  opacity: 0.7; // 🤖 more subtle
}

// Ensure colors work in dark mode (if applicable)
@media (prefers-color-scheme: dark) {
  .highlight-overridden {
    background-color: #4d3319; // Dark orange background
    border-left-color: #ff9933;
  }

  .highlight-automated {
    background-color: #4d4d19; // Dark yellow background
    border-left-color: #ffdd55;
  }
}
```

**Visual Design Goals**:

- **Orange** is more prominent (6px border, stronger pulse) - "Hey, we changed what you said!"
- **Yellow** is more subtle (4px border, no pulse) - "We helpfully filled this in"
- Both work with high contrast for accessibility
- Icons add non-color visual indicators (Decision #4)

### Alternative: CSS-Only Panel Expansion

For better no-JavaScript experience, use URL fragment and CSS `:target` pseudo-class:

```erb
<!-- Redirect with fragment pointing to overridden field -->
redirect_to edit_project_path(
  @project,
  level: @criteria_level,
  anchor: first_overridden.to_s,
  overridden: overridden_fields.map { |r| r[:field].to_s }.join(',')
)
```

```scss
// CSS to auto-expand panel containing targeted element
.panel-collapse:has(#criterion-#{$field}:target) {
  display: block !important; // Override Bootstrap collapse
}

// Or using more general selector
.criterion-data:target {
  scroll-margin-top: 100px; // Offset for fixed header

  // Ensure parent panel is visible
  .panel-collapse {
    display: block !important;
  }
}
```

**Browser support**: `:has()` is supported in modern browsers (2023+). For older browsers, JavaScript fallback still works.

## Testing Strategy

### Controller Tests

```ruby
# test/controllers/projects_controller_test.rb

test 'should override and redirect to edit when high confidence changes user input' do
  project = projects(:one)
  sign_in users(:admin_user)

  # Mock Chief to return forced overrides in multiple directions
  Chief.stub :new, MockChiefWithOverrides.new do
    patch project_url(project, locale: :en), params: {
      project: {
        floss_license_osi_status: 'Met',  # Will be overridden to Unmet
        contribution_status: '?'           # Will be overridden to Met
      },
      level: 'passing'
    }
  end

  # Should redirect to edit, not show
  assert_redirected_to edit_project_path(project, level: 'passing')

  # Should include overridden fields in URL
  assert_match /overridden=.*floss_license_osi_status/, @response.redirect_url
  assert_match /overridden=.*contribution_status/, @response.redirect_url

  # Should have warning flash
  assert_match /We corrected.*field/, flash[:warning]
  assert_match /changed from/, flash[:warning]

  # Should save both overrides
  project.reload
  assert_equal 'Unmet', project.floss_license_osi_status
  assert_equal 'Met', project.contribution_status
end

test 'should exit normally when no overrides made' do
  project = projects(:one)
  sign_in users(:admin_user)

  # Mock Chief to agree with user input
  Chief.stub :new, MockChiefWithoutOverrides.new do
    patch project_url(project, locale: :en), params: {
      project: { description_good_status: 'Met' },
      level: 'passing'
    }
  end

  # Should redirect to show page
  assert_redirected_to project_path(project)

  # Should have success flash
  assert_match /updated/i, flash[:success]
end

class MockChiefWithOverrides
  def initialize; end

  def propose_changes(level:, changed_fields:)
    {
      floss_license_osi_status: {
        value: 'Unmet',
        confidence: 5,
        explanation: 'Detected license (Proprietary) is not OSI-approved'
      },
      contribution_status: {
        value: 'Met',
        confidence: 5,
        explanation: 'CONTRIBUTING.md file found in repository'
      }
    }
  end

  def apply_changes(project, changes)
    changes.each { |field, data| project[field] = data[:value] }
  end
end

class MockChiefWithoutOverrides
  def initialize; end

  def propose_changes(level:, changed_fields:)
    {} # No changes proposed
  end

  def apply_changes(project, changes)
    # No-op
  end
end
```

### System Tests

```ruby
# test/system/automation_override_test.rb

class AutomationOverrideTest < ApplicationSystemTestCase
  test 'user sees overridden fields highlighted and scrolled to' do
    project = projects(:one)
    sign_in_as users(:admin_user)

    visit edit_project_path(project, locale: :en, level: 'passing')

    # User tries to claim OSI license
    choose 'project_floss_license_osi_status_met'
    click_button 'Save and Exit'

    # Should redirect back to edit (mocked Chief override)
    assert_current_path edit_project_path(project, level: 'passing')

    # Should show warning flash
    assert_text 'We corrected'
    assert_text 'changed from'

    # Should highlight overridden field
    overridden_field = find('[data-criterion="floss_license_osi_status"]')
    assert overridden_field[:class].include?('highlight-overridden')

    # Panel should be expanded
    panel = overridden_field.ancestor('.panel-collapse')
    assert panel[:class].include?('show')
  end

  test 'user exits normally when no overrides made' do
    project = projects(:one)
    sign_in_as users(:admin_user)

    visit edit_project_path(project, locale: :en, level: 'passing')

    # User sets value that Chief agrees with
    choose 'project_description_good_status_met'
    click_button 'Save and Exit'

    # Should go to show page
    assert_current_path project_path(project)

    # Should show success message
    assert_text 'updated'
  end
end
```

## Performance Considerations

### Avoiding N+1 Queries

When building flash message for overridden fields, preload criteria:

```ruby
def handle_overridden_fields(overridden_fields)
  # Preload all criteria to avoid N+1
  field_names = overridden_fields.map { |r| r[:field].to_s.chomp('_status') }
  criteria_map = Criteria.where(name: field_names).index_by(&:name)

  message = "We corrected #{overridden_fields.size} field(s):\n"
  overridden_fields.each do |r|
    criterion_name = r[:field].to_s.chomp('_status')
    criterion = criteria_map[criterion_name]
    title = criterion&.title || r[:field].to_s.humanize
    message += "• '#{title}' → #{r[:new_value]} (#{r[:explanation]})\n"
  end

  # ... rest of method
end
```

### Limiting URL Length

If many fields overridden, URL could get long. Consider:

```ruby
# Store overridden fields in session instead of URL
session[:overridden_fields] = overridden_fields
redirect_to edit_project_path(@project, level: @criteria_level, show_overridden: true)

# Then in edit action:
if params[:show_overridden] && session[:overridden_fields]
  @overridden_fields = session[:overridden_fields]
  session.delete(:overridden_fields)
end
```

## Accessibility Considerations

### Screen Reader Announcements

```erb
<!-- Add ARIA live region for flash messages -->
<div role="alert" aria-live="assertive" class="sr-only">
  <% if flash[:warning] %>
    <%= flash[:warning] %>
  <% end %>
</div>
```

### Keyboard Navigation

Ensure overridden fields can be reached via keyboard:

```javascript
// Set focus on first overridden field
const firstOverridden = document.querySelector('.highlight-overridden input, .highlight-overridden select');
if (firstOverridden) {
  firstOverridden.focus();
}
```

## Security Considerations

### Preventing Flash Message Injection

Always escape user input in flash messages:

```ruby
message += "• '#{ERB::Util.html_escape(criterion_name)}' → Unmet (#{ERB::Util.html_escape(r[:explanation])})\n"
```

### Validating Overridden Field Parameter

```ruby
def edit
  if params[:overridden]
    # Validate overridden field names to prevent injection
    overridden_fields = params[:overridden].split(',').select do |field|
      field.match?(/\A[a-z_]+\z/) # Only lowercase letters and underscores
    end
    @overridden_fields = overridden_fields
  end
end
```

## API JSON Response Format (Decision #1)

When API clients (JSON requests) trigger overrides, return **200 OK** with override details.

**Rationale** (Decision #1): Save succeeded - data was accepted and stored. Overrides are informational.

### Controller: Format-Specific Response

```ruby
def update
  # ... Chief analysis and save logic ...

  if @project.save
    respond_to do |format|
      format.html do
        if overridden_fields.any?
          handle_overridden_fields(overridden_fields, automated_fields)
        else
          redirect_to project_path(@project)
        end
      end

      format.json do
        # Decision #1: Return 200 OK, include override details
        response_data = {
          id: @project.id,
          status: 'updated',
          message: 'Project updated successfully'
        }

        if overridden_fields.any? || automated_fields.any?
          response_data[:automation] = {
            overridden: overridden_fields.map { |r|
              {
                field: r[:field],
                old_value: r[:old_value],
                new_value: r[:new_value],
                explanation: r[:explanation],  # English only (Decision #5)
                confidence: r[:confidence]
              }
            },
            automated: automated_fields.map { |r|
              {
                field: r[:field],
                value: r[:new_value],
                explanation: r[:explanation]  # English only (Decision #5)
              }
            }
          }
        end

        render json: response_data, status: :ok
      end
    end
  else
    # Validation failed
    respond_to do |format|
      format.html { render :edit }
      format.json { render json: @project.errors, status: :unprocessable_entity }
    end
  end
end
```

### Example JSON Responses

**Normal save (no overrides)**:

```json
{
  "id": 12345,
  "status": "updated",
  "message": "Project updated successfully"
}
```

**Save with overrides**:

```json
{
  "id": 12345,
  "status": "updated",
  "message": "Project updated successfully",
  "automation": {
    "overridden": [
      {
        "field": "floss_license_osi_status",
        "old_value": "Met",
        "new_value": "Unmet",
        "explanation": "Detected license (Proprietary) is not OSI-approved",
        "confidence": 5
      }
    ],
    "automated": [
      {
        "field": "contribution_status",
        "value": "Met",
        "explanation": "CONTRIBUTING.md file found in repository"
      }
    ]
  }
}
```

**Chief analysis failed** (Decision #6):

```json
{
  "error": "Automated analysis failed",
  "message": "Some fields could not be validated automatically",
  "unvalidated_fields": [
    "floss_license_osi_status",
    "sites_https_status"
  ],
  "saved_fields": [
    "description_good_status"
  ]
}
```

## i18n Translations (Decision #5)

Add to `config/locales/en.yml`:

```yaml
en:
  projects:
    edit:
      aria_automated: "This field was automatically filled"
      aria_overridden: "This field value was corrected by automation"
      automated_tooltip: "We filled this in based on project analysis"
      overridden_tooltip: "We corrected this value based on project analysis"

    update:
      chief_overrode:
        one: "We corrected 1 field based on project analysis:"
        other: "We corrected %{count} fields based on project analysis:"

      override_detail: "'%{criterion}' changed from '%{old}' to '%{new}' — %{explanation}"

      chief_automated:
        one: "We automatically filled 1 field: %{fields}"
        other: "We automatically filled %{count} fields: %{fields}"

      analysis_failed:
        one: "Warning: Automated analysis failed for 1 field (%{fields}). Your other changes were saved."
        other: "Warning: Automated analysis failed for %{count} fields (%{fields}). Your other changes were saved."

      save_failed: "Failed to save project changes. Please try again."
      updated: "Project successfully updated!"
```

Add to `config/locales/fr.yml` (example):

```yaml
fr:
  projects:
    edit:
      aria_automated: "Ce champ a été rempli automatiquement"
      aria_overridden: "Cette valeur a été corrigée par l'automatisation"
      automated_tooltip: ...
      overridden_tooltip: ...

    update:
      chief_overrode:
        one: ...
        other: ...

      override_detail: "'%{criterion}' changé de '%{old}' à '%{new}' — %{explanation}"

      chief_automated:
        one: "Nous avons rempli automatiquement 1 champ: %{fields}"
        other: "Nous avons rempli automatiquement %{count} champs: %{fields}"

      analysis_failed:
        one: "Attention: L'analyse automatisée a échoué pour 1 champ (%{fields}). Vos autres changements ont été enregistrés."
        other: "Attention: L'analyse automatisée a échoué pour %{count} champs (%{fields}). Vos autres changements ont été enregistrés."

      save_failed: ...
      updated: ...
```

**Note on JSON responses** (Decision #5):

- English only for now (API clients don't provide locale context)
- `explanation` strings from detectives are English-only
- Future: Could add `Accept-Language` header support if needed

## Detective Architecture: OVERRIDABLE_OUTPUTS (Decision #6)

Each detective must declare which outputs can override user input (confidence >= 4).

### Example: FlossLicenseDetective

```ruby
# app/lib/floss_license_detective.rb
class FlossLicenseDetective
  INPUTS = %i[repo_url].freeze
  OUTPUTS = %i[floss_license_osi_status osps_le_03_01_status].freeze

  # Decision #6: Declare which outputs can override user input
  OVERRIDABLE_OUTPUTS = %i[floss_license_osi_status osps_le_03_01_status].freeze

  # ... rest of detective code
end
```

### Example: NameFromUrlDetective

```ruby
# app/lib/name_from_url_detective.rb
class NameFromUrlDetective
  INPUTS = %i[repo_url].freeze
  OUTPUTS = %i[name].freeze

  # Decision #6: This detective CANNOT override (suggestions only)
  OVERRIDABLE_OUTPUTS = [].freeze

  # ... rest of detective code
end
```

### Usage in Controller

```ruby
# Find all potentially overridable fields
def find_overridable_fields(level, changed_fields)
  overridable = Set.new
  Chief::ALL_DETECTIVES.each do |detective_class|
    overridable.merge(detective_class::OVERRIDABLE_OUTPUTS)
  end

  # Return intersection of changed fields and overridable fields
  (changed_fields || []).select { |f| overridable.include?(f) }
end
```

## Summary: Key Implementation Points

1. **Two highlight colors** (Decision #2):
   - Orange (.highlight-overridden): Chief changed non-'?' value
   - Yellow (.highlight-automated): Chief filled in '?' value

2. **Server-side rendering** (Decision #4):
   - CSS classes added in controller + view
   - Icons (🤖, ⚠️) added in view
   - ARIA labels for accessibility
   - Works without JavaScript

3. **i18n throughout** (Decision #5):
   - Flash messages use t() helper
   - JSON explanations English-only (no locale context)
   - All user-facing text translatable

4. **API returns 200 OK** (Decision #1):
   - Overrides included in `automation` key
   - Save succeeded, overrides are informational

5. **Error handling** (Decision #6):
   - OVERRIDABLE_OUTPUTS declares override capability
   - On Chief failure: save non-overridable, keep user input for overridable
   - Return 422 for JSON, warning flash for HTML

6. **Simple logging** (Decision #7):
   - Rails.logger.info for overrides
   - Include project ID, user ID, field list

7. **Always redirect to edit** when overriding:
   - Never redirect to show page
   - Include highlights and first-field anchor
   - Flash explains what was changed and why

8. **Testing strategy**:
   - Mock Chief for controlled override scenarios
   - Test both HTML and JSON responses
   - Verify CSS classes appear server-side
   - System tests for full user flow
