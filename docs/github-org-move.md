# Plan: Moving GitHub Organization from coreinfrastructure to ossf

This document outlines the steps required to migrate the GitHub repository from the `coreinfrastructure` organization to the `ossf` organization.

## Objective

Ensure a seamless transition for CI/CD pipelines, contributors, and users while the repository moves to its new home at `https://github.com/ossf/best-practices-badge`.

**Note:**

* The production domain (`www.bestpractices.dev`) is **NOT** changing.
* The mailing list (`lists.coreinfrastructure.org`) is **NOT** changing.

---

## 1. Summary of Items to Change

### Category A: CI/CD & Pipeline Stability

* **`.circleci/config.yml`**: Update `working_directory` path.
* **External Badges**: Update URLs for CircleCI, Codecov, Snyk, and Scorecard.

### Category B: Documentation (Links & References)

* **Primary Files**: `README.md`, `CONTRIBUTING.md`, `SECURITY.md`, `LICENSE.spdx`, `AGENTS.md`.
* **Bulk Docs**: All Markdown files in the `docs/` directory.

### Category C: Application Code

* **Helpers**: `app/helpers/application_helper.rb`.
* **Scripts**: `install-badge-dev-env`.
* **API Specs**: `best_practices.openapi.yaml`.

### Category D: Localization (UI Strings)

* **Locales**: `config/locales/*.yml` and `config/machine_translations/*.yml`.

---

## 2. Priority & Implementation Order

### Phase 1: Preparation (Before the Move)

1. **Freeze PRs**: Briefly notify contributors of the move.
2. **Verify Access**: Ensure you have administrative access to the `ossf` organization.

### Phase 2: Primary Bulk Update (High Priority)

*Goal: Update all primary configuration, documentation, and application files in one step. This command specifically targets the repository path to avoid accidentally changing the mailing list or website domains.*

Run this command to handle CI/CD pathing, primary documentation links, and application helpers:

```bash
sed -i 's|coreinfrastructure/best-practices-badge|ossf/best-practices-badge|g' \
  .circleci/config.yml \
  README.md \
  CONTRIBUTING.md \
  SECURITY.md \
  LICENSE.spdx \
  AGENTS.md \
  app/helpers/application_helper.rb \
  install-badge-dev-env \
  best_practices.openapi.yaml
```

### Phase 3: Recursive Cleanup (Standard Priority)

*Goal: Thoroughly update all documentation and localization files.*

1. **Documentation Directory**:

   ```bash
   find docs/ -name "*.md" ! -name "github-org-move.md" \
     -exec sed -i 's|coreinfrastructure/best-practices-badge|ossf/best-practices-badge|g' {} +
   ```

2. **Localization & UI Strings**:

   ```bash
   find config/locales/ config/machine_translations/ -name "*.yml" -exec sed -i 's|coreinfrastructure/best-practices-badge|ossf/best-practices-badge|g' {} +
   ```

---

## 3. Translation Synchronization Strategy

To ensure that future translation synchronizations do not revert these changes (if translators have not yet updated the strings on translation.io), the following code tweak is recommended for `lib/tasks/default.rake`.

The `normalize_string` method should be updated to forcibly substitute the organization name in all retrieved strings.

**Proposed change in `lib/tasks/default.rake`:**

```ruby
def normalize_string(value, locale)
  # Remove trailing whitespace
  value = value.sub(/\s+$/, '')
  # Forcibly substitute GitHub organization with literal string match
  value = value.gsub('github.com/coreinfrastructure/best-practices-badge',
                     'github.com/ossf/best-practices-badge')

  return value if value.exclude?('<')
  # ... (rest of the existing HTML normalization logic)
end
```

This ensures that whenever `rake translation:sync` is run, the local files are immediately patched with the correct repository URLs across all languages.

---

## 4. Specific File Changes (Technical Details)

The following patterns are all addressed by the `sed` commands in Phase 2 and 3:

| Detail | Source | Target | Command |
| :--- | :--- | :--- | :--- |
| **CI Working Dir** | `~/coreinfrastructure/best-practices-badge` | `~/ossf/best-practices-badge` | Phase 2 `sed` |
| **GitHub Repo** | `github.com/coreinfrastructure/best-practices-badge` | `github.com/ossf/best-practices-badge` | Phase 2 `sed` |
| **CircleCI UI** | `circleci.com/gh/coreinfrastructure/best-practices-badge` | `circleci.com/gh/ossf/best-practices-badge` | Phase 2 `sed` |
| **Codecov API** | `codecov.io/gh/coreinfrastructure/best-practices-badge` | `codecov.io/gh/ossf/best-practices-badge` | Phase 2 `sed` |
| **Localization** | `config/locales/*.yml` | (Update all org refs) | Phase 3 `find/sed` |

---

## 4. Verification Steps

1. **CircleCI**: Verify that the build triggers and succeeds after the directory path change.
2. **Links**: Run a broken link checker on `README.md` and `CONTRIBUTING.md`.
3. **Clone**: Run `./install-badge-dev-env` in a clean environment.
4. **UI Verification**:

   ```bash
   # Check a sample localization file for the update
   grep "ossf/best-practices-badge" config/locales/en.yml | head -n 5
   ```
