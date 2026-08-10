# Baseline Criteria Automation

This document describes how baseline criteria are (or could be) automatically
filled using the Detective pattern, and maps baseline criteria to metal series
automation where possible.

## Overview

The BadgeApp uses a "Chief and Detective" pattern for automated criterion
checking. The `Chief` class orchestrates multiple `Detective` classes, each
analyzing specific aspects of a project. Detectives return changesets with
confidence levels (1-5), and the Chief applies changes based on confidence
thresholds and existing data.

## Existing Detective Infrastructure

### Detectives and Their Outputs

1. **GithubBasicDetective** - Queries GitHub API for repository metadata
   - Outputs: `name`, `license`, `discussion_status`, `repo_public_status`,
     `repo_track_status`, `repo_distributed_status`, `contribution_status`,
     `implementation_languages`

2. **RepoFilesExamineDetective** - Examines repository file structure
   - Outputs: `contribution_status`, `license_location_status`,
     `release_notes_status`

3. **FlossLicenseDetective** - Validates OSI-approved licenses
   - Outputs: `floss_license_osi_status`, `floss_license_status`

4. **BuildDetective** - Detects build tools and processes
   - Outputs: `build_status`, `build_common_tools_status`

5. **ProjectSitesHttpsDetective** - Checks HTTPS support for project URLs
   - Outputs: `sites_https_status`

6. **HardenedSitesDetective** - Validates security headers on project sites
   - Outputs: `hardened_site_status`

7. **SubdirFileContentsDetective** - Examines documentation in subdirectories
   - Outputs: `documentation_basics_status`

## Baseline Criteria Automation Mapping

### Category 1: Direct Automation (High Confidence)

These baseline criteria can be directly automated using existing detective
logic with high confidence.

#### osps_br_03_01: Project URIs Use Encrypted Channels

- **Description**: Project URI must be exclusively delivered using encrypted
  channels
- **Metal equivalent**: `sites_https_status`
- **Detective**: `ProjectSitesHttpsDetective` (already implemented)
- **Automation approach**: Check that `repo_url` and `homepage_url` use HTTPS
- **Confidence level**: 4-5 (can definitively check HTTPS support)
- **Implementation**: Create `BaselineHttpsDetective` that reuses existing
  HTTPS checking logic

#### osps_br_03_02: Distribution URIs Use Encrypted Channels

- **Description**: Distribution channel URI must use encrypted channels
- **Metal equivalent**: `sites_https_status`
- **Detective**: `ProjectSitesHttpsDetective` (already implemented)
- **Automation approach**: Check distribution URLs for HTTPS
- **Confidence level**: 4-5
- **Implementation**: Extend `BaselineHttpsDetective` to check distribution
  channels

#### osps_br_07_01: Version Control System Usage

- **Description**: Project must use a version control system
- **Metal equivalent**: `repo_public_status`, `repo_track_status`
- **Detective**: `GithubBasicDetective` (already implemented)
- **Automation approach**: If `repo_url` is present and valid, version control
  is in use
- **Confidence level**: 5 (definitive if repo URL exists)
- **Implementation**: Map existing `repo_public_status` result to baseline
  field

### Category 2: Partial Automation (Medium Confidence)

These criteria can be partially automated but may require additional validation
or have lower confidence.

#### osps_do_02_01: Contribution Instructions

- **Description**: Project must document how to contribute
- **Metal equivalent**: `contribution_status`
- **Detective**: `GithubBasicDetective`, `RepoFilesExamineDetective`
- **Automation approach**: Check for CONTRIBUTING file in repository
- **Confidence level**: 3-4 (file presence is strong signal but content
  matters)
- **Implementation**: Reuse existing contribution file detection

#### osps_do_01_01: README Documentation

- **Description**: Project must have README documentation
- **Metal equivalent**: `documentation_basics_status`
- **Detective**: `SubdirFileContentsDetective`
- **Automation approach**: Check for README file with minimum content
- **Confidence level**: 4 (presence of substantial README is definitive)
- **Implementation**: Extend documentation detective for baseline fields

#### osps_le_02_01, osps_le_02_02: License Declaration

- **Description**: Project must declare a license
- **Metal equivalent**: `license`, `license_location_status`
- **Detective**: `GithubBasicDetective`, `RepoFilesExamineDetective`
- **Automation approach**: Check for license file and valid SPDX identifier
- **Confidence level**: 4 (GitHub API provides reliable license data)
- **Implementation**: Create `BaselineLicenseDetective` using existing logic

#### osps_le_03_01, osps_le_03_02: OSI-Approved License

- **Description**: License must be OSI-approved
- **Metal equivalent**: `floss_license_osi_status`
- **Detective**: `FlossLicenseDetective` (already implemented)
- **Automation approach**: Validate license against OSI-approved list
- **Confidence level**: 5 (definitive for known licenses)
- **Implementation**: Reuse `FlossLicenseDetective` logic for baseline fields

#### osps_gv_02_01, osps_gv_03_01: Vulnerability Disclosure

- **Description**: Project must have vulnerability disclosure process
- **Metal equivalent**: Partial overlap with `discussion_status`
- **Detective**: New `BaselineSecurityDetective` needed
- **Automation approach**: Check for SECURITY.md file via GitHub API
- **Confidence level**: 3-4 (presence of file is good signal, content matters)
- **Implementation**: Create new detective to check for security policy file

### Category 3: Manual Only (No Automation)

These criteria require human judgment or access to information not available
via APIs. They cannot be reliably automated.

#### Multi-Factor Authentication (osps_ac_01_01)

- **Description**: Require MFA for sensitive repository access
- **Why manual**: GitHub API doesn't expose MFA enforcement status for
  organization members
- **Possible future**: If GitHub adds API support, could be automated

#### Permission Assignment (osps_ac_02_01)

- **Description**: New collaborators must have restricted default permissions
- **Why manual**: Requires checking organization/repository settings not
  exposed via API
- **Possible future**: May be possible with GitHub Apps API

#### Branch Protection (osps_ac_03_01, osps_ac_03_02)

- **Description**: Primary branch must be protected from direct commits and
  deletion
- **Why manual**: While GitHub API can check branch protection, the specific
  rules and their configuration require careful validation that's better done
  manually
- **Note**: Could be automated in future with careful API integration

#### CI/CD Pipeline Security (osps_br_01_01, osps_br_01_02)

- **Description**: CI/CD inputs must be sanitized and validated
- **Why manual**: Requires examining pipeline code and configuration, which
  varies by CI/CD system
- **Note**: Cannot be reliably automated without AI code analysis

#### Governance and Review Criteria (osps_gv_*)

- **Description**: Various governance requirements about maintainers, review
  processes, etc.
- **Why manual**: Requires human judgment about organizational structure and
  processes
- **Note**: Some aspects (like PR review requirements) could be partially
  automated

#### Quality Assurance Criteria (osps_qa_*)

- **Description**: Testing, code review, and quality processes
- **Why manual**: While presence of tests can be detected, quality and coverage
  require human assessment
- **Note**: Some aspects (test file presence) could be weakly automated

#### Vulnerability Management (osps_vm_02_01)

- **Description**: Documented process for fixing vulnerabilities
- **Why manual**: Requires human judgment of the process quality
- **Note**: Presence of SECURITY.md is a signal but doesn't guarantee process
  quality

## Implementation Strategy

### Phase 1: Simple Mappings (Immediate)

Create a `BaselineDetective` that maps existing detective outputs to baseline
fields with high confidence:

- HTTPS checks → `osps_br_03_01_status`, `osps_br_03_02_status`
- Repo presence → `osps_br_07_01_status`
- README presence → `osps_do_01_01_status`
- Contributing file → `osps_do_02_01_status`
- License detection → `osps_le_02_01_status`, `osps_le_02_02_status`
- OSI license validation → `osps_le_03_01_status`, `osps_le_03_02_status`

### Phase 2: New Detectives (Near-term)

Create new detectives for baseline-specific checks:

- `BaselineSecurityDetective`: Check for SECURITY.md file
  → `osps_gv_02_01_status`

### Phase 3: Conservative Enhancement (Future)

Carefully add automation for additional criteria as API capabilities expand:

- Branch protection checks (if reliable API methods exist)
- Test presence indicators (weak signals only)

## Design Principles

1. **Conservative Confidence**: Only mark criteria as "Met" with high
   confidence (level 4-5)
2. **Manual Override**: Users can always override automated results
3. **No False Positives**: Better to leave as "?" than incorrectly mark as
   "Met"
4. **Clear Justifications**: Automated justifications explain what was detected
5. **Reuse Existing Logic**: Leverage proven detective implementations

## Technical Implementation

### Baseline Detective Structure

```ruby
class BaselineDetective < Detective
  INPUTS = %i[repo_url homepage_url license contribution_status].freeze
  OUTPUTS = %i[
    osps_br_03_01_status osps_br_03_02_status osps_br_07_01_status
    osps_do_02_01_status osps_le_02_01_status osps_le_03_01_status
  ].freeze

  def analyze(evidence, current)
    result = {}

    # Map HTTPS status
    if https_check_passes?(current)
      result[:osps_br_03_01_status] = {
        value: 'Met',
        confidence: 4,
        explanation: 'Project URLs use HTTPS.'
      }
    end

    # More mappings...
    result
  end
end
```

### Integration with Chief

The `Chief` class already handles detective orchestration. Baseline detectives
are added to `ALL_DETECTIVES` list and run automatically during autofill.

## Testing Strategy

1. **Unit tests**: Test each detective's analyze method with various inputs
2. **Integration tests**: Verify Chief correctly applies baseline changes
3. **Negative tests**: Ensure no false positives
4. **Manual override tests**: Confirm users can override automated results

## Future Enhancements

- **API Expansion**: As GitHub and other platforms expose more data, expand
  automation
- **ML-based Detection**: Use AI to detect patterns in documentation quality
- **Multi-platform**: Extend beyond GitHub to GitLab, Bitbucket, etc.
- **Confidence Scoring**: Refine confidence levels based on real-world accuracy

## Summary

Approximately 8-10 of the 62 baseline criteria can be automated with reasonable
confidence. The remaining criteria require human judgment or access to
non-public data. This document provides a roadmap for implementing available
automation while maintaining high quality standards.
