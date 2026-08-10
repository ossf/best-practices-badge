# Converting `NAME_status` Fields to Raw Integers for Memory Optimization

## Goal

Reduce memory object creation in the Ruby application by converting hundreds of `NAME_status` fields in the projects table from VARCHAR strings to PostgreSQL `smallint` integers (0-3).

## Decision: Raw Integer Approach (Not Rails Enums)

**We are implementing the raw integer approach**, not Rails ActiveRecord enums.

### Rationale

1. **Maximum Memory Efficiency**: Raw integers are immediate values (Fixnum) with zero object allocation, while Rails enum symbols are heap-allocated objects
2. **True Type Sharing**: Single `CriterionStatus` module serves all 193 status fields with no duplication
3. **No Method Namespace Pollution**: Avoids generating hundreds of predicate methods (`.met?`, `.unmet?`, etc.)
4. **Simpler Implementation**: ~26 targeted code changes vs complex enum declarations for 193 fields
5. **100% Backward Compatible**: External API remains unchanged (strings in/out)
6. **Optimal Storage**: PostgreSQL `smallint` (2 bytes) for maximum database efficiency

### Trade-offs Accepted

- No Rails enum conveniences (predicate methods, string setters)
- Manual conversion at controller/view boundaries
- Integer comparisons in code (`== 3` instead of `.met?`)

These trade-offs are acceptable given the significant memory and storage benefits.

## Analysis

### Current State

We are receiving a massive number of queries that are causing increasing memory use. Every load of a project record causes many string objects to be created.

When examining the memory use, one thing is striking:

- There are hundreds of `NAME_status` fields stored as VARCHAR/TEXT in PostgreSQL
- Each field value creates a new String object in Ruby when loaded
- With hundreds of status fields per Project record, this means hundreds of String allocations per record

All of these values should be a mapping to the same underlying data type,
if possible. That's because all status values have the same 4 possible values:

* '?' => 0 (default. We want this to be 0 because it's the default)
* 'Unmet' => 1
* 'N/A' => 2
* 'Met' => 3 (We want this to be 3, so it takes 2 bit flips to go
  from '?' to 'Met')

All status values should map to a *single* enumerated type, since they
all have the same possibilities. It would much more confusing if there
was a different mapping.

**Database Type**: PostgreSQL `smallint` (2 bytes) is ideal for these values:

- Range: -32,768 to 32,767 (more than sufficient for 0-3)
- Storage: 2 bytes per field vs 4 bytes for `integer`
- With 193 status fields: **386 bytes vs 772 bytes per project**
- 50% storage reduction compared to `integer`, ~80% compared to VARCHAR

### Proposed Solution: Rails Enums with Integer Storage

**Use Rails `enum` feature with integer database storage**

#### Benefits

1. ✅ **Database Storage**: 2-byte smallints instead of VARCHAR/TEXT (50% smaller than integers)
2. ✅ **Ruby Memory**: Automatic symbol interning - only one Symbol object per unique value across all records
3. ✅ **Memory Savings**: Hundreds of status fields sharing a few symbol objects instead of creating hundreds of String objects per record
4. ✅ **API Improvements**: Clean Ruby API with predicate methods (`warnings.met?`, `warnings.unmet!`)
5. ✅ **Database Portability**: Works identically on other databases (not PostgreSQL-specific)
6. ✅ **Simpler Migration**: Standard Rails pattern

#### Example of what to avoid

We don't want this, if we can avoid it:

```ruby
class Project < ApplicationRecord
  # Common status values for most criteria
  enum floss_license_status: { '?' => 0, 'Unmet' => 1, 'Met' => 2, 'N/A' => 3 }
  enum build_status: { '?' => 0, 'Unmet' => 1, 'Met' => 2, 'N/A' => 3 }
  enum test_status: { '?' => 0, 'Unmet' => 1, 'Met' => 2, 'N/A' => 3 }
  # ... hundreds more
end
```

All status values should map to a *single* enumerated type, since they
all have the same possibilities.

### Rejected Alternative: PostgreSQL Native Enums (Not Recommended)

PostgreSQL native enum types would:

- ✅ Store as 4-byte integers in PostgreSQL
- ❌ Still create new String objects in Ruby by default
- ❌ Require explicit freezing/interning: `def status; super&.freeze; end`
- ❌ PostgreSQL-specific (not portable)
- ❌ More complex to modify enum values later

### Alternative Approach: Raw Integers with Custom Mapping (Recommended for Maximum Efficiency)

**Store as integers in PostgreSQL, keep as integers in Ruby, map only at serialization boundaries**

This is the most memory-efficient approach and deserves serious consideration.

#### Implementation

```ruby
class Project < ApplicationRecord
  # Single source of truth for all criterion status values, for quick lookup.
  # E.g., "CRITERION_STATUS[3]" is 'Met'.
  CRITERION_STATUS = ['?', 'Unmet', 'N/A', 'Met'].freeze

  # Derived hash for fast reverse lookups (name to integer).
  CRITERION_STATUS_BY_NAME = CRITERION_STATUS.each_with_index.to_h { |name, idx| [name, idx] }.freeze

  # Constant integers
  CRITERION_UNKNOWN = CRITERION_STATUS_BY_NAME['?'] # 0
  CRITERION_UNMET = CRITERION_STATUS_BY_NAME['Unmet'] # 1
  CRITERION_NA = CRITERION_STATUS_BY_NAME['N/A'] # 2
  CRITERION_MET = CRITERION_STATUS_BY_NAME['Met'] # 3

  # Status fields stored as integers (0-3) in database and Ruby
  # No enum declarations needed - use integers directly
end
```

#### Benefits

1. ✅ **Maximum Memory Efficiency**: Integers are immediate values in Ruby (Fixnum) - no object allocation for small integers
2. ✅ **True Type Sharing**: Single array constant used for ALL status fields
3. ✅ **Fastest Access**: Direct integer comparison in Ruby (`status == 3` vs symbol comparison)
4. ✅ **No Method Pollution**: No hundreds of generated predicate methods cluttering the namespace
5. ✅ **Simpler Code**: `project.warnings_status == 3` is clear and direct
6. ✅ **Optimal Database Storage**: Use PostgreSQL `smallint` (2 bytes) for maximum efficiency
7. ✅ **Clean Serialization**: Convert to strings only at API/view boundaries where needed
8. ✅ **100% Backward Compatible**: External API interface unchanged - clients continue using strings

#### Drawbacks

1. ❌ **Manual Mapping Required**: Need explicit conversion for JSON/views: `CRITERION_STATUS[status_value]`
2. ❌ **No Predicate Methods**: Can't use `project.warnings_status.met?` - must use `project.warnings_status == 3`
3. ❌ **No Setter Convenience**: Can't use `project.warnings_status = :met` - must use integer or convert from string
4. ❌ **Magic Numbers in Code**: Direct integer comparisons less readable than symbols (though constants can help)

#### Memory Comparison

**Rails Enum Approach (per Project instance):**

- Hundreds of Symbol references (symbols interned globally, but still objects)
- Symbol overhead: ~40 bytes per unique symbol + pointer in each instance

**Raw Integer Approach (per Project instance):**

- Hundreds of Fixnum immediate values (0 bytes object allocation)
- Total overhead: 0 bytes for status values themselves

**Estimated savings per Project instance: Several KB**

#### Code Patterns

```ruby
# Setting values from user input (e.g., form params)
project.warnings_status = Project::CRITERION_STATUS_BY_NAME[params[:status]]

# Reading for display (JSON, views)
{ warnings_status: Project::CRITERION_STATUS[project.warnings_status] }

# Comparisons in business logic
if project.warnings_status == 3  # Met
  # Could use: Project::CRITERION_STATUS.index('Met')
  # Or define: CRITERION_MET = 3 for readability
end
```

#### Why This Is More Efficient Than Rails Enums

Rails enums convert integers to symbols automatically. While symbols are interned (shared across all instances), they are still heap-allocated objects. In contrast:

- **Small integers (Fixnum)**: Encoded directly in the VALUE (pointer-sized), no heap allocation
- **Symbols**: Require heap allocation, symbol table entry, and object overhead

With hundreds of status fields per Project, the difference compounds significantly.

## Expected Memory Impact

### Current (String-based)

- Each Project record: ~hundreds of String allocations
- 1000 Project records: ~hundreds of thousands of String objects

### After Rails Enum (Symbol-based)

- Each Project record: References to ~10 shared Symbol objects
- 1000 Project records: Still only ~10 Symbol objects total
- **Estimated savings**: Dozens of KB per Project instance

## JSON and editing

We generate JSON. When doing so, we need to convert these status values
back to strings (e.g., "Met") since the integers will mean little to
readers, and switching to integers would also be backwards-incompatible.

When we accept edit requests, we'll need to ensure that only valid
status values are accepted (we do that anyway) and they'll have the
same text inputs as current. This change to enums should be
entirely internal to the application and those with direct access to
the database, and should *not* impact external users in any way.

## Implementation Considerations

1. **Bulk Migration**: Converting hundreds of columns will be a large migration
2. **Backward Compatibility**: Ensure API compatibility if external code depends on string values
3. **Testing**: Comprehensive tests to ensure enum mappings are correct
4. **Documentation**: Update API documentation to reflect new enum methods
5. **Performance**: The migration itself may take time on large datasets (use batching if needed)

## Raw Integer Approach: Conversion Strategy

Based on analysis of the codebase, here's how the raw integer approach would handle data flow:

### Current Data Flow

1. **HTML Forms** (app/views/projects/_status_chooser.html.erb):
   - Radio buttons with string values: `'Met'`, `'Unmet'`, `'N/A'`, `'?'`
   - Example: `f.radio_button status_symbol, 'Met', label: t('criterion_status.Met')`

2. **JavaScript** (app/assets/javascripts/project-form.js):
   - Reads string values from DOM: `checkedInput.value`
   - Compares as strings: `if (status === 'Met')`

3. **Server Input** (app/controllers/projects_controller.rb):
   - Receives params with string values
   - Currently passes directly to ActiveRecord for storage as strings

4. **Server Output** (app/views/projects/_project.json.jbuilder):
   - Uses `project.attributes` to get all fields
   - Currently returns strings directly to JSON

### External Interface Compatibility

**IMPORTANT**: The raw integer approach maintains **100% backward compatibility** with external interfaces.

**For external API consumers and programmatic updates:**

1. **Sending data** (POST/PATCH to projects controller):
   - Send: `{ "warnings_status": "Met" }` (string)
   - Controller receives: `"Met"` string in params
   - `before_action` converts: `"Met"` → `3` (integer)
   - Database stores: `3` (smallint)
   - **No API change required!**

2. **Receiving data** (GET /projects/:id.json):
   - Database has: `3` (smallint)
   - ActiveRecord loads: `3` (integer)
   - Jbuilder converts: `3` → `"Met"` (string)
   - JSON returns: `{ "warnings_status": "Met" }`
   - **No API change required!**

**Result**: External clients see no difference - strings in, strings out!

### Required Changes for Raw Integer Approach

#### 1. No Changes Needed

- **HTML forms**: Continue using string values in radio buttons
- **JavaScript**: Continue using string comparisons and DOM reads
- **External API**: JSON continues to expose strings (conversion at boundaries)
- **API consumers**: No changes needed - send/receive strings as before

#### 2. Changes Required

**A. Create Shared Constants Module** (lib/criterion_status.rb)

Create a new module to hold status constants, available across the entire application:

```ruby
# frozen_string_literal: true

# Copyright the Linux Foundation and the
# OpenSSF Best Practices badge contributors
# SPDX-License-Identifier: MIT

# Shared constants for criterion status values
# Used across models, controllers, views, and helpers to represent
# the four possible states of a criterion (unknown, unmet, N/A, met)
module CriterionStatus
  # Single source of truth for all criterion status values
  # Array index corresponds to database integer value
  STATUS_VALUES = ['?', 'Unmet', 'N/A', 'Met'].freeze

  # Derived hash for fast reverse lookups (name to integer)
  # Used for converting user input strings to database integers
  STATUS_BY_NAME = STATUS_VALUES.each_with_index.to_h { |name, idx| [name, idx] }.freeze

  # Named constants for readable code comparisons
  # Derived from STATUS_BY_NAME to ensure consistency
  UNKNOWN = STATUS_BY_NAME['?'] # 0
  UNMET = STATUS_BY_NAME['Unmet'] # 1
  NA = STATUS_BY_NAME['N/A'] # 2
  MET = STATUS_BY_NAME['Met'] # 3
end
```

**Why `lib/` directory?**

- No circular dependencies (loads before models)
- Available everywhere (models, controllers, views, helpers)
- Clear namespace (`CriterionStatus::MET`)
- Follows existing pattern (similar to `lib/locale_utils.rb`)
- Framework-independent (pure Ruby constants)

**B. Controller Params Processing** (app/controllers/projects_controller.rb)

Add a before_action to convert incoming string params to integers:

```ruby
class ProjectsController < ApplicationController
  before_action :convert_status_params, only: [:create, :update]

  private

  # Convert all status fields from strings to integers in hash h.
  # This modifies the hash IN PLACE.
  # Invalid values are left as-is and will be caught by model validations.
  # @param h [Hash] The hash to modify (typically params[:project])
  # @return [void]
  def convert_status_params_of_hash!(h)
    Project::ALL_CRITERIA_STATUS.each do |status_field|
      next unless h[status_field]

      string_value = h[status_field]
      next if string_value.is_a?(Integer)

      integer_value = CriterionStatus::STATUS_BY_NAME[string_value]

      if integer_value
        h[status_field] = integer_value
      else
        # Invalid value - leave as-is so model validation can reject it
        Rails.logger.warn "Invalid status value for #{status_field}: #{string_value.inspect}"
      end
    end
  end

  # Convert all status fields in params[:project] from strings to integers
  # @return [void]
  def convert_status_params
    return unless params[:project]

    convert_status_params_of_hash!(params[:project])
  end
end
```

**Important**: Invalid values are NOT removed from the hash. They remain as strings so that model validations can catch them and provide proper error messages to users. This follows the Rails pattern: "controller converts valid input, model validates all input."

**C. JSON Serialization** (app/views/projects/_project.json.jbuilder)

Convert integer values back to strings for API output.

**Recommended approach**: Transform only status fields explicitly:

```ruby
# Start with project attributes
transformed_attrs = project.attributes.dup

# Convert status fields from integers to strings for API compatibility
Project::ALL_CRITERIA_STATUS.each do |status_field|
  status_value = transformed_attrs[status_field.to_s]
  if status_value.is_a?(Integer)
    transformed_attrs[status_field.to_s] = CriterionStatus::STATUS_VALUES[status_value]
  end
end

# Then apply key transformation for baseline fields
transformed_attrs = transformed_attrs.transform_keys do |key|
  ProjectsHelper::BASELINE_FIELD_DISPLAY_NAME_MAP.fetch(key, key)
end

json.merge! transformed_attrs
# ... rest of jbuilder code
```

**D. View Helpers** (if status values displayed in ERB views)

Add helper method for displaying status in views:

```ruby
module ProjectsHelper
  def display_status(status_integer)
    CriterionStatus::STATUS_VALUES[status_integer]
  end
end
```

### Difficulty Assessment

**Is this difficult?** No, the conversion is straightforward:

1. **String → Integer (Input)**: One before_action filter in controller (10-15 lines)
2. **Integer → String (Output)**: Modify jbuilder template (5-10 lines)
3. **Model Constants**: Add CRITERION_STATUS constants (5 lines)
4. **View Helpers** (if needed): Simple array lookup (2-3 lines)

**Total implementation**: ~30-40 lines of code changes

**Key Advantages**:

- HTML/JavaScript completely unchanged (no frontend work)
- External API backward compatible (still serves strings)
- Conversion happens only at boundaries (controller input, JSON output)
- All business logic can use fast integer comparisons

**Potential Issues**:

- Need to update any direct comparisons in Ruby code (e.g., `if project.status == 'Met'` → `if project.status == CriterionStatus::MET`)
- Need to audit code for string assumptions (see audit below)
- Migration needs careful handling for existing data

## Code Audit: String Status Value Assumptions

A comprehensive audit of the codebase identified all locations that assume status values are strings. These locations must be updated to work with integers when implementing the raw integer approach.

### Critical Files Requiring Updates

#### 1. **app/lib/chief.rb** - Chief class

**Line 70**: Comparison with '?' string

```ruby
# CURRENT:
elsif !project.attribute_present?(key) || project[key].blank? || project[key] == '?'

# NEEDS TO BECOME:
elsif !project.attribute_present?(key) || project[key].blank? || project[key] == CriterionStatus::UNKNOWN
```

**Impact**: HIGH - Chief is the main autofill orchestrator, runs on project creation/update

---

#### 2. **app/models/project.rb** - Project model

**Lines 817, 819, 821, 823**: Achievement status comparisons and assignments

```ruby
# CURRENT:
if self[:"badge_percentage_#{level - 1}"] >= 100
  return if self[achieved_previous_level] == 'Met'
  self[achieved_previous_level] = 'Met'
else
  return if self[achieved_previous_level] == 'Unmet'
  self[achieved_previous_level] = 'Unmet'
end

# NEEDS TO BECOME:
if self[:"badge_percentage_#{level - 1}"] >= 100
  return if self[achieved_previous_level] == CriterionStatus::MET
  self[achieved_previous_level] = CriterionStatus::MET
else
  return if self[achieved_previous_level] == CriterionStatus::UNMET
  self[achieved_previous_level] = CriterionStatus::UNMET
end
```

**Impact**: HIGH - Controls badge level achievement status

---

#### 3. **Detective Files** - All detectives return status string values

All detective classes return changeset hashes with string values that Chief applies to the project.

**Files affected** (20+ instances across):

- `app/lib/build_detective.rb`
- `app/lib/floss_license_detective.rb`
- `app/lib/hardened_sites_detective.rb`
- `app/lib/project_sites_https_detective.rb`
- `app/lib/repo_files_examine_detective.rb`
- `app/lib/subdir_file_contents_detective.rb`

**Pattern examples**:

```ruby
# CURRENT:
{ value: 'Met', confidence: 5, explanation: '...' }
{ value: 'Unmet', confidence: 3, explanation: '...' }

# NEEDS TO BECOME:
{ value: CriterionStatus::MET, confidence: 5, explanation: '...' }
{ value: CriterionStatus::UNMET, confidence: 3, explanation: '...' }
```

**Counts**:

- 13 instances of `value: 'Met'`
- 7 instances of `value: 'Unmet'`

**Impact**: HIGH - Detectives provide autofill values for criteria

---

#### 4. **app/views/projects/show_markdown.erb** - Markdown export view

**Line 12**: Case statement for checkbox rendering

```ruby
# CURRENT:
def criterion_to_checkbox(value)
  case value
  when 'Met', 'N/A'
    '[x]'
  else
    '[ ]'
  end
end

# NEEDS TO BECOME:
def criterion_to_checkbox(value)
  case value
  when CriterionStatus::MET, CriterionStatus::NA
    '[x]'
  else
    '[ ]'
  end
end
```

**Impact**: MEDIUM - Affects markdown export feature

---

### Files NOT Requiring Updates

These files contain status value strings but don't need changes:

1. **app/views/projects/_status_chooser.html.erb** - Radio button values remain as strings (form inputs)
2. **app/assets/javascripts/project-form.js** - JavaScript continues using strings
3. **app/controllers/projects_controller.rb** - Only URL-related '?' comment, not status

---

### Summary of Required Changes

| File | Lines | Changes | Priority |
|------|-------|---------|----------|
| `app/lib/chief.rb` | 1 | Replace `== '?'` with `== CriterionStatus::UNKNOWN` | HIGH |
| `app/models/project.rb` | 4 | Replace string comparisons/assignments with constants | HIGH |
| Detective files (6 files) | 20 | Replace string values with CriterionStatus constants | HIGH |
| `app/views/projects/show_markdown.erb` | 1 | Update case statement | MEDIUM |
| **Total** | **~26 lines** | **Straightforward find/replace patterns** | |

---

### Migration Strategy for Code Updates

1. **Create CriterionStatus module first** (`lib/criterion_status.rb`)
2. **Update all detectives** - Change return values to use constants
3. **Update Chief** - Change comparison logic
4. **Update Project model** - Change achievement status logic
5. **Update views** - Change markdown export helper
6. **Update controller** - Add `before_action :convert_status_params`
7. **Update jbuilder** - Add integer-to-string conversion for JSON output
8. **Run tests** - Ensure all detective tests pass with new values
9. **Only then migrate database** - After code is ready for integers

### Database Migration Notes

**Column type**: Use PostgreSQL `smallint` (not `integer`)

```ruby
# Migration example (one of 193 status fields)
change_column :projects, :warnings_status, :smallint, using: 'warnings_status::smallint'
```

**Data conversion during migration**:

- '?' → 0
- 'Unmet' → 1
- 'N/A' → 2
- 'Met' → 3

**Migration considerations**:

- Large table with many columns - may need batching or careful timing
- Use `USING` clause to convert existing string data
- Consider adding check constraint: `CHECK (warnings_status BETWEEN 0 AND 3)`
- Default values should be `0` (for '?')

## Conclusion

The raw integer approach with PostgreSQL `smallint` storage provides maximum memory and storage efficiency for the 193 status fields per project. By storing integers internally and converting to/from strings only at API boundaries, we achieve:

- **~75-85% database storage reduction** (VARCHAR → smallint)
- **Zero Ruby object allocation** for status values (immediate Fixnum values)
- **100% backward compatible external API** (strings in, strings out)
- **Simple, maintainable implementation** (~26 code changes)

This approach is superior to Rails enums for this specific use case due to the large number of fields (193) and the need for maximum memory efficiency under high query load.

---

## Implementation Migration Plan

### Overview

This plan outlines the step-by-step process to migrate from VARCHAR status fields to smallint storage with the raw integer approach.

**Total Estimated Effort**: ~4-6 hours of development + testing
**Risk Level**: MEDIUM (many changes, but straightforward patterns)
**Backward Compatibility**: 100% (external API unchanged)

### Prerequisites

- [ ] All tests passing on current codebase
- [ ] Database backup available
- [ ] Staging environment available for testing
- [ ] Understanding of rollback procedures

### Phase 1: Create Infrastructure (No Database Changes)

**Goal**: Add constants and conversion infrastructure without changing database

#### Step 1.1: Create CriterionStatus Module

**File**: `lib/criterion_status.rb` (new file)

**Actions**:

1. Create new file with frozen string literal header
2. Add copyright and license headers
3. Define module with constants and mappings
4. Add inline documentation

**Testing**:

- Rails console: `CriterionStatus::STATUS_VALUES` should return array
- Rails console: `CriterionStatus::MET` should return `3`
- Rails console: `CriterionStatus::STATUS_BY_NAME['Met']` should return `3`

**Success Criteria**: Module loads without errors, constants accessible

#### Step 1.2: Add Helper Methods to ProjectsHelper

**File**: `app/helpers/projects_helper.rb`

**Actions**:

1. Add `status_to_string(value)` method using `CriterionStatus::STATUS_VALUES[value]`
2. Add inline documentation

**Testing**:

- Helper test: verify `status_to_string(3)` returns `'Met'`
- Helper test: verify `status_to_string(0)` returns `'?'`

**Success Criteria**: Helper methods work correctly

#### Step 1.3: Verify Phase 1

**Commands**:

```bash
rails test
rake rubocop
rake rails_best_practices
```

**Success Criteria**: All tests pass, no linting errors, no functionality changes

---

### Phase 2: Update Application Code (Still No Database Changes)

**Goal**: Update all Ruby code to use CriterionStatus constants

**Important**: Database still has strings at this point. Code will work with BOTH strings and integers during transition.

#### Step 2.1: Update Detective Files

**Files** (6 files, 20 changes):

- `app/lib/build_detective.rb`
- `app/lib/floss_license_detective.rb`
- `app/lib/hardened_sites_detective.rb`
- `app/lib/project_sites_https_detective.rb`
- `app/lib/repo_files_examine_detective.rb`
- `app/lib/subdir_file_contents_detective.rb`

**Actions**:

1. Find all `value: 'Met'` → replace with `value: CriterionStatus::MET`
2. Find all `value: 'Unmet'` → replace with `value: CriterionStatus::UNMET`
3. Find all `value: 'N/A'` → replace with `value: CriterionStatus::NA`

**Pattern**:

```ruby
# BEFORE:
{ value: 'Met', confidence: 5, explanation: '...' }

# AFTER:
{ value: CriterionStatus::MET, confidence: 5, explanation: '...' }
```

**Testing**:

- Run detective unit tests: `rails test test/unit/lib/*detective_test.rb`
- Verify detectives return integer values

**Success Criteria**: All detective tests pass

#### Step 2.2: Update Chief

**File**: `app/lib/chief.rb`

**Actions**:

1. Line 70: Replace `project[key] == '?'` with `project[key] == CriterionStatus::UNKNOWN || project[key] == '?'`
   - **Note**: During transition, accept BOTH string and integer until migration complete

**Pattern**:

```ruby
# BEFORE:
elsif !project.attribute_present?(key) || project[key].blank? || project[key] == '?'

# AFTER (transition-safe):
elsif !project.attribute_present?(key) || project[key].blank? ||
      project[key] == CriterionStatus::UNKNOWN || project[key] == '?'
```

**Testing**:

- Run chief unit tests: `rails test test/unit/lib/chief_test.rb`
- Test autofill functionality manually in development

**Success Criteria**: Chief tests pass, autofill works

#### Step 2.3: Update Project Model

**File**: `app/models/project.rb`

**Actions**:

1. Lines 33-34: Update and rename STATUS_CHOICE constants
2. Lines 817-823: Update achievement status comparisons/assignments

**Pattern for constants**:

```ruby
# BEFORE:
STATUS_CHOICE = %w[? Met Unmet].freeze
STATUS_CHOICE_NA = (STATUS_CHOICE + %w[N/A]).freeze

# AFTER (transition-safe - accepts both integers and strings):
STATUS_CHOICE_WITHOUT_NA = [
  CriterionStatus::UNKNOWN, CriterionStatus::MET, CriterionStatus::UNMET,
  '?', 'Met', 'Unmet'
].freeze
STATUS_CHOICE_NA = (STATUS_CHOICE_WITHOUT_NA + [CriterionStatus::NA, 'N/A']).freeze

# Note: Renamed STATUS_CHOICE to STATUS_CHOICE_WITHOUT_NA for clarity
```

**Pattern for achievement status**:

```ruby
# BEFORE:
if self[:"badge_percentage_#{level - 1}"] >= 100
  return if self[achieved_previous_level] == 'Met'
  self[achieved_previous_level] = 'Met'
else
  return if self[achieved_previous_level] == 'Unmet'
  self[achieved_previous_level] = 'Unmet'
end

# AFTER (transition-safe):
if self[:"badge_percentage_#{level - 1}"] >= 100
  return if self[achieved_previous_level] == CriterionStatus::MET ||
            self[achieved_previous_level] == 'Met'
  self[achieved_previous_level] = CriterionStatus::MET
else
  return if self[achieved_previous_level] == CriterionStatus::UNMET ||
            self[achieved_previous_level] == 'Unmet'
  self[achieved_previous_level] = CriterionStatus::UNMET
end
```

**Important**: The STATUS_CHOICE constants are used in model validations (lines 298-301). During transition, they must accept BOTH integers and strings. After Phase 4 cleanup, remove string values.

**Testing**:

- Run project model tests: `rails test test/models/project_test.rb`
- Test badge achievement logic
- Test that validations accept integers
- Test that validations still accept strings (during transition)

**Success Criteria**: Project tests pass, validations work with both integers and strings

#### Step 2.4: Update Markdown View

**File**: `app/views/projects/show_markdown.erb`

**Actions**:

1. Line 12: Update case statement to handle integers

**Pattern**:

```ruby
# BEFORE:
def criterion_to_checkbox(value)
  case value
  when 'Met', 'N/A'
    '[x]'
  else
    '[ ]'
  end
end

# AFTER (transition-safe):
def criterion_to_checkbox(value)
  case value
  when CriterionStatus::MET, CriterionStatus::NA, 'Met', 'N/A'
    '[x]'
  else
    '[ ]'
  end
end
```

**Testing**:

- Test markdown export manually
- Verify checkboxes render correctly

**Success Criteria**: Markdown export works

#### Step 2.5: Update Projects Controller

**File**: `app/controllers/projects_controller.rb`

**Actions**:

1. Add `before_action :convert_status_params` to the action filters
2. Add private method `convert_status_params` (see below)

**Code to add**:

```ruby
class ProjectsController < ApplicationController
  before_action :convert_status_params, only: [:create, :update]

  # ... existing code ...

  private

  # Convert all status fields from strings to integers in hash h.
  # This modifies the hash IN PLACE.
  # Invalid values are left as-is and will be caught by model validations,
  # which provide proper error messages to users.
  # @param h [Hash] The hash to modify (typically params[:project])
  # @return [void]
  def convert_status_params_of_hash!(h)
    Project::ALL_CRITERIA_STATUS.each do |status_field|
      next unless h[status_field]

      string_value = h[status_field]

      # Skip if already an integer (shouldn't happen, but be safe)
      next if string_value.is_a?(Integer)

      integer_value = CriterionStatus::STATUS_BY_NAME[string_value]

      if integer_value
        # Valid value - convert to integer
        h[status_field] = integer_value
      else
        # Invalid value - leave as-is (don't convert)
        # Model validations (project.rb:298-301) will catch it and provide error message
        # Log for security monitoring
        Rails.logger.warn "Invalid status value for #{status_field}: #{string_value.inspect}"
        # IMPORTANT: Do NOT remove the value from hash!
        # Removing it would bypass validation and silently ignore user error.
        # Leave it as a string so model validation can reject it properly.
      end
    end
  end

  # Convert incoming string status params to integers for database storage.
  # Maintains backward compatibility with external API (accepts strings).
  # @return [void]
  def convert_status_params
    return unless params[:project]

    convert_status_params_of_hash!(params[:project])
  end
end
```

**Rationale for leaving invalid values unchanged**:

- Model validations exist in `project.rb` (lines 298-301) using `STATUS_CHOICE_WITHOUT_NA` and `STATUS_CHOICE_NA`
- **During transition**: Invalid strings fail validation (not in list of valid strings/integers)
- **After migration**: Invalid strings fail validation (not in list of valid integers)
- Users receive proper Rails validation error messages (e.g., "is not included in the list")
- **If we removed invalid values**: User errors would be silently ignored (no feedback!)
- Logging provides security monitoring for suspicious input
- Separate `convert_status_params_of_hash!` method makes unit testing easier

**How validation works**:

1. Valid string (e.g., "Met") → converted to integer (3) → validation passes
2. Invalid string (e.g., "BadValue") → left as-is → validation fails → user sees error
3. This works both during transition and after migration to integers

**Testing**:

- Test project creation with form (valid status values)
- Test project updates with form (valid status values)
- **Test with invalid status values** - should return validation error, not 500 error
- Test API updates with curl/Postman
- Verify error messages are user-friendly (Rails validation errors)

**Test cases for invalid values**:

```bash
# Should fail with validation error, not crash
curl -X PATCH http://localhost:3000/en/projects/1 \
  -d 'project[warnings_status]=InvalidValue'
# Expected: 422 Unprocessable Entity with validation error
# NOT: 500 Internal Server Error
```

**Unit tests for convert_status_params_of_hash!**:

Create a test file `test/controllers/projects_controller_convert_test.rb`:

```ruby
# Test the convert_status_params_of_hash! helper method
class ProjectsControllerConvertTest < ActionController::TestCase
  setup do
    @controller = ProjectsController.new
  end

  test 'converts valid status string to integer' do
    h = { warnings_status: 'Met' }
    @controller.send(:convert_status_params_of_hash!, h)
    assert_equal CriterionStatus::MET, h[:warnings_status]
  end

  test 'converts all valid status values' do
    h = {
      warnings_status: '?',
      build_status: 'Unmet',
      test_status: 'N/A',
      floss_license_status: 'Met'
    }
    @controller.send(:convert_status_params_of_hash!, h)
    assert_equal CriterionStatus::UNKNOWN, h[:warnings_status]
    assert_equal CriterionStatus::UNMET, h[:build_status]
    assert_equal CriterionStatus::NA, h[:test_status]
    assert_equal CriterionStatus::MET, h[:floss_license_status]
  end

  test 'leaves invalid status value as string' do
    h = { warnings_status: 'InvalidValue' }
    @controller.send(:convert_status_params_of_hash!, h)
    assert_equal 'InvalidValue', h[:warnings_status]  # Left as-is
  end

  test 'leaves already-integer values unchanged' do
    h = { warnings_status: 3 }
    @controller.send(:convert_status_params_of_hash!, h)
    assert_equal 3, h[:warnings_status]
  end

  test 'handles mixed valid and invalid values' do
    h = {
      warnings_status: 'Met',      # Valid - should convert
      build_status: 'InvalidValue' # Invalid - should stay as-is
    }
    @controller.send(:convert_status_params_of_hash!, h)
    assert_equal CriterionStatus::MET, h[:warnings_status]
    assert_equal 'InvalidValue', h[:build_status]
  end
end
```

**Success Criteria**:

- Create/update works with valid string inputs
- Invalid inputs return proper validation errors (422 status)
- Log shows warnings for invalid values
- All unit tests for `convert_status_params_of_hash!` pass
- Integration tests verify end-to-end validation behavior

#### Step 2.6: Update JSON Serialization

**File**: `app/views/projects/_project.json.jbuilder`

**Actions**:

1. Replace the `transformed_attrs` logic to convert integers to strings

**Code**:

```ruby
# BEFORE:
transformed_attrs =
  project.attributes.transform_keys do |key|
    ProjectsHelper::BASELINE_FIELD_DISPLAY_NAME_MAP.fetch(key, key)
  end
json.merge! transformed_attrs

# AFTER:
# Start with project attributes
transformed_attrs = project.attributes.dup

# Convert status fields from integers to strings for API compatibility
Project::ALL_CRITERIA_STATUS.each do |status_field|
  status_value = transformed_attrs[status_field.to_s]
  if status_value.is_a?(Integer)
    transformed_attrs[status_field.to_s] = CriterionStatus::STATUS_VALUES[status_value]
  end
  # If it's still a string (during migration), leave it as-is
end

# Then apply key transformation for baseline fields
transformed_attrs = transformed_attrs.transform_keys do |key|
  ProjectsHelper::BASELINE_FIELD_DISPLAY_NAME_MAP.fetch(key, key)
end

json.merge! transformed_attrs
```

**Testing**:

- Test JSON API: `curl http://localhost:3000/en/projects/1.json`
- Verify status fields are strings in JSON output
- Verify API backward compatibility

**Success Criteria**: JSON returns strings for status fields

#### Step 2.7: Verify Phase 2

**Commands**:

```bash
rake default          # Run full CI/CD pipeline
rails test:all        # Run all tests including system tests
```

**Manual Testing Checklist**:

- [ ] Create new project via web form
- [ ] Update project status fields via web form
- [ ] Verify JSON API returns strings
- [ ] Test autofill functionality
- [ ] Test markdown export
- [ ] Test badge achievement status updates

**Success Criteria**:

- All tests pass
- All manual tests work
- Code still works with VARCHAR strings in database
- No regression in functionality

---

### Phase 3: Database Migration

**Goal**: Convert database columns from VARCHAR to smallint

**WARNING**: This phase changes the database schema. Ensure Phase 2 is 100% complete and tested.

#### Step 3.1: Create Migration File

**Commands**:

```bash
rails generate migration ConvertStatusFieldsToSmallint
```

**File**: `db/migrate/YYYYMMDDHHMMSS_convert_status_fields_to_smallint.rb`

**Migration Code**:

```ruby
# frozen_string_literal: true

# Copyright 2015-2017, the Linux Foundation, IDA, and the
# OpenSSF Best Practices badge contributors
# SPDX-License-Identifier: MIT

class ConvertStatusFieldsToSmallint < ActiveRecord::Migration[8.1]
  # Map string values to integers
  STATUS_MAPPING = {
    '?' => 0,
    'Unmet' => 1,
    'N/A' => 2,
    'Met' => 3
  }.freeze

  def up
    # Get all status field names from Criteria
    status_fields = Criteria.all.map(&:status)

    # Also include achievement status fields
    achievement_fields = %i[achieve_passing_status achieve_silver_status]

    all_fields = (status_fields + achievement_fields).uniq

    say_with_time "Converting #{all_fields.size} status fields to smallint" do
      all_fields.each_with_index do |field, index|
        say "Converting #{field} (#{index + 1}/#{all_fields.size})", :subitem

        # Create CASE statement for conversion
        case_stmt = STATUS_MAPPING.map { |str, int| "WHEN '#{str}' THEN #{int}" }.join(' ')

        # Convert column with data transformation
        execute <<-SQL
          ALTER TABLE projects
          ALTER COLUMN #{field}
          TYPE smallint
          USING (
            CASE #{field}
              #{case_stmt}
              ELSE 0
            END
          )
        SQL

        # Set default value
        change_column_default :projects, field, from: '?', to: 0

        # Add check constraint
        execute <<-SQL
          ALTER TABLE projects
          ADD CONSTRAINT check_#{field}_range
          CHECK (#{field} >= 0 AND #{field} <= 3)
        SQL
      end
    end
  end

  def down
    status_fields = Criteria.all.map(&:status)
    achievement_fields = %i[achieve_passing_status achieve_silver_status]
    all_fields = (status_fields + achievement_fields).uniq

    # Reverse mapping
    reverse_mapping = STATUS_MAPPING.invert

    say_with_time "Converting #{all_fields.size} status fields back to varchar" do
      all_fields.each_with_index do |field, index|
        say "Converting #{field} (#{index + 1}/#{all_fields.size})", :subitem

        # Drop check constraint
        execute <<-SQL
          ALTER TABLE projects
          DROP CONSTRAINT IF EXISTS check_#{field}_range
        SQL

        # Create CASE statement for reverse conversion
        case_stmt = reverse_mapping.map { |int, str| "WHEN #{int} THEN '#{str}'" }.join(' ')

        # Convert back to varchar
        execute <<-SQL
          ALTER TABLE projects
          ALTER COLUMN #{field}
          TYPE varchar
          USING (
            CASE #{field}
              #{case_stmt}
              ELSE '?'
            END
          )
        SQL

        # Set default value back
        change_column_default :projects, field, from: 0, to: '?'
      end
    end
  end
end
```

#### Step 3.2: Test Migration on Development Database

**Commands**:

```bash
# Backup development database first
pg_dump badgeapp_development > backup_before_migration.sql

# Run migration
rails db:migrate

# Verify schema
rails db:schema:dump
```

**Verification**:

1. Check schema.rb shows `t.integer` with `limit: 2` (smallint)
2. Check data in database: `rails console` then check status values
3. Verify application still works

#### Step 3.3: Test Rollback

**Commands**:

```bash
# Test rollback
rails db:rollback

# Verify data is back to strings
# Then re-migrate
rails db:migrate
```

**Success Criteria**: Rollback and re-migration work without data loss

#### Step 3.4: Run Full Test Suite After Migration

**Commands**:

```bash
RAILS_ENV=test rails db:migrate
rails test:all
rake default
```

**Success Criteria**: All tests pass with new schema

---

### Phase 4: Cleanup (Remove Transition Code)

**Goal**: Remove dual string/integer support code

#### Step 4.1: Update Chief (Remove String Support)

**File**: `app/lib/chief.rb`

**Actions**:

```ruby
# BEFORE (transition code):
elsif !project.attribute_present?(key) || project[key].blank? ||
      project[key] == CriterionStatus::UNKNOWN || project[key] == '?'

# AFTER (final):
elsif !project.attribute_present?(key) || project[key].blank? ||
      project[key] == CriterionStatus::UNKNOWN
```

#### Step 4.2: Update Project Model (Remove String Support)

**File**: `app/models/project.rb`

**Actions**:

1. Update STATUS_CHOICE constants to remove string values
2. Remove `|| == 'Met'` / `|| == 'Unmet'` dual checks from achievement status logic

**Pattern for constants**:

```ruby
# BEFORE (transition code with both integers and strings):
STATUS_CHOICE_WITHOUT_NA = [
  CriterionStatus::UNKNOWN, CriterionStatus::MET, CriterionStatus::UNMET,
  '?', 'Met', 'Unmet'
].freeze
STATUS_CHOICE_NA = (STATUS_CHOICE_WITHOUT_NA + [CriterionStatus::NA, 'N/A']).freeze

# AFTER (final - integers only):
STATUS_CHOICE_WITHOUT_NA = [
  CriterionStatus::UNKNOWN,
  CriterionStatus::MET,
  CriterionStatus::UNMET
].freeze
STATUS_CHOICE_NA = (STATUS_CHOICE_WITHOUT_NA + [CriterionStatus::NA]).freeze
```

**Pattern for achievement status**:

```ruby
# BEFORE (transition code):
if self[:"badge_percentage_#{level - 1}"] >= 100
  return if self[achieved_previous_level] == CriterionStatus::MET ||
            self[achieved_previous_level] == 'Met'
  self[achieved_previous_level] = CriterionStatus::MET
else
  return if self[achieved_previous_level] == CriterionStatus::UNMET ||
            self[achieved_previous_level] == 'Unmet'
  self[achieved_previous_level] = CriterionStatus::UNMET
end

# AFTER (final):
if self[:"badge_percentage_#{level - 1}"] >= 100
  return if self[achieved_previous_level] == CriterionStatus::MET
  self[achieved_previous_level] = CriterionStatus::MET
else
  return if self[achieved_previous_level] == CriterionStatus::UNMET
  self[achieved_previous_level] = CriterionStatus::UNMET
end
```

#### Step 4.3: Update Markdown View (Remove String Support)

**File**: `app/views/projects/show_markdown.erb`

**Actions**: Remove `'Met', 'N/A'` from case statement, keep only integer constants

#### Step 4.4: Remove rails_best_practices Exception

**File**: `config/rails_best_practices.yml`

**Actions**:

Remove the exception for `ProjectsHelper#status_to_string` that was added during Phase 2.

```yaml
# BEFORE (with Phase 2 exception):
RemoveUnusedMethodsInHelpersCheck: { except_methods: [
  'UnsubscribeHelper#generate_unsubscribe_url', # Used in app/mailers/report_mailer.rb
  'ProjectsHelper#status_to_string' # Will be used post-Phase 3 migration; tool doesn't detect it
  ] }

# AFTER (exception removed):
RemoveUnusedMethodsInHelpersCheck: { except_methods: [
  'UnsubscribeHelper#generate_unsubscribe_url' # Used in app/mailers/report_mailer.rb
  ] }
```

**Rationale**: The exception was needed during Phase 2 because the method wasn't being used yet. After Phase 3 (database migration), if the method is still not being actively called in the codebase, it should either be used or removed entirely.

#### Step 4.5: Verify Cleanup

**Commands**:

```bash
rake default
rails test:all
```

**Success Criteria**: All tests pass, no string status values in code

---

### Phase 5: Deployment and Monitoring

#### Step 5.1: Deploy to Staging

**Actions**:

1. Deploy all code changes to staging
2. Run migration on staging database
3. Run full test suite on staging
4. Manual QA testing on staging
5. Monitor staging for 24-48 hours

**Success Criteria**: Staging stable with no errors

#### Step 5.2: Deploy to Production

**Pre-deployment Checklist**:

- [ ] Staging deployment successful
- [ ] All tests passing
- [ ] Database backup completed
- [ ] Rollback procedure documented
- [ ] Monitoring alerts configured

**Deployment Steps**:

1. Enable maintenance mode (optional)
2. Backup production database
3. Deploy code changes
4. Run migration (will take time - 193 columns)
5. Verify migration completed successfully
6. Disable maintenance mode
7. Monitor application logs
8. Monitor error rates
9. Monitor API requests/responses

**Success Criteria**:

- Migration completes without errors
- No increase in error rates
- API responses remain unchanged
- Application performance stable or improved

#### Step 5.3: Post-Deployment Validation

**Within 1 hour**:

- [ ] Verify JSON API returns strings
- [ ] Test project creation
- [ ] Test project updates
- [ ] Check error logs for status-related errors

**Within 24 hours**:

- [ ] Monitor memory usage (should decrease)
- [ ] Monitor database size (should decrease)
- [ ] Verify no user-reported issues

**Success Criteria**: No issues detected, memory/storage improvements visible

---

### Rollback Plan

#### If Issues Found Before Database Migration

**Action**: Simply revert code changes via git
**Impact**: None - database unchanged

#### If Issues Found After Database Migration

**Option 1: Rollback Migration**

```bash
rails db:rollback
```

Then revert code changes.

**Option 2: Fix Forward**
If migration succeeded but code has bugs, fix code bugs without rolling back migration.

**Option 3: Emergency Database Restore**
Only if catastrophic failure:

```bash
pg_restore backup_file.sql
```

---

### Risk Assessment

| Risk | Likelihood | Impact | Mitigation |
|------|-----------|--------|------------|
| Migration fails mid-way | LOW | HIGH | Test on staging first, have database backup |
| Data loss during conversion | LOW | CRITICAL | Use CASE statement in migration, test rollback |
| Performance degradation | LOW | MEDIUM | smallint is faster than VARCHAR |
| External API breaks | VERY LOW | HIGH | Conversion at boundaries maintains compatibility |
| Code bugs with integer handling | MEDIUM | MEDIUM | Comprehensive testing, dual string/integer support during transition |
| Chief autofill issues | MEDIUM | LOW | Extensive detective tests, manual testing |

---

### Success Metrics

**After full deployment, measure**:

1. **Memory Usage**: Ruby process memory should decrease
2. **Database Size**: Projects table size should decrease by ~75-85% for status columns
3. **API Compatibility**: External API tests should all pass
4. **Error Rates**: No increase in application errors
5. **Test Coverage**: All tests passing

**Target Improvements**:

- Database storage: -75% to -85% for status fields
- Ruby memory per project: Reduction in String object allocations
- Application performance: Same or better (integer comparisons faster)
