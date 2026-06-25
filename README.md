# OpenSSF Best Practices Badge (formerly CII Best Practices Badge)

<!-- SPDX-License-Identifier: (MIT OR CC-BY-3.0+) -->

<table border="0">
  <tr>
    <td align="left" border="0" valign="middle">
      <a href="https://bestpractices.coreinfrastructure.org/projects/1"><img src="https://bestpractices.coreinfrastructure.org/projects/1/badge" alt="OpenSSF Best Practices" align="middle"></a>&nbsp;
      <a href="https://www.bestpractices.dev/projects/1"><img src="https://www.bestpractices.dev/projects/1/baseline" alt="OpenSSF Baseline" align="middle"></a>&nbsp;
      <a href="https://app.circleci.com/pipelines/github/ossf/best-practices-badge"><img src="https://circleci.com/gh/ossf/best-practices-badge.svg?&style=shield" alt="CircleCI Build Status" align="middle"></a>&nbsp;
      <a href="https://codecov.io/gh/ossf/best-practices-badge"><img src="https://codecov.io/gh/ossf/best-practices-badge/branch/master/graph/badge.svg" alt="codecov" align="middle"></a>&nbsp;
      <a href="https://badges.mit-license.org"><img src="https://img.shields.io/:license-mit-blue.svg" alt="License" align="middle"></a>&nbsp;
      <a href="https://scorecard.dev/viewer/?uri=github.com/ossf/best-practices-badge"><img src="https://api.scorecard.dev/projects/github.com/ossf/best-practices-badge/badge" alt="OpenSSF Scorecard" align="middle"></a>
    </td>
    <td align="left" border="0" valign="middle">
      <a href="https://github.com/ossf/tac/blob/main/process/project-lifecycle-documents/best_practices_badge_graduation_stage.md">
        <img src="https://raw.githubusercontent.com/ossf/best-practices-badge/main/docs/graduated.svg" alt="OpenSSF graduated project" height="80">
      </a>
    </td>
  </tr>
</table>

This project identifies best practices for
Free/Libre and Open Source Software (FLOSS)
and implements a badging system for those best practices.
The "BadgeApp" badging system is a simple web application
that lets projects self-certify that they meet the criteria
and show a badge.
The real goal of this project is to encourage projects to
apply best practices, and to help users determine which FLOSS projects do so.
We believe that FLOSS projects that implement best practices are more likely
to produce better software, including more secure software.
We support both our original "metal" badge criteria and the
OpenSSF Baseline criteria.

See the
*[OpenSSF Best Practices badge website](https://bestpractices.coreinfrastructure.org/)* if you want to try to actually get a badge.

This is the development site for the criteria and badge application
software that runs the website.
Feedback is very welcome via the
[GitHub site](https://github.com/ossf/best-practices-badge)
as issues or pull (merge) requests.
There is also a
[mailing list](https://lists.coreinfrastructure.org/mailman/listinfo/cii-badges)
for general discussion.
This project was originally developed under the CII, but it
is now part of the
[Open Source Security Foundation (OpenSSF)](https://openssf.org/)
[Best Practices Working Group (WG)](https://github.com/ossf/wg-best-practices-os-developers).
Its formal name is the OpenSSF Best Practices badge project, formerly named
the CII Best Practices badge.

## Interesting pages

Interesting pages include:

* Badging **[Criteria for the passing level](https://bestpractices.coreinfrastructure.org/criteria/0)**
* **[Criteria for all badging levels](https://bestpractices.coreinfrastructure.org/criteria)**
* Information on how to **[contribute](./CONTRIBUTING.md)**
* Information on **[our own security, including how to report vulnerabilities in our badge application](./SECURITY.md)**
* [Up-for-grabs](https://github.com/ossf/best-practices-badge/labels/up-for-grabs)
  lists smaller tasks that may take 1-3 days, and are ideal for people
  new to the project (or FLOSS in general)
* **[Background](./docs/background.md)** on Badging
* **[ChangeLog](./CHANGELOG.md)**
* **[Requirements](./docs/requirements.md)** - our overall requirements
* **[Design](./docs/design.md)** - our basic design
* Current **[implementation](./docs/implementation.md)**  - notes about the
  BadgeApp implementation
* **[security](./docs/assurance-case.md)**  - notes about BadgeApp security, specifically its assurance case
* **[testing](./docs/testing.md)**  - notes about BadgeApp automated tests
* **[api](./docs/api.md)** - Application Programming Interface (API), including data downloads
* **[Installation](./docs/INSTALL.md)**  - Installation and quick start
* **[Vetting](./docs/vetting.md)**  - More about our vetting approach
* **[Roadmap](./docs/roadmap.md)**  - Roadmap (future plans)
* **[Automation proposals](./docs/automation-proposals.md)** - a mechanism for external tools to easily propose changes (this is our recommended integration mechanism)

## Baseline and Metal series

The best practices badge site supports both the
[OpenSSF Baseline](https://baseline.openssf.org/) criteria
(baseline-1,2,3) and its own "Metal series" of criteria
(passing, silver, gold).

The baseline series is a more minimal checklist focusing only on MUST
security requirements and is derived in part from global cybersecurity
regulations and frameworks. The metal series is a larger set of criteria that
includes suggestions and quality issues that impact security, and is derived
in part from experiences of secure FLOSS projects. Both focus on security.

We encourage projects to eventually do both. You choose where to start.
Once you do one series, it's much easier to do the other.

## Summary of Best Practices Criteria "passing" level

This is a summary of the passing criteria, with requirements in bold:

* **Have a [stable website](docs/criteria.md#homepage_url)**, which says:
  - **[what it does](docs/criteria.md#description_good)**
  - **[how to get it](docs/criteria.md#interact)**
  - **[how to give feedback](docs/criteria.md#interact)**
  - **[how to contribute](docs/criteria.md#contribution)** and
    [preferred styles](docs/criteria.md#contribution_requirements)
* **[Explicitly specify](docs/criteria.md#license_location) a
  [FLOSS](docs/criteria.md#floss_license) [license](docs/criteria.md#floss_license_osi)**
* **[Support HTTPS on the project sites](docs/criteria.md#sites_https)**
* **[Document how to install and run (securely)](docs/criteria.md#documentation_basics),
  and [any API](docs/criteria.md#documentation_interface)**
* **Have a** [distributed](docs/criteria.md#repo_distributed)
  **[public version control system](docs/criteria.md#repo_public),
 including [changes between releases](docs/criteria.md#repo_interim)**:
  - **[Give each release a unique version](docs/criteria.md#version_unique)**, using
    [semantic versioning format](docs/criteria.md#version_semver)
  - **Give a [summary of changes for each release](docs/criteria.md#release_notes),
    [identifying any fixed vulnerabilities](docs/criteria.md#release_notes_vulns)**
* **Allow [bug reports to be submitted](docs/criteria.md#report_process),
  [archived](docs/criteria.md#report_archive)** and
  [tracked](docs/criteria.md#report_tracker):
  - **[Acknowledge](docs/criteria.md#report_responses)**/respond to bugs &
    [enhancement requests](docs/criteria.md#enhancement_responses), rather than
    ignoring them
  - **Have a [secure](docs/criteria.md#vulnerability_report_private),
    [documented process](docs/criteria.md#vulnerability_report_process) for
    reporting vulnerabilities**
  - **[Respond within 14 days](docs/criteria.md#vulnerability_report_response),
    and [fix vulnerabilities](docs/criteria.md#vulnerabilities_critical_fixed),
    [within 60 days if they're public](docs/criteria.md#vulnerabilities_fixed_60_days)**
* **[Have a build that works](docs/criteria.md#build)**, using
  [standard](docs/criteria.md#build_common_tools)
  [open-source](docs/criteria.md#build_floss_tools) tools
  - **Enable (and [fix](docs/criteria.md#warnings_fixed))
    [compiler warnings and lint-like checks](docs/criteria.md#warnings)**
  - **[Run other static analysis tools](docs/criteria.md#static_analysis) and
    [fix exploitable problems](docs/criteria.md#static_analysis_fixed)**
* **[Have an automated test suite](docs/criteria.md#test)** that
  [covers most of the code/functionality](docs/criteria.md#test_most), and
  [officially](docs/criteria.md#tests_documented_added)
  **[require new tests for new code](docs/criteria.md#test_policy)**
* [Automate running the tests on all changes](docs/criteria.md#test_continuous_integration),
  and apply dynamic checks:
  - [Run memory/behaviour analysis tools](docs/criteria.md#dynamic_analysis)
    ([sanitizers/Valgrind](docs/criteria.md#dynamic_analysis_unsafe) etc.)
  - [Run a fuzzer or web-scanner over the code](docs/criteria.md#dynamic_analysis)
* **[Have a developer who understands secure software](docs/criteria.md#know_secure_design)
  and [common vulnerability errors](docs/criteria.md#know_common_errors)**
* If cryptography is used:
  - **[Use public protocols/algorithm](docs/criteria.md#crypto_published)**
  - **[Don't re-implement standard functionality](docs/criteria.md#crypto_call)**
  - **[Use open-source cryptography](docs/criteria.md#crypto_floss)**
  - **[Use key lengths that will stay secure](docs/criteria.md#crypto_keylength)**
  - **[Don't use known-broken](docs/criteria.md#crypto_working)** or
    [known-weak](docs/criteria.md#crypto_weaknesses) algorithms
  - [Use algorithms with forward secrecy](docs/criteria.md#crypto_pfs)
  - **[Store any passwords with iterated, salted, hashes using a key-stretching algorithm](docs/criteria.md#crypto_password_storage)**
  - **[Use cryptographic random number sources](docs/criteria.md#crypto_random)**

## Summary of Best Practices Criteria for higher levels

Getting a passing badge is a significant achievement;
on average only about 10% of pursuing projects have a passing badge.
That said, some projects would like to meet even stronger criteria,
and many users would like projects to do so.
We have established two higher levels beyond passing: silver and gold.
The higher levels strengthen some of the passing criteria and add new
criteria of their own.

### Silver

Here is a summary of the silver criteria, with requirements in bold
(for details, see the [full list of silver criteria](docs/other.md)):

* **[Use a DCO or similar](docs/other.md#dco)**
* **[Define/document project governance](docs/other.md#governance)**
* **[Another will have the necessary access rights if someone dies](docs/other.md#access_continuity)**
* *["Bus factor" of 2 or more](docs/other.md#bus_factor)*
* **[Document security requirements](docs/other.md#documentation_security)**
* **[Have an assurance case explaining why security requirements are met](docs/other.md#assurance_case)**
* **[Have a quick start guide](docs/other.md#documentation_quick_start)**
* *[Follow accessibility best practices](docs/other.md#accessibility_best_practices)*
* **[Pick & follow coding standards](docs/other.md#coding_standards)**
* **[Monitor external dependencies to detect/fix known vulnerabilities](docs/other.md#dependency_monitoring)**
* **[Tests have 80%+ statement coverage](docs/other.md#test_statement_coverage80)**
* **[Project releases for widespread use are cryptographically signed](docs/other.md#signed_releases)**
* **[Check all inputs from potentially untrusted sources for validity (using an allowlist)](docs/other.md#input_validation)**
* *[Use hardening mechanisms](docs/other.md#hardening)*

### Gold

Here is a summary of the gold criteria, with requirements in bold
(for details, see the [full list of gold criteria](docs/other.md)):

* **[At least 2 unassociated significant contributors](docs/other.md#contributors_unassociated)**
* **[Per-file copyright and license](docs/other.md#copyright_per_file)**
* **[Use 2FA](docs/other.md#require_2FA)**
* **[At least 50% of all modifications are reviewed by another](docs/other.md#two_person_review)**
* **[Have a reproducible build](docs/other.md#reproducible_build)**
* **[Use continuous integration](docs/other.md#test_continuous_integration)**
* **[Statement coverage 90%+](docs/other.md#test_statement_coverage90)**
* **[Branch coverage 80%+](docs/other.md#test_branch_coverage80)**
* **[Support secure protocols & disable insecure protocols by default](docs/other.md#crypto_used_network)**
* **[Use TLS version 1.2 or higher](docs/other.md#crypto_tls12)**
* **[Have a hardened project website, repo, and download site](docs/other.md#hardened_site)**
* **[Have a security review (internal or external)](docs/other.md#security_review)**

## Directory "doc" is now "docs"

If you've used this system in the past, you may have referred to our `doc`
subdirectory for documentation. We have renamed that to a `docs` subdirectory.

## Main site

Years ago we moved our main site to
<https://www.bestpractices.dev>.

For many years the main site previously was at
<https://bestpractices.coreinfrastructure.org>.
However, the Core Infrastructure Initiative (CII) ended and we
became part of the Open Source Security Foundation (OpenSSF).
We use the "www" subdomain because there are technical challenges using
a top-level domain with our CDN; it's more efficient to use the subdomain.

## Governance and administration

See [governance](docs/governance.md) for how this project is governed,
[TSC](docs/TSC.md) for current best practices badge
project technical steering committee (TSC) members, and
[admin](docs/admin.md) for information to web site application administrators.

## Software Bill of Materials (SBOM)

We generate an Software Bill of Materials (SBOM) in SPDX format.
[Here is more information how to get our SPDX SBOMs](docs/sbom.md).

## License

All material in this repository is released under the [MIT license](./LICENSE).
All material in this repository that is not executable,
including all text when not executed,
is also released under the
[Creative Commons Attribution 3.0 International (CC BY 3.0) license](https://creativecommons.org/licenses/by/3.0/) or later.
In SPDX terms, everything here is licensed under MIT;
if it's not executable, including the text when extracted from code, it's
"(MIT OR CC-BY-3.0+)".

Like almost all software today, this software depends on many
other components with their own licenses.
Not all components we depend on are MIT-licensed, but all
*required* components are FLOSS. We prevent licensing issues
using various processes (see [CONTRIBUTING](./CONTRIBUTING.md)).

The data *managed* by this software is under different highly-permissive
[open data](https://opendefinition.org/od/2.1/en/) licenses,
depending on when the data was last updated:

* Data updated on or after 2024-08-23T12:00:00Z is released under the
  [Community Data License Agreement – Permissive, Version 2.0 (CDLA-Permissive-2.0)](https://cdla.dev/permissive-2-0/).
  This means that a Data Recipient
  may share the Data, with or without modifications, so long as the
  Data Recipient makes available the text of this agreement with
  the shared Data.
  This agreement does *not* impose any restriction or obligations
  with respect to the use, modification, or sharing of Results.
* Otherwise, data updated on or after 2017-02-20T12:00:00Z is released under the
  [Creative Commons Attribution 3.0 International (CC BY 3.0) license or later (CC-BY-3.0+)](https://creativecommons.org/licenses/by/3.0/).
* Otherwise, data is released under the
  [Creative Commons Attribution 3.0 International (CC BY 3.0) license (CC-BY-3.0)](https://creativecommons.org/licenses/by/3.0/).

The *complete* collection of data *managed* by this application is thus
licensed with the SPDX license expression "(CC-BY-3.0 AND CDLA-Permissive-2.0)".
Only a few old entries are under the CC-BY-3.0, so if you omitted those
oldest data values, the dataset is released under the expression
"(CC-BY-3.0+ AND CDLA-Permissive-2.0)".

Submitters of data retain copyright (if any), and
the project license is unaffected.
