# Implementing "NULL for blank string" optimization for justifications

## Background

The badge application receives a very large number of requests,
especially for "project" data. We believe this is because many organizations
are trying to train AI systems based on machine learning, and are
basically repeatedly downloading everything on the Internet to train them.

This massive number of requests leads to
a massive number of memory allocations. We need to reduce the
memory allocations when retrieving project data, and have taken
various steps to do this.

The "project" table has a large number of `t.text` fields
for criteria justification, e.g., `know_common_errors_justification`.
Their current definition permits NULL values.
In many cases the stored justification values are empty strings.

## Data Analysis (from development database)

Analysis of the development database (9,372 projects) as of 2025-12-30
revealed:

- **193 justification fields** per project
- **1,808,796 total justification cells** (193 fields × 9,372 projects)

**Current distribution:**

- **Empty strings**: 273,826 cells (15.14%)
- **NULL values**: 1,319,823 cells (72.97%)
- **Non-empty strings**: 215,147 cells (11.89%)

**Key finding**: The vast majority of justification cells (72.97%) are
already NULL, demonstrating that the application already handles NULL
values correctly throughout.

## Hypothesis - CONFIRMED ✓

**Hypothesis**: We can optimize memory usage by always storing *empty*
justification strings as NULL values.

**Confirmation**: Testing confirms that:

1. **Empty strings consume memory**: Each empty string allocates 40 bytes
   with a unique object_id
2. **nil is zero-cost**: Ruby's `nil` is a singleton (object_id: 4) that
   takes 0 more bytes to allocate
3. **Memory savings**: Converting 273,826 empty strings to NULL would save
   ~10.4 MB of direct allocations plus reduce garbage collection overhead
   if you simply loaded each project in once (as a thought experiment
   to estimate impact).
4. **Rails compatibility**: Rails often treats `nil` and `''` equivalently:
   - `nil.blank?` == `''.blank?` (both true)
   - `nil.present?` == `''.present?` (both false)
   - `nil.to_s` == `''` (both empty string)

## Implementation Approach

Since 72.97% of justifications are already NULL and the application handles
them correctly, we can take a simple, focused approach:

### Required Changes

1. **Migration**: Convert all empty string justifications to NULL
   - Update all 273,826 empty string cells to NULL
   - This is a one-time data cleanup

2. **Input normalization**: Ensure incoming empty strings become NULL
   - When receiving data updates (form submissions, API calls), convert
     empty justification strings to `nil` before saving
   - This prevents new empty string allocations from being created

### What Does NOT Need to Change

- **JSON serialization**: Can remain as-is. While `nil` will serialize as
  `null` instead of `""`, this is semantically more correct and unlikely
  to cause issues for API consumers, since this already can occur,
  and there's no semantic difference for a user.
- **HTML rendering**: Rails automatically converts `nil.to_s` to `''`,
  so forms and views will display empty strings correctly
- **Validation logic**: Already uses `.blank?` and `.present?` which
  treat `nil` and `''` identically
- **Database schema**: Already permits NULL values, no schema changes needed

### Benefits

- Reduced memory allocations. When a project is loaded, empty justifications
  will refer to nil instead of allocating a useless empty string.
  This reduces the memory use, and also reduces garbage collection pressure
  since the nil values don't need to be cleaned up later
  by the garbage collector.
- Minimal code changes required

The actual impact depends on which projects are loaded. However,
if you simply loaded each project once as they are currently, there would be
273,826 fewer objects to track and ~10.4 MB saved.
It's really the number of objects eliminated that matters.

## Implementation Plan

### 1. Database Migration

Create a new migration:
`db/migrate/YYYYMMDDHHMMSS_convert_empty_justifications_to_null.rb`

**Structure:**

```ruby
# frozen_string_literal: true

# Copyright the Linux Foundation and the
# OpenSSF Best Practices badge contributors
# SPDX-License-Identifier: MIT

class ConvertEmptyJustificationsToNull < ActiveRecord::Migration[8.1]
  using SymbolRefinements

  def up
    # Get all justification field names from Criteria
    justification_fields = Criteria.all.map(&:justification)

    say_with_time "Converting #{justification_fields.size} justification fields: empty strings to NULL" do
      justification_fields.each_with_index do |field, index|
        say "Converting #{field} (#{index + 1}/#{justification_fields.size})", :subitem

        # Convert empty strings to NULL
        execute <<-SQL
          UPDATE projects
          SET "#{field}" = NULL
          WHERE "#{field}" = ''
        SQL
      end
    end
  end

  def down
    # Get all justification field names from Criteria
    justification_fields = Criteria.all.map(&:justification)

    say_with_time "Converting #{justification_fields.size} justification fields: NULL to empty strings" do
      justification_fields.each_with_index do |field, index|
        say "Converting #{field} (#{index + 1}/#{justification_fields.size})", :subitem

        # This would Convert NULL back to empty strings, but it would do it
        # everywhere.
        # execute <<-SQL
        #   UPDATE projects
        #   SET "#{field}" = ''
        #   WHERE "#{field}" IS NULL
        # SQL
      end
    end
  end
end
```

**What it does:**

- **up**: Iterates through all 193 justification fields and converts
  empty strings (`''`) to NULL
- **down**: Reversible - Doesn't do anything, because NULL is already allowed.
- Uses `say_with_time` for progress reporting during migration
- Follows the same pattern as the recent status field migration
  (20251230044124_convert_status_fields_to_smallint.rb)

**Expected impact:**

- Will update ~273,826 cells in the production database
- Migration should be relatively fast (simple UPDATE statements)
- No schema changes required (columns already permit NULL)

### 2. Controller Input Normalization

Modify `app/controllers/projects_controller.rb` to normalize incoming
justification parameters.

Note that the text below creates two new `before_actions`; a plausible
alternative would be to have a single `before_action` to
`regularize_input`, which might then call conversions for both
status values *and* empty justification strings.
Don't implement before considering this alternative.

**Location:** Modify existing method `convert_status_params`
method (around line 783) from:

```ruby
  def convert_status_params
    return unless params[:project]

    convert_status_params_of_hash!(params[:project])
  end
```

into:

```ruby
  # Clean up input project data.
  # Turn status values into integers, and convert
  # empty justification values into nil.
  # @return [void]
  def cleanup_input_params
    p = params[:project]
    return unless p

    convert_status_params_of_hash!(p)
    convert_justification_params_of_hash!(p)
  end
```

**New method:**

```ruby
# Convert all empty justification strings to nil in hash h.
# This modifies the hash IN PLACE.
# @param h [Hash] The hash to modify (typically params[:project])
# @return [void]
def convert_justification_params_of_hash!(h)
  Project::ALL_CRITERIA_JUSTIFICATION.each do |justification_field|
    next unless h.key?(justification_field)

    value = h[justification_field]

    # Convert empty strings to nil
    # Leave nil and non-empty strings as-is
    h[justification_field] = nil if value == ''
  end
end
```

**Update before_action filter** (around line 28):

```ruby
# Change from:
before_action :convert_status_params, only: %i[create update]

# To:
before_action :cleanup_input_params, only: %i[create update]
```

### 3. Testing Considerations

**Tests to add/verify:**

1. **Controller test** (`test/controllers/projects_controller_test.rb`):
   - Verify empty string justifications are converted to nil on update
   - Verify non-empty justifications are preserved
   - Verify nil justifications remain nil

2. **Integration test** (optional):
   - Submit a form with empty justification fields
   - Verify the saved project has nil (not '') for those fields

3. **Migration test**:
   - The migration should be tested manually in development
   - Run migration on development database and verify empty strings
     are converted to NULL

**Example test case:**

```ruby
test 'empty justification strings converted to nil on update' do
  project = projects(:one)
  sign_in users(:admin_user)

  patch project_path(project, locale: :en), params: {
    project: {
      description_good_justification: '',  # Empty string
      name: 'Test Project'
    }
  }

  project.reload
  assert_nil project.description_good_justification
end
```

### 4. Additional Changes Required

**None identified.**

After careful analysis:

- **No view changes needed**: Rails automatically renders `nil.to_s` as `''`
  in form fields
- **No model changes needed**: Validations already use `.blank?` and
  `.present?` which treat nil and '' identically
- **No serializer changes needed**: JSON serialization will output `null`
  instead of `""`, but this is semantically correct and already occurs
  (72.97% of justifications are already NULL)
- **No other controllers exist** that update projects (verified via grep)
- **No schema changes needed**: Columns already permit NULL values

### 5. Deployment Steps

1. **Run migration** on production database:

   ```bash
   rails db:migrate
   ```

2. **Deploy code** with controller changes

3. **Verify** by checking a few projects in production:
   - Empty justifications should be NULL in database
   - Empty justifications should render as empty strings in forms

### 6. Rollback Plan

If issues are discovered:

1. **Revert controller changes** (remove the before_action and methods)
2. **Rollback migration**:

   ```bash
   rails db:rollback
   ```

   This will convert all NULL justifications back to empty strings,
   restoring the previous state (but re-creating the memory problem).

### 7. Monitoring

After deployment, monitor:

- **Memory usage**: Should decrease slightly due to fewer object allocations
- **GC metrics**: Should see reduced garbage collection pressure
- **Error logs**: Watch for any unexpected issues with nil justifications
- **User reports**: Watch for any UI issues with empty justification fields

The impact will be gradual as projects are loaded and re-saved over time.
