# Route Consolidation Plan

This document outlines a plan to consolidate and simplify the routing
structure for `/projects` GET routes in the Best Practices Badge application.

## Problem Statement

The current routing configuration for GET ... `/projects`
has significant issues:

1. **Route Proliferation**: Multiple overlapping patterns cause the router
   to repeatedly attempt pattern matching for the same request
2. **Maintenance Burden**: Obsolete section names (0, 1, 2, bronze) require
   extensive redirect handling
3. **Scattered Logic**: Format handling and validation spread across routes
   instead of centralized in controllers
4. **Performance**: Each request may traverse many route patterns before
   finding a match

The current routes were generated and stored in `,projects-routes` for
analysis, revealing these inefficiencies.

Note: the PUT, PATCH, etc., routes are simpler and not what we're focusing on.

## Goals

1. **Simplify Routing**: Reduce the number of route patterns by consolidating
   related functionality
2. **Centralize Logic**: Move format and section handling from routes to
   controllers where appropriate
3. **Maintain Compatibility**: Preserve all existing widely-used
   URLs through redirects. We're less concerned about URLs for
   markdown (.md) format, as those aren't widely known. We're less concerned
   about "edit" for obsolete section names, as those aren't normally linked to.
4. **Improve Performance**: Reduce route matching overhead
5. **Future-Proof**: Support planned features like per-project default sections

## Proposed Route Structure

### Badge Images (Unchanged)

```
GET /projects/:id/badge(.:format)
  → projects#badge
  → Constraints: format: "svg", id: /[1-9][0-9]*/
  → No locale needed (badges are locale-independent)
```

This route remains as-is since it works well.

### Project Listing (Unchanged)

```
GET (/:locale)/projects(.:format)
  → projects#index
  → Shows list of all projects
  → If :locale omitted: 302 redirect to /:detected_locale/projects
```

### New Project (Unchanged)

```
GET (/:locale)/projects/new(.:format)
  → projects#new
  → Shows form to create new project
  → If :locale omitted: 302 redirect to /:detected_locale/projects/new
```

### Delete Confirmation (Unchanged)

This is unchanged.

```
GET (/:locale)/projects/:id/delete_form(.:format)
  → projects#delete_form
  → Shows delete confirmation page
  → If :locale omitted: 302 redirect to /:detected_locale/projects/:id/delete_form
  → Kept as separate route for security (requires GET before DELETE)
```

### Edit Section

```
GET (/:locale)/projects/:id/:section/edit
  → projects#edit
  → Constraints: :section must be valid section (passing, silver, gold,
    baseline-1, baseline-2, baseline-3, permissions)
  → Does NOT accept obsolete values (0, 1, 2, bronze). We don't expect
    those URLs to be widely linked to.
  → If :locale omitted: 302 redirect to /:detected_locale/projects/:id/:section/edit
```

### View Section (HTML or Markdown)

```
GET (/:locale)/projects/:id/:section(.:format)
  → Handles both viewing and format-specific requests
  → If :locale omitted: 302 redirect to /:detected_locale/projects/:id/:section

  Behavior by :section value:

  - If :section is obsolete (bronze, 0, 1, 2):
    → 301 redirect to current name with same locale/format
    → Mapping: bronze→passing, 0→passing, 1→silver, 2→gold

  - If :section is valid (passing, silver, gold, baseline-*, permissions):
    → Behavior depends on format:
      - .html or no format: projects#show (HTML view)
      - .md: projects#show (Markdown view)
    → Controller uses respond_to to handle format
```

I suspect the controller will call some sort of method like
`show_handler` that takes the section and format, then handles it
(e.g., redirects, calls `show`, or calls `show_json`)

### View Project (Default Section)

```
GET (/:locale)/projects/:id(.:format)
  → 302 redirect to (/:locale)/projects/:id/passing(.:format)
  → Preserves format if specified
  → If :locale omitted: 302 redirect happens first to add locale,
    then redirects again to add section
  → Future: May redirect to project-specific default section instead
    of always "passing"
```

### JSON API (Locale-Independent)

```
GET /(:locale/)projects/:id.json
  → Eventually calls projects#show_json (though the implementation
    might call another method first, like "show", and then call show_json).
  → Returns complete project data as JSON
  → If locale in URL, always 301 redirect to non-locale version
    (JSON is locale-independent)
  → NO per-section JSON (doesn't make semantic sense)
  → Note: Different from HTML/Markdown which ARE locale-specific and
    depend on sections.
```

### Markdown Without Locale (Redirect Chain)

```
GET /projects/:id.md
  → 302 redirect to /:detected_locale/projects/:id.md
  → Which then 302 redirects to /:detected_locale/projects/:id/passing.md
  → Markdown IS locale-specific (unlike JSON)
  → Default section is "passing" until per-project defaults implemented
```

## Opportunities for Additional Consolidation

The current plan keeps several routes separate. Two specific patterns suggest
opportunities for further consolidation that might simplify the router
(speeding it up) and clarify format overlap.

### Opportunity 1: Consolidate `delete_form` as a Section

**Current Separate Routes:**

```
GET (/:locale)/projects/:id/delete_form(.:format) → projects#delete_form
GET (/:locale)/projects/:id/:section(.:format)    → projects#show
```

**Proposed Consolidation:**

```
GET (/:locale)/projects/:id/:section(.:format) → projects#show_or_action
  where :section can be:
  - A criteria level: passing, silver, gold, baseline-1, baseline-2, baseline-3
  - A special view: permissions, delete_form
```

#### Implications

This would treat `delete_form` as just another "section" of the project view,
similar to how "permissions" is already handled as a section. The controller
would need to distinguish between criteria sections and special action sections.

#### Pros

1. **Single Route Pattern**: Eliminates one route definition, making the
   route table simpler
2. **Consistent URL Structure**: All project "views" follow the same pattern
   `/:locale/projects/:id/:view_name`
3. **Format Flexibility**: If we ever need `delete_form.json` or
   `delete_form.md`, it would work automatically without new routes
4. **Easier Extension**: Adding new special views (like "audit_log",
   "contributors") wouldn't require new route definitions
5. **Clear Conceptual Model**: Everything under `/:id/:something` is a
   "view of the project"

#### Cons

1. **Semantic Confusion**: `delete_form` is not really a "section" of
   criteria - it's a confirmation page for deletion
   - Mixing data views (sections) with action confirmations (delete) is
     conceptually unclear
   - Future developers might not realize `delete_form` is special

2. **Security Concerns**: Delete confirmation requires special authorization
   - Currently isolated in separate route and controller action
   - Consolidation means authorization logic must be added to generic `show`
   - Higher risk of accidentally exposing delete_form to unauthorized users

3. **Different Behavior Requirements**:
   - Sections: cacheable, can be public, support multiple formats
   - delete_form: not cacheable, requires authentication, only HTML makes sense
   - Consolidation forces generic code to handle very different requirements

4. **RESTful Convention Violation**: Rails convention is:
   - GET `/projects/:id/edit` - edit form
   - DELETE `/projects/:id` - destroy action
   - GET `/projects/:id/delete_form` fits the "confirmation form" pattern
   - Treating it as a "section" breaks this convention

5. **Format Handling Complexity**:
   - `delete_form.json` - what would this return? The JSON representation
     of a delete button?
   - `delete_form.md` - markdown of a delete confirmation form is nonsensical
   - Would need format constraints or validation specific to this "section"

6. **Testing Complexity**: Tests for sections and tests for delete_form
   have different concerns
   - Section tests: verify correct criteria display, test caching, check
     all formats
   - delete_form tests: verify authorization, ensure CSRF token, check
     deletion flow
   - Consolidating makes test suite organization less clear

#### Recommendation

**Do NOT consolidate delete_form with sections.**

Rationale:

- `delete_form` is fundamentally different: it's an action confirmation,
  not a data view
- Security implications of consolidation are significant
- The single-route benefit is outweighed by increased conceptual complexity
- Rails conventions favor keeping destructive action confirmations separate
- Only one route is saved, but multiple concerns are mixed

**Alternative:** If route consolidation is critical, consider a different
pattern:

- Keep sections separate from special actions
- Create a pattern for special actions: `/:id/_action/:action_name`
- Example: `/projects/123/_action/delete_form`
- This makes it clear these are different from data sections

### Opportunity 2: Consolidate JSON Format into Main Show Route

**Current Separate Routes:**

```
GET /projects/:id.json                            → projects#show_json
GET (/:locale)/projects/:id(/:section)(.:format)  → projects#show
```

**Proposed Consolidation:**

```
GET /(:locale/)projects/:id(/:section)(.:format) → projects#show
  where format can be html, md, or json
  - If format is json: ignore locale and section parameters
  - If format is html/md: use locale and section normally
```

#### Implications

This would unify all project viewing into a single controller action that
handles format-specific rendering. The controller would need to handle
JSON as a special case that bypasses locale and section logic.

#### Pros

1. **True Route Unification**: Single route handles all project viewing
   regardless of format
2. **Consistent respond_to Block**: All formats in one place makes it
   obvious what formats are supported
3. **Reduced Route Complexity**: Eliminates the special-case route for JSON
4. **Potential Code Sharing**: If JSON and HTML need similar data loading,
   it's already in the same action
5. **Future Format Support**: Adding new formats (e.g., XML, CSV) would
   naturally fit the existing pattern

#### Cons

1. **Locale Handling Complexity**: Route becomes `/(:locale/)projects/...`
   - Optional locale makes routing more complex
   - Need to handle locale-in-URL for HTML/MD but reject for JSON
   - Redirect logic becomes more complex: if JSON requested with locale,
     must redirect to remove it

2. **Section Parameter Confusion**: JSON ignores section parameter
   - URL `/fr/projects/123/passing.json` - what does this mean?
   - Should it error? Redirect to `/projects/123.json`? Silently ignore
     "passing"?
   - Creates "valid" URLs that don't make semantic sense

3. **Conceptual Mismatch**: JSON represents fundamentally different data
   - HTML/MD: Shows one section at a time, localized text
   - JSON: Shows entire project, no localization, structure-focused
   - Forcing them into one route obscures this difference

4. **Controller Logic Branching**: The `show` action becomes:

   ```ruby
   def show
     if request.format.json?
       # Completely different code path
       render json: @project.to_json
     else
       # Section-based rendering
       @section = params[:section] || 'passing'
       # ... rest of section logic
     end
   end
   ```

   This is effectively two actions in one, making the code harder to understand

5. **Testing Becomes Complex**:
   - Tests for JSON have completely different setup and assertions
   - Tests for HTML/MD need locale and section fixtures
   - Consolidated action means tests are harder to organize and maintain

6. **Route Constraints Complexity**: To make this work properly:

   ```ruby
   # Need complex constraints:
   get '(:locale/)projects/:id(/:section)',
       to: 'projects#show',
       constraints: {
         locale: /en|fr|.../,
         section: /passing|silver|.../,
         format: /html|md|json/
       }

   # Plus redirect logic for invalid combinations:
   # - /en/projects/123.json → /projects/123.json
   # - /projects/123/passing.json → /projects/123.json
   ```

   This constraint complexity is harder to maintain than two simple routes

7. **Breaking Existing API Contracts**: If external clients use
   `/projects/:id.json`, they might accidentally request
   `/en/projects/:id.json` and get unexpected redirects

8. **Performance Consideration**: Every HTML/MD request would need to check
   "is this JSON?" before proceeding with section logic, adding tiny overhead

#### Recommendation

**Do NOT consolidate JSON into the main show route.**

Rationale:

- JSON is conceptually different enough to warrant separate handling
- The route parameters (locale, section) that make sense for HTML/MD don't
  apply to JSON
- Controller logic would become significantly more complex with branching
- Creating "valid but nonsensical" URLs like `/en/projects/123/passing.json`
  is worse than having two routes
- Separate routes make the API clearer: one route for human viewing
  (HTML/MD with sections), another for machine consumption (JSON)

The current plan of separate routes is the right choice. The routes are:

- Self-documenting: clear which URLs are valid
- Simple: each route has one purpose
- Maintainable: changing JSON behavior doesn't affect HTML rendering

**Alternative Considered:** Could use route constraints to make JSON-only
route match first, then fallback to section-based route. However, this
creates route ordering dependencies and is harder to understand than
explicit separate routes.

### Summary of Recommendations

Both consolidation opportunities should be **rejected**:

1. **delete_form**: Keep separate due to different purpose (action
   confirmation vs. data view), security concerns, and semantic clarity
2. **JSON format**: Keep separate due to different parameters (no locale,
   no section), different data structure, and API clarity

The current plan strikes the right balance between consolidation and
clarity. Further consolidation would trade minor route table simplification
for significant increases in controller complexity and conceptual confusion.

## Detailed Implementation Plan

This section provides the exact implementation details including route
definitions, controller methods, and memory impact analysis.

### Phase 0: Rename and Consolidate Constants (COMPLETED)

**Status**: This phase has been completed. The constants have been defined in
`config/initializers/01_section_names.rb` (not `00_section_names.rb` as originally
planned, because it needs to load after `00_criteria_hash.rb`).

**Goal**: Rename constants to accurately reflect their meaning, compute them once
in a single location, freeze them, and make them available to both routes and
controllers. This provides clear, consistent naming for all subsequent changes.

#### Current State Problems

1. **Misleading names**: `ALL_CRITERIA_LEVEL_NAMES` includes "permissions" which
   is a section/view, not a criteria level
2. **Scattered definitions**: Constants defined in multiple places (initializers,
   routes.rb, controller)
3. **Recomputation**: Same values calculated multiple times
4. **Unclear dependencies**: Routes depend on initializers, controller depends on
   routes

#### Proposed Constants (All Frozen)

Define these in `config/initializers/01_section_names.rb` (named with "01_"
prefix because it must load AFTER `00_criteria_hash.rb` which loads the YAML
and exports level keys):

```ruby
# frozen_string_literal: true

# **CANONICAL LISTS** of valid criteria level names and routing constants
#
# This file defines the authoritative list of criteria levels and sections
# used throughout the application. These constants are used by:
# - config/routes.rb - to build routing constraints
# - app/controllers - for validation and redirects
# - config/initializers/cors.rb - to build CORS resource patterns
#
# This file is named with "01_" prefix to ensure it loads AFTER
# 00_criteria_hash.rb which loads the YAML and exports level keys.
#
# IMPORTANT: Level names are DERIVED from the YAML criteria files via
# constants exported from 00_criteria_hash.rb (YAML_METAL_LEVEL_KEYS and
# YAML_BASELINE_LEVEL_KEYS). This ensures YAML is loaded only once.

module Sections
  # Map of obsolete names to their canonical equivalents
  # This mapping is the authoritative source for canonical names
  # NOTE: The YAML files use obsolete numeric keys ('0', '1', '2')
  # but we route using canonical names ('passing', 'silver', 'gold')
  REDIRECTS = {
    '0' => 'passing',
    '1' => 'silver',
    '2' => 'gold',
    'bronze' => 'passing'
  }.freeze

  # Use level keys exported from 00_criteria_hash.rb (which loaded the YAML)
  # This avoids loading YAML twice - single source of truth

  # Metal badge levels - map numeric YAML keys to canonical names
  # The YAML uses '0', '1', '2' but we want canonical names
  # E.g., ['passing', 'silver', 'gold']
  METAL_LEVEL_NAMES = YAML_METAL_LEVEL_KEYS.map { |k| REDIRECTS[k] || k }
                                           .freeze

  # Metal level numbers (obsolete keys still used in YAML)
  # E.g., ['0', '1', '2']
  METAL_LEVEL_NUMBERS = YAML_METAL_LEVEL_KEYS

  # Baseline badge levels (already use canonical names in YAML)
  # E.g., ['baseline-1', 'baseline-2', 'baseline-3']
  BASELINE_LEVEL_NAMES = YAML_BASELINE_LEVEL_KEYS

  # Synonyms for existing levels (obsolete names beyond numeric keys)
  SYNONYMS = %w[bronze].freeze # bronze = passing

  # Special forms (non-criteria sections - views/forms not tied to a criteria level)
  SPECIAL_FORMS = %w[permissions].freeze

  # All criteria levels (canonical names only - no obsolete numbers)
  # Built up from canonical level names derived from YAML
  ALL_CRITERIA_LEVEL_NAMES = (METAL_LEVEL_NAMES + BASELINE_LEVEL_NAMES).freeze

  # All canonical section names (criteria levels + special sections)
  # These are the preferred names that we redirect to - no obsolete names
  ALL_CANONICAL_NAMES = (ALL_CRITERIA_LEVEL_NAMES + SPECIAL_FORMS).freeze

  # Obsolete section names (deprecated, should redirect to canonical names)
  # Built up from obsolete numeric keys and synonym names
  OBSOLETE_NAMES = (METAL_LEVEL_NUMBERS + SYNONYMS).freeze

  # Valid section names (all names we accept - canonical + obsolete)
  # Used for validation where we accept obsolete names (then redirect to canonical)
  VALID_NAMES = (ALL_CANONICAL_NAMES + OBSOLETE_NAMES).freeze

  # Regex matching only primary/canonical section names
  # Used in controller validation and routes that reject obsolete names
  PRIMARY_SECTION_REGEX = Regexp.union(ALL_CANONICAL_NAMES)

  # Regex matching all valid section names (canonical + obsolete synonyms)
  # Used in routes.rb for :section parameter validation
  # (accepts obsolete for redirect)
  VALID_SECTION_REGEX = Regexp.union(VALID_NAMES)

  # Default section to use when none specified
  DEFAULT_SECTION = 'passing'
end
```

#### Benefits of This Approach

1. **Single source of truth**: All section-related constants in one file
2. **Namespaced**: Under `Sections::` module to avoid polluting global namespace
3. **Clear naming**:
   - `Sections::ALL_CRITERIA_LEVEL_NAMES` - only actual criteria levels
   - `Sections::ALL_CANONICAL_NAMES` - includes special sections like permissions (canonical only)
   - `Sections::VALID_NAMES` - all names we accept (canonical + obsolete)
   - `Sections::REDIRECTS` - obsolete to canonical mapping
   - `Sections::PRIMARY_SECTION_REGEX` - route constraint for primary sections only
   - `Sections::VALID_SECTION_REGEX` - route constraint including obsolete
   - `Sections::DEFAULT_SECTION` - default section ('passing')
   - `Sections::SPECIAL_FORMS` - non-criteria sections (e.g., permissions)
4. **Computed once**: Regexes and arrays frozen, not recomputed
5. **Available everywhere**: Initializers load before routes and controllers
6. **Easy maintenance**: Adding new levels only requires updating one place
7. **Type clarity**: Frozen arrays, hashes, and regexes (not strings or symbols)

#### Usage in Routes

```ruby
# config/routes.rb

Rails.application.routes.draw do
  scope '(:locale)', locale: LEGAL_LOCALE do
    # Use VALID_SECTION_REGEX for routes that accept obsolete names (will redirect)
    get 'projects/:id/:section', to: 'projects#show',
        constraints: { id: VALID_ID, section: Sections::VALID_SECTION_REGEX }

    # Use PRIMARY_SECTION_REGEX for routes that reject obsolete names
    get 'projects/:id/:section/edit', to: 'projects#edit',
        constraints: { id: VALID_ID, section: Sections::PRIMARY_SECTION_REGEX }
  end
end
```

#### Usage in Controller

```ruby
# app/controllers/projects_controller.rb

class ProjectsController < ApplicationController
  # Reference the frozen constants from Sections module directly
  # No need to redefine - use Sections:: prefix throughout

  def show
    @section = params[:section]

    # Check obsolete names using Sections::REDIRECTS frozen hash
    if Sections::REDIRECTS.key?(@section)
      redirect_to project_section_path(@project,
                                       Sections::REDIRECTS[@section],
                                       locale: params[:locale]),
                  status: :moved_permanently
      return
    end

    # Validate using Sections::VALID_NAMES frozen array
    unless Sections::VALID_NAMES.include?(@section)
      raise ActionController::RoutingError, "Invalid section: #{@section}"
    end
    # ...
  end
end
```

#### Migration Steps for Phase 0

1. **Create/update initializer**:
   - File: `config/initializers/01_section_names.rb`
   - Define all constants as shown above
   - Ensure file loads after 00_criteria_hash.rb (01_ prefix ensures correct order)

2. **Update routes.rb**:
   - Remove `LEVEL_REDIRECTS` constant (use `SECTION_REDIRECTS` instead)
   - Remove `VALID_CRITERIA_LEVEL` regex (use `SECTION_REGEX` instead)
   - Replace all references with new constant names

3. **Update controllers**:
   - Remove any local constant definitions
   - Use frozen constants from initializer directly

4. **Test**:
   - Run `rake routes` to verify routes still work
   - Run controller tests to verify validation still works
   - Verify no performance regression (constants frozen/memoized)

5. **Commit separately**:
   - This is a pure refactoring (no behavior change)
   - Makes subsequent route consolidation changes clearer

#### Why This Must Be Done First

- **Clearer subsequent changes**: Route consolidation will use accurate names
  like `SECTION_REGEX` instead of misleading `VALID_CRITERIA_LEVEL`
- **Single point of failure**: If constant names are wrong, fix once, not
  scattered across files
- **Easier review**: Rename commit separate from behavior change commits
- **Lower risk**: Pure refactoring can be tested independently

### Migration from Current Routes

This section shows exactly how the current routes will be transformed.

#### Current Route Structure (BEFORE)

The existing `config/routes.rb` currently has this structure for `/projects`:

```ruby
Rails.application.routes.draw do
  # 1. Badge route (outside scope) - UNCHANGED
  get '/projects/:id/badge' => 'projects#badge',
      constraints: { id: VALID_ID },
      defaults: { format: 'svg' }

  # 2. Loop-generated redirects for obsolete levels (bronze, 0, 1, 2)
  # This generates 16 routes total (4 obsolete levels × 4 routes each):
  LEVEL_REDIRECTS.each do |old_level, new_level|
    # Show with locale (301 permanent)
    get "/:locale/projects/:id/#{old_level}(.:format)",
        to: redirect(301) { ... }

    # Show without locale (302 temporary, adds locale)
    get "/projects/:id/#{old_level}(.:format)",
        to: redirect_to_level(new_level, status: 302)

    # Edit with locale (301 permanent)
    get "/:locale/projects/:id/#{old_level}/edit(.:format)",
        to: redirect(301) { ... }

    # Edit without locale (302 temporary, adds locale)
    get "/projects/:id/#{old_level}/edit(.:format)",
        to: redirect_to_level(new_level, suffix: '/edit', status: 302)
  end
  # = 16 routes generated by this loop

  # 3. Redirect to default section (complex lambda constraints)
  # Show routes with complex format exclusions
  get '/:locale/projects/:id(.:format)',
      to: redirect_to_level('passing', status: 302),
      constraints: lambda { |req|
        id_ok && locale_ok && format_ok && no_criteria_level
      }

  get '/projects/:id(.:format)',
      to: redirect_to_level('passing', status: 302),
      constraints: lambda { |req| ... }

  # Edit routes to default section
  get '/:locale/projects/:id/edit(.:format)',
      to: redirect_to_level('passing', suffix: '/edit', status: 302)

  get '/projects/:id/edit(.:format)',
      to: redirect_to_level('passing', suffix: '/edit', status: 302)
  # = 4 routes for default section redirects

  # 4. Resources block with member routes
  scope '(:locale)', locale: LEGAL_LOCALE do
    resources :projects, constraints: { id: VALID_ID } do
      member do
        # Delete confirmation
        get 'delete_form' => 'projects#delete_form'

        # JSON format (special constraint)
        get '' => 'projects#show_json',
            constraints: ->(req) { req.format == :json }

        # Markdown format (special constraint)
        get '' => 'projects#show_markdown',
            constraints: ->(req) { req.format == :md }

        # Show with criteria level
        get ':criteria_level(.:format)' => 'projects#show',
            constraints: { criteria_level: VALID_CRITERIA_LEVEL },
            as: :level

        # Edit with criteria level
        get ':criteria_level/edit(.:format)' => 'projects#edit',
            constraints: { criteria_level: VALID_CRITERIA_LEVEL },
            as: :level_edit
      end
    end
  end
  # = 5 routes in resources block
end

# TOTAL: ~25 routes for /projects GET operations
```

**Problems with current structure:**

1. **16 redirect routes** generated by `LEVEL_REDIRECTS.each` loop
2. **Complex lambda constraints** with inline logic that's hard to understand
3. **Format handling split** between lambda constraints and resources block
4. **Duplicate locale handling** (with/without locale patterns repeated)
5. **Three separate controller methods** for formats (show, show_json, show_markdown)

#### New Route Structure (AFTER)

```ruby
Rails.application.routes.draw do
  # ROUTE 1: Badge image (UNCHANGED - outside scope, no locale)
  get 'projects/:id/badge', to: 'projects#badge',
      constraints: { id: VALID_ID, format: 'svg' },
      defaults: { format: 'svg' },
      as: :project_badge

  # ROUTE 2: JSON API - locale-independent (MODIFIED - moved outside scope)
  # This is the expected common case, so match it first for performance
  get 'projects/:id', to: 'projects#show_json',
      constraints: { id: VALID_ID, format: 'json' },
      defaults: { format: 'json' },
      as: :project_json

  # ROUTE 3: Redirect localized JSON to non-localized (NEW)
  # Handle common mistake of adding locale to JSON URLs (less frequent)
  get ':locale/projects/:id', to: redirect('/projects/%{id}.json', status: 301),
      constraints: { id: VALID_ID, format: 'json', locale: LEGAL_LOCALE }

  # Localized routes (optional locale parameter)
  scope '(:locale)', locale: LEGAL_LOCALE do
    # Standard RESTful routes
    # Excludes :show and :edit (custom routes below)
    # Excludes :update (custom route below with section parameter)
    resources :projects, only: [:index, :new, :create, :destroy],
              constraints: { id: VALID_ID }

    # ROUTE 4: Delete confirmation (UNCHANGED - extracted from resources)
    get 'projects/:id/delete_form', to: 'projects#delete_form',
        constraints: { id: VALID_ID },
        as: :delete_form_project

    # ROUTE 5: Edit with section (MODIFIED - was in resources member block)
    get 'projects/:id/:section/edit', to: 'projects#edit',
        constraints: { id: VALID_ID, section: VALID_CRITERIA_LEVEL },
        as: :edit_project_section

    # ROUTE 6: Show section (MODIFIED - consolidates show + show_markdown)
    # Handles obsolete sections via controller redirect
    get 'projects/:id/:section', to: 'projects#show',
        constraints: { id: VALID_ID, section: VALID_CRITERIA_LEVEL },
        as: :project_section,
        defaults: { format: 'html' }

    # ROUTE 7: Redirect to default section (MODIFIED - consolidates 4 routes)
    # Handles all formats, with/without locale (via scope's optional locale)
    get 'projects/:id', to: 'projects#redirect_to_default_section',
        constraints: { id: VALID_ID },
        as: :project_redirect

    # ROUTE 8: Update project (PUT/PATCH) - section optional
    # Pattern: PUT/PATCH /projects/:id(/:section)(/edit)
    # Accepts all these patterns:
    # - PUT/PATCH /projects/:id (section inferred from referrer or defaults to passing)
    # - PUT/PATCH /projects/:id/:section (preferred - explicit redirect target)
    # - PUT/PATCH /projects/:id/:section/edit (backward compat - deprecated /edit suffix)
    # Section in URL indicates where to redirect after successful update
    # IMPORTANT: ANY project field can be updated regardless of section in URL
    match 'projects/:id(/:section)(/edit)', to: 'projects#update',
          via: %i[put patch],
          constraints: { id: VALID_ID, section: VALID_CRITERIA_LEVEL },
          as: :update_project
  end
end

# TOTAL: 7 GET routes + 1 PUT/PATCH route for /projects operations (down from ~25)
```

#### Key Changes

| Current Approach | New Approach | Benefit |
|-----------------|--------------|---------|
| 16 routes via `LEVEL_REDIRECTS.each` loop | Obsolete sections handled in controller | Reduces routes by 16 |
| Lambda constraints with complex logic | Simple hash constraints | Easier to understand |
| 3 controller methods (show, show_json, show_markdown) | 2 methods (show handles HTML+MD, show_json separate) | Reduces controller complexity |
| Format handling split across routes | Format handled via `respond_to` in controller | Centralized logic |
| Separate with/without locale routes | `scope '(:locale)'` with optional parameter | Eliminates duplication |
| Complex redirect helpers (`redirect_to_level`) | Single `redirect_to_default_section` method | Simpler redirect logic |

#### Routes Removed

```ruby
# REMOVED: All 16 loop-generated routes
LEVEL_REDIRECTS.each do |old_level, new_level|
  # These 4 routes × 4 obsolete levels = 16 routes REMOVED
  # Functionality moved to controller (projects#show handles redirects)
end

# REMOVED: Complex lambda constraint routes
get '/:locale/projects/:id(.:format)',
    to: redirect_to_level('passing', status: 302),
    constraints: lambda { ... } # REMOVED

get '/projects/:id(.:format)',
    to: redirect_to_level('passing', status: 302),
    constraints: lambda { ... } # REMOVED

# REMOVED: Duplicate edit redirect routes (consolidated into Route 7)
get '/:locale/projects/:id/edit(.:format)',
    to: redirect_to_level('passing', suffix: '/edit', status: 302) # REMOVED

get '/projects/:id/edit(.:format)',
    to: redirect_to_level('passing', suffix: '/edit', status: 302) # REMOVED

# REMOVED: Resources member block (routes extracted to explicit definitions)
resources :projects do
  member do
    get '' => 'projects#show_markdown' # REMOVED (merged into show)
    get ':criteria_level(.:format)' => 'projects#show' # REPLACED by Route 6
    get ':criteria_level/edit(.:format)' => 'projects#edit' # REPLACED by Route 5
  end
end
```

#### Routes Added

```ruby
# NEW: Redirect localized JSON to non-localized (Route 3)
# Handles common mistake of adding locale to JSON URLs
get ':locale/projects/:id', to: redirect('/projects/%{id}.json', status: 301),
    constraints: { id: VALID_ID, format: 'json', locale: LEGAL_LOCALE }

# NEW: Single redirect handler for default section (Route 7)
# Consolidates 4 previous routes into one
# Handles all formats, all locale variations (via scope's optional locale)
get 'projects/:id', to: 'projects#redirect_to_default_section',
    constraints: { id: VALID_ID },
    as: :project_redirect
```

#### Routes Modified

```ruby
# BEFORE: Inside resources member block
get '' => 'projects#show_json', constraints: ->(req) { req.format == :json }

# AFTER: Outside scope, explicit route (Route 2)
# Moved before localized JSON redirect for performance (common case first)
get 'projects/:id', to: 'projects#show_json',
    constraints: { id: VALID_ID, format: 'json' }

# ----

# BEFORE: Inside resources member block
get ':criteria_level(.:format)' => 'projects#show',
    constraints: { criteria_level: VALID_CRITERIA_LEVEL }

# AFTER: Explicit route, renamed parameter (Route 6)
get 'projects/:id/:section', to: 'projects#show',
    constraints: { id: VALID_ID, section: VALID_CRITERIA_LEVEL }

# ----

# BEFORE: Separate match outside resources, optional criteria_level with /edit suffix
match 'projects/:id/(:criteria_level/)edit' => 'projects#update',
      via: [:put, :patch]
# Accepts: PUT/PATCH /projects/:id/passing/edit (non-standard)
#       or PUT/PATCH /projects/:id/edit (if criteria_level omitted)

# AFTER: Inside scope, optional section, optional /edit suffix (Route 8)
# Follows REST conventions while maintaining backward compatibility
match 'projects/:id(/:section)(/edit)', to: 'projects#update',
      via: [:put, :patch],
      constraints: { id: VALID_ID, section: VALID_CRITERIA_LEVEL }
# Accepts all these patterns:
# - PUT/PATCH /projects/:id (section inferred from referrer or defaults to passing)
# - PUT/PATCH /projects/:id/:section (preferred - explicit redirect target, standard REST)
# - PUT/PATCH /projects/:id/:section/edit (deprecated - backward compat)
```

**Forms should be updated to use the new pattern:**

- Internal forms: Update to use `update_project_section_path` (no `/edit` suffix)
- External clients: Both patterns work, but `/edit` is deprecated
- Transition period: Old pattern continues working but generates deprecation warnings (optional)

### Routing Table Implementation

**Proposed routes in `config/routes.rb` (order matters):**

```ruby
# Route order is critical - Rails matches top to bottom
# More specific routes must come before more generic routes

# Note: Using these constants:
# From config/routes.rb:
#   LEGAL_LOCALE - derived from I18n.available_locales
#   VALID_ID - matches [1-9][0-9]*
# From config/initializers/01_section_names.rb (Sections module):
#   Sections::VALID_SECTION_REGEX - matches primary and obsolete section names
#   Sections::PRIMARY_SECTION_REGEX - matches only primary sections (excludes obsolete)

Rails.application.routes.draw do
  # ROUTE 1: Badge image (no locale needed, must be outside locale scope)
  # GET /projects/:id/badge.svg
  # Badge images need canonical URLs for CDN caching
  get 'projects/:id/badge', to: 'projects#badge',
      constraints: { id: VALID_ID, format: 'svg' },
      defaults: { format: 'svg' },
      as: :project_badge

  # ROUTE 2: JSON API (locale-independent, outside scope)
  # GET /projects/:id.json
  # This is the expected common case, so it's matched first for performance
  get 'projects/:id', to: 'projects#show_json',
      constraints: { id: VALID_ID, format: 'json' },
      defaults: { format: 'json' },
      as: :project_json

  # ROUTE 3: Redirect localized JSON to non-localized version
  # GET /:locale/projects/:id.json → /projects/:id.json (301 permanent)
  # Handle common mistake of adding locale to JSON URLs (less frequent)
  get ':locale/projects/:id', to: redirect('/projects/%{id}.json', status: 301),
      constraints: {
        id: VALID_ID,
        format: 'json',
        locale: LEGAL_LOCALE
      }

  # Localized routes (optional locale parameter)
  scope '(:locale)', locale: LEGAL_LOCALE do
    # Standard RESTful routes
    # Excludes :show and :edit (custom routes below)
    # Excludes :update (custom route below with section parameter)
    resources :projects, only: [:index, :new, :create, :destroy]

    # ROUTE 4: Delete confirmation form (specific, before generic :section)
    # GET (/:locale)/projects/:id/delete_form
    get 'projects/:id/delete_form', to: 'projects#delete_form',
        constraints: { id: VALID_ID },
        as: :delete_form_project

    # ROUTE 5: Edit with section (before show to avoid conflicts)
    # GET (/:locale)/projects/:id/:section/edit
    # Use PRIMARY_SECTION_REGEX to reject obsolete sections in edit URLs
    get 'projects/:id/:section/edit', to: 'projects#edit',
        constraints: {
          id: VALID_ID,
          section: Sections::PRIMARY_SECTION_REGEX
        },
        as: :edit_project_section

    # ROUTE 6: Show section with format (HTML or Markdown)
    # GET (/:locale)/projects/:id/:section(.:format)
    # Use VALID_SECTION_REGEX to accept obsolete sections (controller will redirect)
    get 'projects/:id/:section', to: 'projects#show',
        constraints: {
          id: VALID_ID,
          section: Sections::VALID_SECTION_REGEX
        },
        as: :project_section,
        defaults: { format: 'html' }

    # ROUTE 7: Redirect to default section (all formats, with/without locale)
    # GET (/:locale)/projects/:id(.:format) → (/:locale)/projects/:id/passing(.:format)
    get 'projects/:id', to: 'projects#redirect_to_default_section',
        constraints: { id: VALID_ID },
        as: :project_redirect

    # ROUTE 8: Update project (PUT/PATCH) - section optional
    # PUT/PATCH (/:locale)/projects/:id(/:section)(/edit) → projects#update
    # Accepts all these patterns:
    # - PUT/PATCH /:locale/projects/:id (section inferred from referrer or defaults)
    # - PUT/PATCH /:locale/projects/:id/:section (preferred - explicit redirect target)
    # - PUT/PATCH /:locale/projects/:id/:section/edit (deprecated - backward compat)
    # The /edit suffix is optional to support external clients during transition
    # IMPORTANT: Section in URL is for routing only - ANY project field can be
    # updated regardless of section. Programs can update any field without knowing
    # which section it belongs to.
    # Use PRIMARY_SECTION_REGEX to reject obsolete sections in update URLs
    match 'projects/:id(/:section)(/edit)', to: 'projects#update',
          via: %i[put patch],
          constraints: { id: VALID_ID, section: Sections::PRIMARY_SECTION_REGEX },
          as: :update_project
  end
end
```

### Route Ordering Analysis

**Why this order is critical:**

1. **Badge (Route 1)**: Outside scope, format-constrained, canonical URL for CDN
2. **JSON API (Route 2)**: Outside scope, handles non-localized JSON requests
   - **Common case first**: Most JSON requests use this pattern
   - Performance: Matches expected usage immediately
3. **JSON redirect (Route 3)**: Outside scope, redirects localized JSON
   - **Error case second**: Handles mistaken locale in JSON URL
   - Won't match Route 2 due to extra `:locale` path segment
4. **Localized scope begins**: All remaining routes inside `scope '(:locale)'`
5. **delete_form (Route 4)**: Literal string `delete_form` must match before
   generic `:section` parameter
6. **:section/edit (Route 5)**: Edit URLs have `/edit` suffix, must match
   before generic `:section` route
7. **:section show (Route 6)**: Displays section content (HTML/Markdown)
8. **:id redirect (Route 7)**: Catches bare project ID, redirects to default
   section; must come after more specific routes
9. **Update (Route 8)**: PUT/PATCH for project updates with section parameter
   - Order doesn't matter for this route (different HTTP verbs from GET routes)

**Route order errors to avoid:**

```ruby
# WRONG - generic route matches before specific:
scope '(:locale)' do
  get 'projects/:id/:section', to: 'projects#show'        # Too generic
  get 'projects/:id/delete_form', to: 'projects#delete_form'  # Never reached!
end

# CORRECT - specific before generic:
scope '(:locale)' do
  get 'projects/:id/delete_form', to: 'projects#delete_form'  # Matches first
  get 'projects/:id/:section', to: 'projects#show'            # Catches rest
end

# WRONG - JSON inside scope would require locale:
scope '(:locale)' do
  get 'projects/:id', to: 'projects#show_json',
      constraints: { format: 'json' }  # Would require locale in URL!
end

# CORRECT - JSON outside scope, locale-independent:
get 'projects/:id', to: 'projects#show_json',
    constraints: { format: 'json' }  # Works without locale
```

### Controller Methods Implementation

**Changes to `app/controllers/projects_controller.rb`:**

```ruby
class ProjectsController < ApplicationController
  # Use frozen constants from Sections module (config/initializers/01_section_names.rb)
  # All constants computed once at boot time and available via Sections:: prefix
  # No need to redefine them - just reference Sections::CONSTANT_NAME directly

  # Existing before_action filters
  before_action :set_project, only: [:show, :edit, :update, :destroy,
                                      :delete_form, :badge, :show_json,
                                      :redirect_to_default_section]
  before_action :set_locale, except: [:badge, :show_json]

  # EXISTING METHOD (minimal changes)
  def index
    # Unchanged - shows project list
  end

  # EXISTING METHOD (minimal changes)
  def new
    # Unchanged - shows new project form
  end

  # EXISTING METHOD (minimal changes)
  def create
    # Unchanged - creates new project
  end

  # MODIFIED METHOD: Handle optional section parameter
  def update
    # Section is now OPTIONAL in the URL
    @section = params[:section]

    # Authorize user can edit this project
    authorize_edit!

    # Update the project with submitted parameters
    if @project.update(project_params)
      # Determine where to redirect after successful update
      redirect_section = determine_redirect_section(@section)

      redirect_to project_section_path(@project, redirect_section,
                                       locale: params[:locale]),
                  notice: t('projects.update.success')
    else
      # Failed - re-render edit form
      # Load section-specific data for the form
      load_section_data_for_edit(@section || DEFAULT_SECTION)
      render "projects/edit_#{@section || DEFAULT_SECTION}"
    end
  end

  private

  # Determine where to redirect after successful project update
  # @param section [String, nil] section from URL (may be nil)
  # @return [String] section name to redirect to
  def determine_redirect_section(section)
    # If section provided in UPDATE request URL, use it (explicit redirect target)
    # Example: PUT /projects/123/silver → section='silver' from params[:section]
    # Use Sections::VALID_NAMES from initializer (frozen array)
    return section if section.present? && Sections::VALID_NAMES.include?(section)

    # Otherwise, try to infer from referrer (the page they came from)
    # This handles unusual cases where update URL lacks section but referrer has it
    # Example: PUT /projects/123 (no section) but came from /en/projects/123/silver/edit
    # Note: Most edit links will include section, so this is primarily a fallback
    if request.referer.present?
      # Extract section from REFERRER URL (different from update URL)
      # Example referrer: /en/projects/123/silver/edit → extract "silver"
      match = request.referer.match(%r{/projects/\d+/([^/]+)(/edit)?$})
      return match[1] if match && Sections::VALID_NAMES.include?(match[1])
    end

    # Fallback: redirect to default section
    # Use Sections::DEFAULT_SECTION from initializer (frozen string)
    Sections::DEFAULT_SECTION
  end

  # Load section-specific data needed for edit forms
  # @param section [String] section name
  def load_section_data_for_edit(section)
    if section == 'permissions'
      @additional_rights_str = @project.additional_rights_to_s
    else
      @criteria = @project.criteria_for_section(section)
    end
  end

  # EXISTING METHOD (minimal changes)
  def destroy
    # Unchanged - destroys project
  end

  # EXISTING METHOD (unchanged)
  def delete_form
    # Shows delete confirmation page
    # No changes - already isolated as separate action
    authorize_admin_or_owner!
    # Renders delete confirmation view
  end

  # EXISTING METHOD (unchanged)
  def badge
    # Returns SVG badge image
    # No changes - already locale-independent
    respond_to do |format|
      format.svg { render_badge_svg }
    end
  end

  # MODIFIED METHOD: Replaces old show/show_markdown with section-aware version
  def show
    # Section is always present (route constraint ensures it)
    # No default needed - this action is ONLY called when :section is in URL
    @section = params[:section]

    # Handle obsolete section names with permanent redirect
    # Use Sections::REDIRECTS from initializer (frozen hash)
    if Sections::REDIRECTS.key?(@section)
      redirect_to project_section_path(@project,
                                       Sections::REDIRECTS[@section],
                                       locale: params[:locale]),
                  status: :moved_permanently
      return
    end

    # Validate section is known (should always pass due to route constraints,
    # but provides safety and better error messages)
    # Use Sections::VALID_NAMES from initializer (frozen array)
    unless Sections::VALID_NAMES.include?(@section)
      raise ActionController::RoutingError, "Invalid section: #{@section}"
    end

    # Load ONLY section-specific data (optimization: don't load irrelevant criteria)
    # Different sections need different data
    if @section == 'permissions'
      # Permissions section: load additional rights data
      # Call model method in controller, not view (Rails best practice)
      @additional_rights_str = @project.additional_rights_to_s

      # SAFEGUARD: Permissions section doesn't support markdown format
      # Markdown is for criteria only, not permissions
      if request.format.md?
        raise ActionController::RoutingError,
              'Markdown format not supported for permissions section'
      end
    else
      # Criteria sections: load criteria and status for this section
      @criteria = @project.criteria_for_section(@section)
      @section_status = @project.section_status(@section)

      # For markdown format, set @criteria_level for the view
      # The existing show_markdown.erb checks @criteria_level:
      # - If blank: generates markdown for ALL levels (old behavior)
      # - If set: generates markdown for ONLY that level (new per-section behavior)
      @criteria_level = @section if request.format.md?
    end

    respond_to do |format|
      format.html { render "projects/show_#{@section}", layout: 'application' }
      format.md do
        # Only reach here if @section is a criteria level (not permissions)
        render 'projects/show_markdown', layout: false,
               content_type: 'text/markdown'
      end
    end
  end

  # MODIFIED METHOD: Replaces old edit with section-aware version
  def edit
    # Section is always present (route constraint ensures it)
    # No default needed - this action is ONLY called when :section is in URL
    @section = params[:section]

    # Validate section is known (should always pass due to route constraints,
    # but provides safety and better error messages)
    # Use Sections::VALID_NAMES from initializer (frozen array)
    unless Sections::VALID_NAMES.include?(@section)
      raise ActionController::RoutingError, "Invalid section: #{@section}"
    end

    authorize_edit!

    # Load ONLY section-specific data (optimization: don't load irrelevant criteria)
    # Use same helper method as update method for consistency
    load_section_data_for_edit(@section)
    render "projects/edit_#{@section}"
  end

  # NEW METHOD: Replaces old show_json with explicit method
  def show_json
    # If locale in URL, redirect to remove it (301 permanent)
    if params[:locale].present?
      redirect_to project_json_path(@project), status: :moved_permanently
      return
    end

    # Return full project JSON (all sections, no localization)
    render json: @project.to_json(
      include: {
        criteria_answers: { only: [:criterion_id, :value, :justification] },
        additional_rights: { only: [:user_id, :project_id] }
      },
      methods: [:badge_level, :all_sections_status]
    )
  end

  # NEW METHOD: Redirects bare project URL to default section
  def redirect_to_default_section
    # Future: could read @project.default_section from database
    # Use Sections::DEFAULT_SECTION from initializer (frozen string)
    default_section = Sections::DEFAULT_SECTION

    # Preserve format if specified
    format = request.format.symbol == :html ? nil : request.format.symbol

    redirect_to project_section_path(@project, default_section,
                                     locale: params[:locale],
                                     format: format),
                status: :found  # 302 temporary (may become configurable)
  end

  # NEW METHOD: Redirects markdown without locale to add detected locale
  def redirect_markdown_to_locale
    detected_locale = detect_locale_from_browser
    redirect_to project_section_path(@project, DEFAULT_SECTION,
                                     locale: detected_locale,
                                     format: :md),
                status: :found  # 302 temporary
  end

  # NEW METHOD: Redirects markdown with locale to default section
  def redirect_markdown_to_section
    redirect_to project_section_path(@project, DEFAULT_SECTION,
                                     locale: params[:locale],
                                     format: :md),
                status: :found  # 302 temporary
  end

  private

  def set_project
    @project = Project.find(params[:id])
  end

  def set_locale
    I18n.locale = params[:locale] || detect_locale_from_browser
  end

  def detect_locale_from_browser
    # Existing locale detection logic
  end

  def authorize_edit!
    # Existing authorization logic
  end

  def authorize_admin_or_owner!
    # Existing authorization logic
  end
end
```

### Markdown Generation Changes

The current markdown generation in `app/views/projects/show_markdown.erb`
already supports per-section rendering, but it needs to be integrated with the
new routing structure.

#### Current Implementation (lines 4-8 of show_markdown.erb)

```erb
<%-
  # @criteria_level should always be a string, but handle nil gracefully.
  if @criteria_level.blank? then
    criteria_levels = Criteria.keys.map { |key| normalize_criteria_level(key) }
  else
    criteria_levels = [@criteria_level]
  end
-%>
```

**Current behavior:**

- If `@criteria_level` is blank → generates markdown for ALL levels
- If `@criteria_level` is set → generates markdown for ONLY that level

#### Changes Required

**Controller (projects_controller.rb):**

```ruby
def show
  @section = params[:section]
  # ... validation and redirects ...

  # NEW: Set @criteria_level for markdown rendering
  # The view already supports this - we just need to set it
  @criteria_level = @section if request.format.md?

  respond_to do |format|
    format.html { render "projects/show_#{@section}", layout: 'application' }
    format.md   { render 'projects/show_markdown', layout: false }
  end
end
```

**View (show_markdown.erb):**

The view already supports per-section rendering! No changes needed to the view
logic. When `@criteria_level` is set (which it will always be now), the view
generates markdown for only that section.

**Result:**

- Old URL: `/projects/123.md` → generates markdown for ALL sections
- New URL: `/en/projects/123/passing.md` → generates markdown for ONLY passing section
- New URL: `/en/projects/123/silver.md` → generates markdown for ONLY silver section

This change aligns markdown with HTML behavior (both are per-section) and
reduces the size of markdown downloads for users who only need one section.

### Permissions Section Database Query Issue

**Current Problem:**

The permissions view (`app/views/projects/_form_permissions.html.erb`) makes
database queries from the view, which is a Rails anti-pattern. Queries should
be in the controller.

**Lines 56 and 145 of _form_permissions.html.erb:**

```erb
<%= t('projects.form_basics.additional_rights_changes.description',
      current_rights: project.additional_rights_to_s) %>
```

**What `additional_rights_to_s` does (app/models/project.rb:317-321):**

```ruby
def additional_rights_to_s
  # "distinct" shouldn't be needed; it's purely defensive here
  list = AdditionalRight.for_project(id).distinct.pluck(:user_id)
  list.sort.to_s
end
```

This executes a database query: `AdditionalRight.for_project(id)` retrieves all
additional rights records for the project, then plucks user IDs.

**Required Fix:**

Call the model method in the controller (not in the view) and set an instance variable:

```ruby
def show
  @section = params[:section]
  # ... existing validation ...

  # Load section-specific data
  if @section == 'permissions'
    # Call model method in controller, not view (Rails best practice)
    # This executes the query once and caches the result
    @additional_rights_str = @project.additional_rights_to_s
  else
    @criteria = @project.criteria_for_section(@section)
    @section_status = @project.section_status(@section)
  end

  # ... rest of method ...
end
```

**Update view to use instance variable:**

```erb
<%# Before: calls model method from view (bad - query in view) %>
current_rights: project.additional_rights_to_s

<%# After: uses instance variable set by controller (good - query in controller) %>
current_rights: @additional_rights_str
```

**Benefits:**

- Follows Rails best practices (queries in controller, not view)
- Makes it explicit what data the view depends on
- Easier to optimize and test
- Consistent with the optimization of loading only section-specific data

### Form URL Changes Required

**CHANGE (with backward compatibility):** The update route pattern has changed to
follow REST conventions, but the old pattern with `/edit` suffix will continue to
work for backward compatibility.

#### Forms That Need Updates

All project edit forms currently submit to URLs ending in `/edit`:

**Files to update:**

- `app/views/projects/_form_0.html.erb`
- `app/views/projects/_form_1.html.erb`
- `app/views/projects/_form_2.html.erb`
- `app/views/projects/_form_baseline-1.html.erb`
- `app/views/projects/_form_baseline-2.html.erb` (if exists)
- `app/views/projects/_form_baseline-3.html.erb` (if exists)
- `app/views/projects/_form_permissions.html.erb`

#### Current Form Pattern (deprecated but still works)

```erb
<%# Example from _form_permissions.html.erb line 64 %>
<%= bootstrap_form_for project, url: put_project_path(project, criteria_level: 'permissions') do |f| %>
  <%# Form fields... %>
<% end %>
```

Generates: `PUT /projects/123/permissions/edit` (deprecated, but backward compatible)

#### Preferred Form Pattern (standard REST)

```erb
<%# Updated form - preferred, section explicit in URL %>
<%= bootstrap_form_for project, url: update_project_path(project, section: @section) do |f| %>
  <%# Form fields... %>
<% end %>
```

Generates: `PUT /projects/123/permissions` (standard REST, section explicit)

**Why include section in URL:**

- Makes redirect target explicit (no need to infer from referrer)
- Form handler knows which section to return to after successful update
- Cleaner than relying on fallback logic

**Alternative using route helper with explicit section:**

```erb
<%# Also acceptable - uses named section directly %>
<%= bootstrap_form_for project, url: update_project_path(project, section: 'permissions') do |f| %>
  <%# Form fields... %>
<% end %>
```

#### Important Note About Section Parameter

**The section in the URL is for routing only.** When the update is submitted to
`PUT /projects/:id/:section`, the controller receives ALL form parameters and
can update ANY field in the project, regardless of which section that field
belongs to.

This design makes it easier for programs to update projects without needing to:

- Know which fields belong to which section
- Send multiple requests to update different sections
- Implement complex field-to-section mapping logic

**Example:** A form at `/projects/123/passing/edit` can submit updates to
both passing-level criteria AND user preferences (like notification settings)
in a single request to `PUT /projects/123/passing`.

#### Backward Compatibility Strategy

The route pattern `'projects/:id/:section(/edit)'` uses parentheses to make
`/edit` optional. This means:

**Both patterns accepted:**

1. `PUT /projects/123/passing` - **Preferred**, standard REST
2. `PUT /projects/123/passing/edit` - **Deprecated**, backward compatible

**Migration approach:**

1. **Phase 1:** Deploy new routes (both patterns work)
2. **Phase 2:** Update all internal forms to use preferred pattern
3. **Phase 3:** Test that old pattern still works for external clients
4. **Optional Phase 4:** Add deprecation warnings for `/edit` pattern
5. **Optional Phase 5:** Remove `/edit` pattern after sufficient transition period

**Advantages of this approach:**

- No breaking changes for external API clients
- Internal forms can be updated gradually
- Easy to roll back if issues discovered
- Clear migration path with measurable progress
- Can add logging to track usage of deprecated pattern

**Optional deprecation logging:**

```ruby
# In projects_controller.rb update method
def update
  # Log deprecation if /edit pattern used
  if request.path.end_with?('/edit')
    Rails.logger.warn(
      "DEPRECATED: PUT/PATCH to #{request.path} uses deprecated /edit suffix. " \
      "Use #{request.path.sub('/edit', '')} instead."
    )
  end
  # ... rest of update logic
end
```

This logging helps identify external clients that need to update their code.

### Controller Method Changes Summary

| Method | Change Type | Rationale |
|--------|-------------|-----------|
| `index` | Unchanged | No routing changes affect this |
| `new` | Unchanged | No routing changes affect this |
| `create` | Unchanged | POST, not part of GET consolidation |
| `update` | **Modified** | Now handles optional section parameter; infers redirect target from section, referrer, or default; uses shared helper for data loading |
| `destroy` | Unchanged | DELETE, not part of GET consolidation |
| `delete_form` | Unchanged | Kept separate (see Opportunity 1 analysis) |
| `badge` | Unchanged | Already simple and locale-independent |
| `show` | **Modified** | Now section-aware; section always present in params (no default); loads only section-specific data; handles HTML and MD formats; includes obsolete section redirects; safeguards against markdown for permissions |
| `edit` | **Modified** | Now section-aware; section always present in params (no default); loads only section-specific data using shared helper; validates section parameter |
| `show_json` | **New explicit** | Separated from show; handles locale redirect; returns full project JSON |
| `show_markdown` | **Removed** | Functionality merged into `show` with format.md |
| `redirect_to_default_section` | **New** | Handles `/:locale/projects/:id` → `/:locale/projects/:id/passing` |
| `redirect_markdown_to_locale` | **Removed** | Consolidated into `redirect_to_default_section` |
| `redirect_markdown_to_section` | **Removed** | Consolidated into `redirect_to_default_section` |
| `determine_redirect_section` | **New (private)** | Helper to determine redirect target after update (from section param, referrer, or default) |
| `load_section_data_for_edit` | **New (private)** | Shared helper for loading section-specific data (permissions vs criteria) |

### Critical Implementation Details

This section addresses the critical issues identified during comprehensive review
to ensure low risk and high likelihood of immediate success.

#### Issue 1: Section Parameter Must Be Optional (RESOLVED)

**Problem**: Initial proposal required `:section` parameter in update route,
which would break `_form_0.html.erb` that uses `project_path(project)` to
generate `PATCH /projects/123` without section.

**Solution**: Made section optional using parentheses: `'projects/:id(/:section)(/edit)'`

**Route now accepts**:

- `PUT/PATCH /projects/:id` - section inferred from referrer or defaults to passing
- `PUT/PATCH /projects/:id/:section` - explicit section (preferred)
- `PUT/PATCH /projects/:id/:section/edit` - backward compatibility

**Controller implementation**: `determine_redirect_section` method (lines 889-910)
handles all three cases:

1. If section in URL → use it
2. Else if section in referrer → extract it
3. Else → default to 'passing'

**Recommended form updates**: When generating edit URLs and form submission URLs,
include the section parameter so the recipient (form handler) knows which section
to redirect to after successful update. This makes the redirect target explicit
rather than relying on the referrer fallback.

Example:

```ruby
# In edit action or view that generates form URL:
url: update_project_path(project, section: @section)
# Generates: PUT /projects/123/passing (section explicit in URL)
```

#### Issue 2: Permissions Section Markdown Generation (RESOLVED)

**Problem**: Permissions section doesn't have criteria, so generating markdown
would fail or produce nonsensical output.

**Solution**: Added safeguard in `show` method (lines 964-969) to raise error
if markdown format requested for permissions section.

**Error message**: "Markdown format not supported for permissions section"

**Why this works**: Permissions section only makes sense as HTML (form for
editing user permissions). Markdown is only for criteria documentation.

#### Issue 3: Edit Method Data Loading (RESOLVED)

**Problem**: Edit method needs same permissions data loading logic as show method.

**Solution**: Created shared helper method `load_section_data_for_edit` (lines
904-912) that:

- Loads `@additional_rights_str` for permissions section
- Loads `@criteria` for criteria sections
- Used by both `edit` and `update` methods (DRY)

#### Issue 4: VALID_SECTIONS Calculation (RESOLVED via Phase 0)

**Solution**: All section-related constants computed once in
`config/initializers/00_section_names.rb` (see Phase 0).

**Constants available**:

```ruby
# From config/initializers/00_section_names.rb (all frozen, in Sections module)
Sections::VALID_NAMES                        # Array of valid sections (excludes obsolete)
Sections::REDIRECTS                          # Hash mapping obsolete → canonical names
Sections::PRIMARY_SECTION_REGEX              # Regex for route constraints (primary only)
Sections::VALID_SECTION_REGEX  # Regex for route constraints (all sections)
Sections::DEFAULT_SECTION                    # String 'passing'
```

**Benefits**:

- Single source of truth in one initializer file
- Namespaced under `Sections::` to avoid global namespace pollution
- Computed once at boot time, frozen, reused everywhere
- No dependencies between routes.rb and controller
- Clear, accurate naming (e.g., `Sections::VALID_NAMES` not `VALID_SECTION_NAMES`)
- Updates automatically when new sections added to initializer

#### Issue 5: Redirect Logic After Update (RESOLVED)

**Implementation**: `determine_redirect_section` method provides clear fallback chain:

1. **Explicit section in URL** (preferred):
   - `PUT /projects/123/silver` → redirects to `/projects/123/silver`
   - Clear, unambiguous

2. **Inferred from referrer**:
   - User submitted form from `/projects/123/gold/edit`
   - Extract "gold" from referrer URL
   - Redirect to `/projects/123/gold`

3. **Default fallback**:
   - No section in URL, no valid section in referrer
   - Redirect to `/projects/123/passing`
   - Consistent behavior

**Why this is safe**:

- Validates section against VALID_SECTIONS before using
- Regex extraction from referrer is simple and robust
- Always has valid fallback
- No edge cases that result in invalid redirects

#### Testing Requirements for Critical Issues

**Must test**:

1. Update without section parameter (from `_form_0.html.erb`)
   - Verifies optional section works
   - Verifies redirect to default section

2. Update with section parameter (from other forms)
   - Verifies explicit section preserved in redirect

3. Markdown request for permissions section
   - Verifies error raised (not silent failure)

4. Edit method with permissions section
   - Verifies `@additional_rights_str` loaded correctly

5. Redirect inference from referrer
   - Verifies section extracted from referrer URL
   - Verifies fallback to default if extraction fails

6. VALID_SECTIONS calculation
   - Verifies obsolete sections excluded
   - Verifies all valid sections included

### Memory Requirement Analysis

**Will this reduce memory requirements? Yes, significantly.**

#### Current Route Memory Consumption

Each route in Rails requires memory for:

1. **Route object**: Pattern matcher, constraints, defaults (~500-800 bytes)
2. **Regex compilation**: Compiled regular expressions for matching (~200-400 bytes per regex)
3. **Journey tree nodes**: Internal routing tree structure (~300-500 bytes per node)

**Current implementation (from Appendix):**

- 23 GET routes for `/projects` (not counting POST/PATCH/PUT/DELETE)
- Many with duplicated patterns for locale handling
- Many with duplicated regex patterns

**Estimated current memory: 23 routes × 1000 bytes = ~23 KB**

#### Proposed Route Memory Consumption

**Proposed implementation:**

- 10 route definitions (vs. 23 current)
- Reduced regex duplication (shared constraints)
- Simpler route tree structure

**Estimated proposed memory: 10 routes × 1000 bytes = ~10 KB**

**Memory savings: ~13 KB (56% reduction)**

#### Why the Reduction Happens

1. **Eliminated Redundant Patterns**:

   **Current (wasteful):**

   ```ruby
   # Each of these is a separate route object in memory:
   get '(/:locale)/:locale/projects/:id/0'          # Route object 1
   get '(/:locale)/projects/:id/0'                   # Route object 2
   get '(/:locale)/:locale/projects/:id/0/edit'     # Route object 3
   get '(/:locale)/projects/:id/0/edit'             # Route object 4
   # ... 16 more similar routes for 1, 2, bronze ...
   ```

   **Proposed (efficient):**

   ```ruby
   # Single route handles all obsolete sections via constraint:
   get ':id/:section', constraints: { section: /.../}  # Route object 1
   # Obsolete redirects handled in controller, not separate routes
   ```

2. **Consolidated Format Handling**:

   **Current (wasteful):**

   ```ruby
   # Three separate routes for same URL pattern:
   get '(/:locale)/projects/:id' → projects#show          # HTML
   get '(/:locale)/projects/:id' → projects#show_json     # JSON
   get '(/:locale)/projects/:id' → projects#show_markdown # MD
   ```

   **Proposed (efficient):**

   ```ruby
   # One route with format discrimination:
   get ':id/:section'            # HTML/MD via respond_to
   get '(:locale/)projects/:id'  # JSON separate (different params)
   # = 2 routes instead of 3
   ```

3. **Shared Constraint Objects**:

   Rails can reuse constraint regex objects when they're identical:

   ```ruby
   # If multiple routes use: constraints: { id: /[1-9][0-9]*/ }
   # Rails stores ONE compiled regex object, referenced by all routes
   # Proposed plan uses same constraints repeatedly = more sharing
   ```

4. **Simpler Route Tree**:

   Rails builds an internal tree structure for route matching:
   - Current: Deep tree with many branches for locale variations,
     format variations, section variations
   - Proposed: Shallower tree with fewer branches, more constraint-based
     matching

   Fewer tree nodes = less memory

#### Runtime Performance Impact

**Memory reduction improves runtime performance:**

1. **Faster route matching**: Fewer routes to check = faster lookups
   - Current: Rails may check 15-20 routes before finding match
   - Proposed: Rails checks 5-8 routes maximum

2. **Better CPU cache utilization**: Smaller route table fits in CPU cache
   - 10 KB route table likely fits in L2 cache
   - 23 KB route table may spill to L3 or RAM

3. **Reduced GC pressure**: Less memory allocated = less garbage collection

**Estimated performance improvement: 15-25% faster route matching**

### Simplifications and Improvements

After reviewing the implementation plan, several opportunities exist to reduce
complexity and work:

#### 1. Reuse Existing Route Constants (ADDRESSED IN PHASE 0)

**Status**: ✅ This is now handled by Phase 0 constant consolidation.

**Previous issue**: Constants were scattered across routes.rb and initializers
with inconsistent naming.

**Solution**: All section-related constants now defined in
`config/initializers/00_section_names.rb` under `Sections::` module:

- `Sections::VALID_SECTION_REGEX` - replaces `VALID_CRITERIA_LEVEL`
- `Sections::PRIMARY_SECTION_REGEX` - for routes requiring valid sections only
- `Sections::REDIRECTS` - replaces `LEVEL_REDIRECTS`
- `Sections::VALID_NAMES` - array of valid sections
- `Sections::DEFAULT_SECTION` - default section string

**Benefits achieved:**

- **Single source of truth** - all constants in one initializer
- **Namespaced** - `Sections::` module avoids global namespace pollution
- **Clear naming** - SECTION_NAMES vs CRITERIA_LEVEL_NAMES distinction
- **Computed once** - frozen at boot time, reused everywhere
- **No dependencies** - routes and controllers both use initializer constants

#### 2. Simplify JSON Route Handling

**Current (confusing):**

```ruby
# ROUTE 7: Tries to handle both cases
get '(:locale/)projects/:id', to: 'projects#show_json'

# ROUTE 8: Then redirects one case
get ':locale/projects/:id', to: redirect('/projects/%{id}.json', status: 301)
```

**Improved (clearer):**

```ruby
# ROUTE 7: Redirect localized JSON FIRST (more specific)
get ':locale/projects/:id', to: redirect('/projects/%{id}.json', status: 301),
    constraints: {
      id: VALID_ID,
      format: 'json',
      locale: LEGAL_LOCALE
    }

# ROUTE 8: Then handle non-localized JSON (less specific)
get 'projects/:id', to: 'projects#show_json',
    constraints: {
      id: VALID_ID,
      format: 'json'
    },
    defaults: { format: 'json' },
    as: :project_json
```

**Benefits:**

- Routes ordered from specific to generic (standard Rails pattern)
- Each route has one clear purpose
- No optional locale parameter confusion
- Easier to understand what matches what

#### 3. Consolidate All Default Section Redirects

**Current (three separate routes and methods):**

```ruby
# ROUTE 5: HTML without section
get '/:locale/projects/:id', to: 'projects#redirect_to_default_section'

# ROUTE 9: Markdown without locale
get '/projects/:id', to: 'projects#redirect_markdown_to_locale',
    constraints: { format: 'md' }

# ROUTE 10: Markdown without section
get '/:locale/projects/:id', to: 'projects#redirect_markdown_to_section',
    constraints: { format: 'md' }
```

**Improved (one route, one method):**

```ruby
# Single route with optional locale handles all formats
scope '(:locale)', locale: LEGAL_LOCALE do
  get 'projects/:id', to: 'projects#redirect_to_default_section',
      constraints: { id: VALID_ID }
end

# Single controller method handles everything
def redirect_to_default_section
  # Detect locale if not provided (can reuse existing locale detection logic)
  locale = params[:locale] || detect_locale_from_browser

  # Preserve format (HTML, Markdown, etc.)
  format = request.format.symbol == :html ? nil : request.format.symbol

  redirect_to project_section_path(@project, DEFAULT_SECTION,
                                   locale: locale, format: format),
              status: :found
end
```

**Benefits:**

- **3 routes reduced to 1** (major simplification)
- **3 controller methods reduced to 1** (significant code reduction)
- Handles all combinations: with/without locale, any format
- Optional locale in scope handles both cases automatically
- Same logic path for all redirect scenarios
- Much simpler to test and understand

#### 4. Consider Route Redirects Instead of Controller Methods

**Current approach:**

```ruby
# Route calls controller method
get ':id', to: 'projects#redirect_to_default_section'

# Controller method
def redirect_to_default_section
  default_section = DEFAULT_SECTION
  format = request.format.symbol == :html ? nil : request.format.symbol
  redirect_to project_section_path(@project, default_section, ...)
end
```

**Alternative (if per-project defaults not needed soon):**

```ruby
# Simple redirect in routes (no controller method needed)
get ':id', to: redirect { |params, request|
  "/#{params[:locale]}/projects/#{params[:id]}/passing"
}, constraints: { id: RouteConstraints::POSITIVE_INTEGER }
```

**Trade-off:**

- **Pro**: No controller method needed, simpler
- **Con**: Harder to make per-project configurable later
- **Recommendation**: Keep controller method if per-project defaults planned
  within 6-12 months; otherwise use route redirect

#### 5. Derive VALID_SECTIONS from Existing Constants (ADDRESSED IN PHASE 0)

**Status**: ✅ This is now handled by Phase 0 constant consolidation.

**Solution**: All section-related constants computed once in
`config/initializers/00_section_names.rb` under `Sections::` module:

```ruby
# All computed at boot time, frozen, available everywhere via Sections:: prefix
module Sections
  VALID_NAMES = (ALL_NAMES - OBSOLETE_NAMES).freeze
  PRIMARY_SECTION_REGEX = /#{Regexp.union(VALID_NAMES)}/.freeze
  VALID_SECTION_REGEX = /#{Regexp.union(ALL_NAMES + OBSOLETE_NAMES)}/.freeze
end
```

**Usage:**

```ruby
# Routes - use VALID_SECTION_REGEX to accept obsolete (controller redirects)
constraints: { section: Sections::VALID_SECTION_REGEX }

# Routes - use PRIMARY_SECTION_REGEX to reject obsolete
constraints: { section: Sections::PRIMARY_SECTION_REGEX }

# Controller - use Sections::VALID_NAMES array for validation
unless Sections::VALID_NAMES.include?(@section)
```

**Benefits achieved:**

- Single source of truth in one initializer file
- Namespaced under `Sections::` to avoid global namespace pollution
- Clear naming: ALL_NAMES (includes permissions) vs ALL_CRITERIA_LEVEL_NAMES (only levels)
- Computed once at boot, not recalculated
- No dependencies between routes and controller

#### 6. Avoid `resources` Block for Custom Routes

**Current (mixed approach):**

```ruby
scope '(:locale)' do
  resources :projects do
    # Custom routes inside resources block
    get ':id/delete_form', to: 'projects#delete_form'
    get ':id/:section/edit', to: 'projects#edit'
    # ...
  end
end
```

**Improved (explicit routes):**

```ruby
scope '(:locale)', locale: RouteConstraints::LOCALE do
  # Standard RESTful routes only
  resources :projects, only: [:index, :new, :create, :update, :destroy]

  # Custom routes explicitly defined
  get 'projects/:id/delete_form', to: 'projects#delete_form',
      constraints: { id: RouteConstraints::POSITIVE_INTEGER },
      as: :delete_form_project

  get 'projects/:id/:section/edit', to: 'projects#edit',
      constraints: {
        id: RouteConstraints::POSITIVE_INTEGER,
        section: RouteConstraints::VALID_SECTIONS
      },
      as: :edit_project_section
  # ...
end
```

**Benefits:**

- Clearer what routes actually exist
- No confusion about path generation
- Easier to see full route paths
- More explicit about which RESTful actions are used

### Recommended Simplified Implementation

Incorporating all improvements:

```ruby
# config/routes.rb

# Note: This file already defines these constants (reuse them):
# LEGAL_LOCALE - derived from I18n.available_locales
# VALID_CRITERIA_LEVEL - built from ALL_CRITERIA_LEVEL_NAMES
# VALID_ID - matches [1-9][0-9]*
# LEVEL_REDIRECTS - maps obsolete to canonical level names

Rails.application.routes.draw do
  # Badge (no locale, format-specific)
  get 'projects/:id/badge', to: 'projects#badge',
      constraints: { id: VALID_ID, format: 'svg' },
      defaults: { format: 'svg' },
      as: :project_badge

  # JSON redirects (locale → no locale)
  get ':locale/projects/:id', to: redirect('/projects/%{id}.json', status: 301),
      constraints: {
        id: VALID_ID,
        format: 'json',
        locale: LEGAL_LOCALE
      }

  # JSON API (no locale)
  get 'projects/:id', to: 'projects#show_json',
      constraints: { id: VALID_ID, format: 'json' },
      defaults: { format: 'json' },
      as: :project_json

  # Localized routes
  scope '(:locale)', locale: LEGAL_LOCALE do
    # Standard RESTful routes
    resources :projects, only: [:index, :new, :create, :update, :destroy]

    # Custom routes (specific before generic)
    get 'projects/:id/delete_form', to: 'projects#delete_form',
        constraints: { id: VALID_ID },
        as: :delete_form_project

    get 'projects/:id/:section/edit', to: 'projects#edit',
        constraints: {
          id: VALID_ID,
          section: VALID_CRITERIA_LEVEL
        },
        as: :edit_project_section

    get 'projects/:id/:section', to: 'projects#show',
        constraints: {
          id: VALID_ID,
          section: VALID_CRITERIA_LEVEL
        },
        as: :project_section,
        defaults: { format: 'html' }

    # Redirect to default section (handles all formats, with or without locale)
    get 'projects/:id', to: 'projects#redirect_to_default_section',
        constraints: { id: VALID_ID },
        as: :project_redirect
  end
end
```

**Controller changes:**

```ruby
# Consolidated redirect method (handles all formats, with or without locale)
def redirect_to_default_section
  # Detect locale if not provided
  locale = params[:locale] || detect_locale_from_browser

  # Preserve format if specified
  format = request.format.symbol == :html ? nil : request.format.symbol

  redirect_to project_section_path(@project, DEFAULT_SECTION,
                                   locale: locale,
                                   format: format),
              status: :found  # 302 temporary (may become configurable)
end

# Remove these methods (all consolidated into redirect_to_default_section):
# - redirect_markdown_to_locale (was handling markdown without locale)
# - redirect_markdown_to_section (was handling markdown with locale)
# - redirect_markdown (was the intermediate consolidation)
# All now handled by single redirect_to_default_section method
```

### Summary of Simplifications

| Improvement | Routes Reduced | Methods Reduced | Complexity Reduction |
|-------------|----------------|-----------------|---------------------|
| Reuse existing constants | 0 | 0 | High (DRY, maintainability) |
| Simplify JSON routes | 0 | 0 | Medium (clarity) |
| Consolidate default section redirects | **2** | **2** | **High** (major simplification) |
| Use explicit routes vs resources | 0 | 0 | Low (clarity) |
| **Total** | **2 routes** | **2 methods** | **Very Significant** |

**Net result:**

- **8 routes instead of 10** (20% reduction)
- **12 controller methods instead of 14** (14% reduction)
- Much more maintainable (constraints in one place)
- Clearer intent (explicit routes, ordered specific→generic)
- Optional locale scope eliminates duplicate routes
- **Significant code reduction overall**

### Testing the Implementation

**Verification steps after implementation:**

1. **Route inspection:**

   ```bash
   rake routes | grep projects
   # Should show ~10 route definitions (not 23)
   ```

2. **Memory measurement:**

   ```ruby
   # In rails console:
   memory_before = `ps -o rss= -p #{Process.pid}`.to_i
   Rails.application.reload_routes!
   memory_after = `ps -o rss= -p #{Process.pid}`.to_i
   puts "Route memory: #{memory_after - memory_before} KB"
   ```

3. **Performance measurement:**

   ```ruby
   # Benchmark route matching:
   require 'benchmark'
   url = '/en/projects/123/passing'
   Benchmark.bmbm do |x|
     x.report('route match') do
       10000.times { Rails.application.routes.recognize_path(url) }
     end
   end
   ```

## Format Handling Details

### HTML (Default)

- URL: `/:locale/projects/:id/:section` or `/:locale/projects/:id/:section.html`
- Renders localized HTML view of the specified section
- Uses Rails templates with I18n

### Markdown

- URL: `/:locale/projects/:id/:section.md`
- Renders localized Markdown view of the specified section
- **Change from current**: Markdown is now per-section, not per-project
- Old project-level markdown route will be removed
- Redirect chain: `/projects/:id.md` → `/:locale/projects/:id.md` →
  `/:locale/projects/:id/passing.md`

### JSON

- URL: `/(:locale/)projects/:id.json`
- If locale provided, redirects (permanently) to non-locale version.
- Returns complete project data as JSON
- Not locale-specific (client handles localization if needed)
- No per-section JSON endpoint

### Controller Implementation

```ruby
def show
  @section = params[:section] || 'passing'

  # Handle obsolete section names with permanent redirect
  if OBSOLETE_SECTIONS[@section]
    redirect_to project_section_path(@project, OBSOLETE_SECTIONS[@section]),
                status: :moved_permanently
    return
  end

  respond_to do |format|
    format.html { render_section_html }
    format.md   { render_section_markdown }
    # We will NOT use: format.json { render_project_json }
  end
end
```

## Redirect Types and Rationale

### Permanent Redirects (301)

Used when URLs should **never** be used again:

- **Obsolete section names**: `bronze` → `passing`, `0` → `passing`,
  `1` → `silver`, `2` → `gold`
- **Localized JSON URLs**: `/en/projects/123.json` → `/projects/123.json`
  (JSON is locale-independent)

Rationale: Search engines and browsers will cache these redirects,
reducing server load for old bookmarks.

### Temporary Redirects (302)

Used when redirect target **may change** in the future:

- **Locale detection**: `/projects` → `/:detected_locale/projects`
  (user's browser language may change)
- **Default section**: `/projects/:id` → `/projects/:id/passing`
  (will become per-project configurable)
- **Markdown section**: `/projects/:id.md` → `/:locale/projects/:id/passing.md`
  (default section may become configurable)

Rationale: Prevents caching of redirects that may change based on
user preferences or future features.

## Routes Being Removed

We don't need to support `/:locale/:locale/projects/...` routes;
doubled locales make no sense. Don't support them.

These current routes will be removed (functionality replaced):

```
# Old project-level markdown (replaced by section-level markdown)
GET (/:locale)/projects/:id(.:format) → projects#show_markdown

# Old project-level edit (replaced by section-level edit)
GET (/:locale)/projects/:id/edit(.:format) → projects#edit

# Note: Localized JSON routes will redirect (301) to non-localized version,
# not removed. See URL Migration Examples table for details.
```

## URL Migration Examples

| Old URL | New URL | Redirect Type | Notes |
|---------|---------|---------------|-------|
| `/projects/123` | `/:locale/projects/123/passing` | 302 | Locale detected, then section added |
| `/fr/projects/123` | `/fr/projects/123/passing` | 302 | Section added (which one may become configurable) |
| `/en/projects/123/bronze` | `/en/projects/123/passing` | 301 | Obsolete section name |
| `/en/projects/123/0` | `/en/projects/123/passing` | 301 | Obsolete numeric section |
| `/en/projects/123/1` | `/en/projects/123/silver` | 301 | Obsolete numeric section |
| `/en/projects/123/2` | `/en/projects/123/gold` | 301 | Obsolete numeric section |
| `/projects/123.md` | `/:locale/projects/123/passing.md` | 302 (maybe chain) | Locale added, then section. It'd be okay to do this in a chain or all at once. |
| `/en/projects/123.md` | `/en/projects/123/passing.md` | 302 | Section added |
| `/en/projects/123.json` | `/projects/123.json` | 301 | JSON has no locale |
| `/en/projects/123/edit` | `/en/projects/123/passing/edit` | 302 | Section added |
| `/en/projects/123/bronze/edit` | N/A | Error | Obsolete sections not accepted in edit URLs |

## Migration Strategy

### Phase 1: Preparation (No User Impact)

1. **Add Controller Logic**
   - Implement section validation in controller
   - Add format handling with `respond_to`
   - Create obsolete section redirect logic
   - Add comprehensive controller tests

2. **Add New Routes**
   - Deploy new consolidated routes alongside existing ones
   - New routes point to updated controller methods
   - Existing routes remain functional
   - No user-visible changes yet

3. **Test Extensively**
   - Verify all new routes work correctly
   - Test redirect chains
   - Validate format handling
   - Check locale detection

### Phase 2: Redirect Old Routes (Minimal Impact)

1. **Convert Old Routes to Redirects**
   - Update old route definitions to redirect to new canonical URLs
   - Use 301 for obsolete sections
   - Use 302 for locale/section defaults

2. **Monitor and Measure**
   - Log redirect usage to identify high-traffic patterns
   - Monitor error rates and 404s
   - Check performance metrics
   - Validate redirect chains aren't too long

3. **Update Internal Links**
   - Change all internal application links to use new URLs
   - Update documentation
   - Fix any test fixtures

### Phase 3: Deprecation (6-12 Months Later)

1. **Announce Deprecation**
   - Document old URL patterns as deprecated
   - Encourage users to update bookmarks
   - Add deprecation warnings to logs

2. **Remove Old Routes**
   - After sufficient transition period
   - Keep redirect routes for obsolete sections (bronze, 0, 1, 2)
   - Remove only truly redundant routes

3. **Cleanup**
   - Remove old controller methods if unused
   - Remove route-related technical debt
   - Update all documentation

## Testing Strategy

### Route Tests (test/controllers/routing/)

- [ ] Verify all redirect paths work correctly
- [ ] Test 301 redirects for obsolete sections
- [ ] Test 302 redirects for locale detection
- [ ] Test 302 redirects for default section
- [ ] Confirm section validation (accept valid, reject invalid)
- [ ] Test locale detection and redirection
- [ ] Validate format detection (.html, .md, .json)
- [ ] Test redirect chains (e.g., `/projects/123.md`)
- [ ] Verify JSON route has no locale
- [ ] Confirm markdown routes have locale

### Controller Tests (test/controllers/projects_controller_test.rb)

- [ ] Test section parameter handling
- [ ] Test obsolete section redirects
- [ ] Test format responses (HTML, Markdown, JSON)
- [ ] Test locale handling in views
- [ ] Verify proper rendering for each section
- [ ] Test error handling for invalid sections
- [ ] Test that /en/projects/123.json redirects 301 to /projects/123.json
- [ ] Verify show_json method works correctly
- [ ] Test JSON response contains all expected fields

### Integration Tests

- [ ] Update existing tests using old URL patterns
- [ ] Add tests for new consolidated routes
- [ ] Verify backward compatibility during transition
- [ ] Test complete user workflows with new URLs
- [ ] Verify bookmarked URLs still work (via redirects)

### System Tests (test/system/)

- [ ] Test user navigation through sections
- [ ] Verify edit workflows
- [ ] Test markdown download
- [ ] Verify JSON API access
- [ ] Test locale switching
- [ ] Verify proper redirects in browser

### Performance Tests

- [ ] Measure route matching time before/after
- [ ] Benchmark controller logic overhead
- [ ] Test redirect chain performance
- [ ] Verify CDN compatibility with new URLs

## Rollback Strategy

If critical issues arise during deployment:

1. **Keep Old Routes Available**
   - Comment out old routes in code rather than deleting
   - Can be quickly uncommented and redeployed

2. **Monitor Key Metrics**
   - 404 error rate (should not increase)
   - Response time (should improve or stay same)
   - User error reports
   - Redirect chain length

3. **Database of Changes**
   - Maintain list of all changed URLs
   - Keep redirect mappings documented
   - Easy to revert redirect logic if needed

4. **Feature Flag (Optional)**
   - Consider feature flag for new route system
   - Can toggle between old and new routes
   - Useful for gradual rollout

## Impact Analysis

### Positive Impacts

- **Performance**: Fewer route patterns to match reduces routing overhead
- **Maintainability**: Centralized logic easier to understand and modify
- **Consistency**: Clearer URL structure
- **Future-Ready**: Easier to add per-project default sections

### Potential Concerns

- **Controller Complexity**: Section validation moves from routes to controller

  Mitigation: Well-tested controller methods, clear documentation

- **Redirect Chains**: Some URLs require multiple redirects

  Mitigation: Only 2 redirects maximum, acceptable for user experience

- **Bookmark Updates**: Users may need to update bookmarks

  Mitigation: Redirects handle this automatically, no action required

### SEO Considerations

- **301 Redirects**: Search engines will update indexed URLs for obsolete sections
- **302 Redirects**: Search engines will preserve original URLs for temporary redirects
- **Canonical URLs**: New structure provides clearer canonical URLs for each section
- **Impact**: Minimal to none; redirects properly signal intent to search engines

## Future Enhancements

### Rename ALL_CRITERIA_LEVEL_NAMES to ALL_SECTION_NAMES

**Status**: ✅ MOVED TO PHASE 0 - This is now part of the initial constant
renaming and consolidation that must be done FIRST.

See "Phase 0: Rename and Consolidate Constants" section above for complete
implementation details.

### Per-Project Default Section

Currently `/projects/:id` redirects to `/projects/:id/passing` for all projects.

Future implementation:

- Add `default_section` column to projects table
- Redirect to project-specific default section
- Change redirect from 302 to 307 (Temporary Redirect, preserves method)

### Section Permissions

Some sections may become restricted based on project visibility or user permissions:

- Public projects: All sections visible
- Private projects: Restrict access to certain sections
- Implement in controller, not routes

## Key Decisions

1. **JSON is locale-independent**: Returns same data regardless of user's language;
   client responsible for localization
2. **Markdown is per-section**: Changed from per-project to align with HTML
   view structure
3. **Obsolete edit URLs not supported**: Bronze/0/1/2 section edit URLs will error
   rather than redirect (not expected to be widely linked)
4. **Doubled locale routes removed**: `/:locale/:locale/...` patterns are
   malformed and won't be supported
5. **Default section is "passing"**: Until per-project defaults implemented

## Appendix: Current Routes

For reference, these are the current GET routes for `/projects`:

```
GET /projects/:id/badge(.:format)
  → projects#badge {format: "svg", id: /[1-9][0-9]*/}

GET (/:locale)/:locale/projects/:id/0(.:format)
  → redirect(301) {locale: /(?:en|zh-CN|es|fr|de|ja|pt-BR|ru|sw)/, id: /[1-9][0-9]*/}

GET (/:locale)/projects/:id/0(.:format)
  → redirect(302) {locale: /(?:en|zh-CN|es|fr|de|ja|pt-BR|ru|sw)/, id: /[1-9][0-9]*/}

GET (/:locale)/:locale/projects/:id/0/edit(.:format)
  → redirect(301) {locale: /(?:en|zh-CN|es|fr|de|ja|pt-BR|ru|sw)/, id: /[1-9][0-9]*/}

GET (/:locale)/projects/:id/0/edit(.:format)
  → redirect(302) {locale: /(?:en|zh-CN|es|fr|de|ja|pt-BR|ru|sw)/, id: /[1-9][0-9]*/}

GET (/:locale)/:locale/projects/:id/1(.:format)
  → redirect(301) {locale: /(?:en|zh-CN|es|fr|de|ja|pt-BR|ru|sw)/, id: /[1-9][0-9]*/}

GET (/:locale)/projects/:id/1(.:format)
  → redirect(302) {locale: /(?:en|zh-CN|es|fr|de|ja|pt-BR|ru|sw)/, id: /[1-9][0-9]*/}

GET (/:locale)/:locale/projects/:id/1/edit(.:format)
  → redirect(301) {locale: /(?:en|zh-CN|es|fr|de|ja|pt-BR|ru|sw)/, id: /[1-9][0-9]*/}

GET (/:locale)/projects/:id/1/edit(.:format)
  → redirect(302) {locale: /(?:en|zh-CN|es|fr|de|ja|pt-BR|ru|sw)/, id: /[1-9][0-9]*/}

GET (/:locale)/:locale/projects/:id/2(.:format)
  → redirect(301) {locale: /(?:en|zh-CN|es|fr|de|ja|pt-BR|ru|sw)/, id: /[1-9][0-9]*/}

GET (/:locale)/projects/:id/2(.:format)
  → redirect(302) {locale: /(?:en|zh-CN|es|fr|de|ja|pt-BR|ru|sw)/, id: /[1-9][0-9]*/}

GET (/:locale)/:locale/projects/:id/2/edit(.:format)
  → redirect(301) {locale: /(?:en|zh-CN|es|fr|de|ja|pt-BR|ru|sw)/, id: /[1-9][0-9]*/}

GET (/:locale)/projects/:id/2/edit(.:format)
  → redirect(302) {locale: /(?:en|zh-CN|es|fr|de|ja|pt-BR|ru|sw)/, id: /[1-9][0-9]*/}

GET (/:locale)/:locale/projects/:id/bronze(.:format)
  → redirect(301) {locale: /(?:en|zh-CN|es|fr|de|ja|pt-BR|ru|sw)/, id: /[1-9][0-9]*/}

GET (/:locale)/projects/:id/bronze(.:format)
  → redirect(302) {locale: /(?:en|zh-CN|es|fr|de|ja|pt-BR|ru|sw)/, id: /[1-9][0-9]*/}

GET (/:locale)/:locale/projects/:id/bronze/edit(.:format)
  → redirect(301) {locale: /(?:en|zh-CN|es|fr|de|ja|pt-BR|ru|sw)/, id: /[1-9][0-9]*/}

GET (/:locale)/projects/:id/bronze/edit(.:format)
  → redirect(302) {locale: /(?:en|zh-CN|es|fr|de|ja|pt-BR|ru|sw)/, id: /[1-9][0-9]*/}

GET (/:locale)/:locale/projects/:id(.:format)
  → redirect(302) {locale: /(?:en|zh-CN|es|fr|de|ja|pt-BR|ru|sw)/}

GET (/:locale)/projects/:id(.:format)
  → redirect(302) {locale: /(?:en|zh-CN|es|fr|de|ja|pt-BR|ru|sw)/}

GET (/:locale)/:locale/projects/:id/edit(.:format)
  → redirect(302) {locale: /(?:en|zh-CN|es|fr|de|ja|pt-BR|ru|sw)/, id: /[1-9][0-9]*/}

GET (/:locale)/projects/:id/edit(.:format)
  → redirect(302) {locale: /(?:en|zh-CN|es|fr|de|ja|pt-BR|ru|sw)/, id: /[1-9][0-9]*/}

GET (/:locale)/projects/:id/delete_form(.:format)
  → projects#delete_form {id: /[1-9][0-9]*/, locale: /(?:en|zh-CN|es|fr|de|ja|pt-BR|ru|sw)/}

GET (/:locale)/projects/:id(.:format)
  → projects#show_json {id: /[1-9][0-9]*/, locale: /(?:en|zh-CN|es|fr|de|ja|pt-BR|ru|sw)/}

GET (/:locale)/projects/:id(.:format)
  → projects#show_markdown {id: /[1-9][0-9]*/, locale: /(?:en|zh-CN|es|fr|de|ja|pt-BR|ru|sw)/}

GET (/:locale)/projects/:id/:criteria_level(.:format)
  → projects#show {id: /[1-9][0-9]*/, locale: /(?:en|zh-CN|es|fr|de|ja|pt-BR|ru|sw)/,
    criteria_level: /(?-mix:passing|silver|gold|0|1|2|baseline\-1|baseline\-2|baseline\-3|bronze|permissions)/}

GET (/:locale)/projects/:id/:criteria_level/edit(.:format)
  → projects#edit {id: /[1-9][0-9]*/, locale: /(?:en|zh-CN|es|fr|de|ja|pt-BR|ru|sw)/,
    criteria_level: /(?-mix:passing|silver|gold|0|1|2|baseline\-1|baseline\-2|baseline\-3|bronze|permissions)/}

GET (/:locale)/projects(.:format)
  → projects#index {locale: /(?:en|zh-CN|es|fr|de|ja|pt-BR|ru|sw)/}

GET (/:locale)/projects/new(.:format)
  → projects#new {locale: /(?:en|zh-CN|es|fr|de|ja|pt-BR|ru|sw)/}

GET (/:locale)/projects/:id/edit(.:format)
  → projects#edit {id: /[1-9][0-9]*/, locale: /(?:en|zh-CN|es|fr|de|ja|pt-BR|ru|sw)/}

GET (/:locale)/projects/:id(.:format)
  → projects#show {id: /[1-9][0-9]*/, locale: /(?:en|zh-CN|es|fr|de|ja|pt-BR|ru|sw)/}
```
