# Baseline plan

This document explains what the OpenSSF Baseline is, and how the
OpenSSF Best Practices badge project plans to add support for it
(without losing support for its existing set of criteria).

## What is baseline?

The [OpenSSF Open Source Project Security Baseline (OSPS Baseline)](https://baseline.openssf.org/), aka "baseline", is a set of requirements
maintained by the OpenSSF Security Baseline SIG for improving security.
Both the baseline criteria and the original "metal series"
are intended to help open source software projects improve their security
and both have 3 levels of criteria.

The baseline criteria are different from the original "metal series" of
criteria currently supported by the OpenSSF Best Practices badge as follows:

* The "baseline" criteria focus on only having MUST criteria
  (no SHOULD or SUGGESTED criteria), are primarily derived from
  regulations and standards, and focus on being a shorter list
  (e.g., baseline-1 has 20 criteria for baseline-1 while passing has 67).
* The original "metal series" of criteria in the Best Practices badge
  (passing, silver, gold) include criteria that are widely but not universally
  applicable (SHOULD and SUGGESTED), are primarily derived from
  successful secure OSS projects, and are willing to accept more criteria
  (including those for quality as long as they also aid security).

To see the current baseline criteria, view the beginning of this document: <https://baseline.openssf.org/versions/2025-10-10>.

## Why support both sets of criteria?

Neither set of criteria is a clear superset of the other.
Their overlaps are often complex
"partial" mappings instead of clean "X covers everything in Y" mappings.

We don't want projects to lose their investment of time in the "metal series".
As of November 2025
over 9,000 projects have spent time to try to meet the metal series criteria,
with nearly 2,000 projects achieving at least "passing",
and we don't want them to think their work is a waste.
In addition, many may find the metal series' more detailed criteria valuable,
as the metal series include a lot of specifics that are
lacking in the baseline.
These include specifics on cryptography, build processes,
and requiring that the developers know how to develop secure software.

Others may prefer to use the baseline set of criteria.
The baseline focuses on mappings to regulations,
focuses solely on MUSTs, and is significantly shorter, and for some
these are advantages.

Some projects may want to use both sets of criteria.
Each list has criteria the other doesn't.
As a result, neither one obviously replaces the other.

Therefore, we plan to make some changes to support *both* sets of criteria.
A given project can use one set of criteria, or the other, or both, at
their choosing. A given project is likely to start with one set, and later
might work to also meet the other.

No set of criteria can fully capture good practices for projects, so being
able to use both sets of criteria has its advantages.
In the longer term there may be more work to converge these criteria, but
there's no obvious short-term way to do this, so doing this incrementally
where appropriate is more likely to succeed.

## Expected result

Currently each project has a page for each criterion set
(e.g., one each for passing, silver, and gold). The plan would be to add
more such pages (one each for baseline-1, baseline-2, and baseline-3).
The plan would be to work incrementally.
We would eventually add more automation, including automation to reuse
any existing data.

## Resource URLs

URLs for the production site always begin with
`https://www.bestpractices.dev`.
In "normal" URLs this is followed by `/{LOCALE}`, and if
the locale is omitted, it's automatically redirected
as set in the user's browser settings.
There are a few locale-independent URLs; in those cases the locale must
be omitted.

A URL `criteria_level` will no longer be `0` (passing), `1` (silver), or `2`
(gold), as that will be confusing. The value values will be
`passing`, `silver`, `gold`, `baseline-1`, `baseline-2`, `baseline-3`,
and `permissions`. The last one isn't really a criteria level, but a way
for users to enter changes to permissions on the project
(these are currently handled when editing passing, and we want baseline
users to have the same access).

Given that, we'll have support for:

* `/projects/{id}`: Temporary redirect to the "preferred" criteria level.
* `/projects/{id}/{criteria_level}`:
   Show the form for that criteria level (append `/edit` to edit them).
* `/projects/{id}.{format}`: Show data for project in that format
  (.json, .md).
* `/projects/{id}/badge`: Show the small badge image for the metal series.
   This is locale-independent, to maximize caching.
* `/projects/{id}/baseline`: Show the small badge image for the baseline series
   This is locale-independent, to maximize caching.

## High-level implementation plan

The plan is to do some reorganizing to make it easier to add support
for baseline, then implement baseline.

1. Change URL `criteria_level` so 0,1,2 get permanently redirected
   to passing, silver, gold, and support those new names.
   Ensure that there's only 1 canonical name for data, to reduce spider load.
   Move the permissions changes to a new form `permissions`, so that
   people don't need to view/edit "passing" to see/edit permissions.
2. Add support for `baseline-1` criteria level and at least stub views
   for two baseline-1 criteria, along with their database support.
3. Add full support for `baseline-1` criteria level
   so it can be manually viewed and edited.  Test.
4. Add support for `/baseline` small badge image.
5. Add full support data entry of `baseline-2` and `baseline-3`.
6. Add basic automation, at least build on existing automation
   (in the longer term we want to use more tools and automation).
7. Discuss with natural language translators. This is a lot of translation work.
   Currently the plan is to add mechanism so automated translations
   are used (using existing translations as templates)
   but *only* when there isn't a human translation. Human translation
   will always be better, but showing English isn't great for those
   who don't speak English.

## Criteria mappings

For the most part the baseline and best practices badge are not the same. In some places they are similar but not identical (so meeting one doesn't always guarantee meeting the other). There are mappings available to help show their relationships.

A form (in English) with the BP Badge criteria are here:
<https://www.bestpractices.dev/en/criteria>.
At the time of writing, the current baseline is here: <https://baseline.openssf.org/versions/2025-10-10>.

To understand their similarities, you can see the
["Compliance Crosswalk Matrix" on the "BP Badges" tab](https://docs.google.com/spreadsheets/d/1an5mx3rayoz3JRFUepD56zgprpwXBXBG70fVZvIMCpA/edit?gid=468811656#gid=468811656).
This shows each of the best practices badge criteria, mapping each to the baseline criteria most related to them.
It also shows a separate set of IDs that for the best practices badge criteria that aren't used anywhere else.

Here's an example of a subset of its data, showing some criteria from the best practices badge. I've intentionally chosen an area where baseline and BP badge criteria are more similar to each other:

| Special ID | BP Badge ID | Level | Requirements text | Mapping |
| --- | --- | --- | --- | --- |
| B-P-4 | `contribution` | Passing | The information on how to contribute MUST explain the contribution process (e.g., are pull requests used?) (URL required for "met".) | OSPS-GV-03 |
| B-P-5 | `contribution_requirements` | Passing | The information on how to contribute SHOULD include the requirements for acceptable contributions (e.g., a reference to any required coding standard). (URL required for "met".) | OSPS-GV-03 |
| B-S-3 | `governance` | Silver | The project MUST clearly define and document its project governance model (the way it makes decisions, including key roles). | OSPS-GV-03, OSPS-GV-01 |
| B-B-4+ | `contribution_requirements` | Silver | Upgrade contribution_requirements from SHOULD to MUST. "The information on how to contribute MUST include the requirements for acceptable contributions (e.g., a reference to any required coding standard)." | OSPS-GV-03, OSPS-GV-03, OSPS-GV-01 |

Note that `contribution_requirements` becomes a "MUST" at Silver. Note also that the mapping only maps to categories here, not to specific baseline controls.

You can see the
[current baseline criteria](https://baseline.openssf.org/versions/2025-10-10).
At its top is the short text of its criteria, followed by details. If you look at the details,
you'll see "BPB:" entries (best practices badge) with criteria IDs. Use the "Compliance Crosswalk Matrix" to
map those IDs back to the Best Practices badge criteria ids.

For example, if you go to:
https://baseline.openssf.org/versions/2025-10-10#osps-gv-03---the-project-documentation-must-include-an-explanation-of-the-contribution-process

You'll see that under category "Governance" (OSPS-GV) we have several sub-categories.

One sub-category is "OSPS-GV-01 - The project documentation MUST include the roles and responsibilities for members of the project." This includes these controls:

OSPS-GV-01.01:

* Requirement: While active, the project documentation MUST include a list of project members with access to sensitive resources.
* Recommendation: Document project participants and their roles through such artifacts as members.md, governance.md, maintainers.md, or similar file within the source code repository of the project. This may be as simple as including names or account handles in a list of maintainers, or more complex depending on the project's governance.
* Maturity Level 2-3

OSPS-GV-01.02:

* Requirement: While active, the project documentation MUST include descriptions of the roles and responsibilities for members of the project.
* Recommendation: Document project participants and their roles through such artifacts as members.md, governance.md, maintainers.md, or similar file within the source code repository of the project.
* Maturity Level 2-3
* External Framework Mappings: BPB: B-S-3, B-S-4

Another sub-category is "OSPS-GV-03 - The project documentation MUST include an explanation of the contribution process." that includes 2 controls:

OSPS-GV-03.01:

* Requirement: While active, the project documentation MUST include an explanation of the contribution process.
* Recommendation: Document project participants and their roles through such artifacts as members.md, governance.md, maintainers.md, or similar file within the source code repository of the project. This may be as simple as including names or account handles in a list of maintainers, or more complex depending on the project's governance.
* Baseline level 2,3

OSPS-GV-01.02:

* Requirement: While active, the project documentation MUST include descriptions of the roles and responsibilities for members of the project.
* Recommendation: Document project participants and their roles through such artifacts as members.md, governance.md, maintainers.md, or similar file within the source code repository of the project.
* Baseline level 2,3
* External Framework ... BPB: {B-S-3 0 }, {B-S-4 0 }

## Detailed plan

See the file [baseline_details.md](./baseline_details.md) for more details
on exactly how this is (currently) planned to be implemented.
