# Plan: Moving GitHub Organization from coreinfrastructure to ossf

This document outlines the steps required to migrate the GitHub repository from the `coreinfrastructure` organization to the `ossf` organization. It was originally developed by Gemini.

## Objective

Implement a seamless transition for CI/CD pipelines, contributors, and users while the repository moves from `https://github.com/coreinfrastructure/best-practices-badge` to its new home at `https://github.com/ossf/best-practices-badge`.

**Note:**

* The production domain (`www.bestpractices.dev`) is **NOT** changing.
* The mailing list (`lists.coreinfrastructure.org`) is **NOT** changing.

---

## 1. Summary of Items to Change

### Category A: CI/CD & Pipeline Stability

* **`.circleci/config.yml`**: Update `working_directory` path.
* **External Badges**: Update URLs for CircleCI, Codecov, Snyk, and Scorecard to point to the new `ossf` namespace.

### Category B: Documentation (Links & References)

* **Primary Files**: `README.md`, `CONTRIBUTING.md`, `SECURITY.md`, `LICENSE.spdx`.
* **Bulk Docs**: All Markdown files in the `docs/` directory that reference the old repository path.

### Category C: Application Code

* **Helpers**: `app/helpers/application_helper.rb` (hardcoded GitHub links).
* **Models/Comments**: `app/models/project.rb` and `app/lib/github_basic_detective.rb`.
* **Scripts**: `install-badge-dev-env` (clone URL).

### Category D: Localization (UI Strings)

* **Locales**: `config/locales/*.yml` and `config/machine_translations/*.yml` (links to issues and the repo in the UI).

---

## 2. Priority & Implementation Order

### Phase 1: Preparation (Before the Move)

1. **Freeze PRs**: Briefly notify contributors of the move to minimize merge conflicts during the transition.
2. **Verify Access**: Ensure you have administrative access to the `ossf` organization.

### Phase 2: Immediate Infrastructure Updates (High Priority)

*Goal: Ensure the build green-lights and badges reflect the new location.*

1. **CircleCI Pathing**:

   ```bash
   sed -i 's|~/coreinfrastructure/best-practices-badge|~/ossf/best-practices-badge|g' .circleci/config.yml
   ```

2. **README Badges**:

   ```bash
   # CircleCI
   sed -i 's|circleci.com/gh/coreinfrastructure/best-practices-badge|circleci.com/gh/ossf/best-practices-badge|g' README.md
   # Codecov
   sed -i 's|codecov.io/gh/coreinfrastructure/best-practices-badge|codecov.io/gh/ossf/best-practices-badge|g' README.md
   # Scorecard
   sed -i 's|api.scorecard.dev/projects/github.com/coreinfrastructure/best-practices-badge|api.scorecard.dev/projects/github.com/ossf/best-practices-badge|g' README.md
   sed -i 's|scorecard.dev/viewer/?uri=github.com/coreinfrastructure/best-practices-badge|scorecard.dev/viewer/?uri=github.com/ossf/best-practices-badge|g' README.md
   ```

3. **LICENSE.spdx**:

   ```bash
   sed -i 's|https://github.com/coreinfrastructure/best-practices-badge|https://github.com/ossf/best-practices-badge|g' LICENSE.spdx
   ```

### Phase 3: Contributor & User Experience (High Priority)

*Goal: Ensure users can find the new home and report issues correctly.*

1. **Update CONTRIBUTING.md**:

   ```bash
   sed -i 's|coreinfrastructure/best-practices-badge|ossf/best-practices-badge|g' CONTRIBUTING.md
   ```

2. **Update SECURITY.md**:

   ```bash
   sed -i 's|coreinfrastructure/best-practices-badge|ossf/best-practices-badge|g' SECURITY.md
   ```

3. **Update README.md Main Links**:

   ```bash
   sed -i 's|coreinfrastructure/best-practices-badge|ossf/best-practices-badge|g' README.md
   ```

### Phase 4: Application & Scripts (Medium Priority)

1. **Update Helpers**:

   ```bash
   sed -i 's|coreinfrastructure/best-practices-badge|ossf/best-practices-badge|g' app/helpers/application_helper.rb
   ```

2. **Update Scripts**:

   ```bash
   sed -i 's|github.com/coreinfrastructure/best-practices-badge|github.com/ossf/best-practices-badge|g' install-badge-dev-env
   ```

3. **OpenAPI Spec**:

   ```bash
   sed -i 's|coreinfrastructure/best-practices-badge|ossf/best-practices-badge|g' best_practices.openapi.yaml
   ```

### Phase 5: Comprehensive Doc/UI Cleanup (Standard Priority)

1. **Bulk Update Documentation**:

   ```bash
   find docs/ -name "*.md" -exec sed -i 's|coreinfrastructure/best-practices-badge|ossf/best-practices-badge|g' {} +
   ```

2. **Update Localization Files**:

   ```bash
   find config/locales/ config/machine_translations/ -name "*.yml" -exec sed -i 's|coreinfrastructure/best-practices-badge|ossf/best-practices-badge|g' {} +
   ```

3. **Update Miscellaneous Metadata**:

   ```bash
   sed -i 's|coreinfrastructure/best-practices-badge|ossf/best-practices-badge|g' AGENTS.md
   ```

---

## 3. Specific File Changes (Technical Details)

| File | Search Pattern | Replacement |
| :--- | :--- | :--- |
| `.circleci/config.yml` | `~/coreinfrastructure/` | `~/ossf/` |
| Multiple | `github.com/coreinfrastructure/` | `github.com/ossf/` |
| Multiple | `circleci.com/gh/coreinfrastructure/` | `circleci.com/gh/ossf/` |
| Multiple | `codecov.io/gh/coreinfrastructure/` | `codecov.io/gh/ossf/` |
| `app/mailers/report_mailer.rb` | *(None)* | *Do not change (List remains the same)* |

---

## 4. Verification Steps

1. **CircleCI**: Verify that the build triggers and succeeds after the directory path change.
2. **Links**: Run a broken link checker (e.g., `awesome_bot`) on `README.md` and `CONTRIBUTING.md`.

   ```bash
   # Suggested check command:
   bundle exec rake links:check # (If applicable in project)
   ```

3. **Clone**: Run `./install-badge-dev-env` in a clean environment to verify it correctly clones from the new OSSF URL.
4. **UI Verification**: Visit a local development instance and verify that "GitHub" and "Issue" links in the footer and help sections point to the OSSF organization.

   ```bash
   grep -r "ossf/best-practices-badge" config/locales/ | head -n 5
   ```
