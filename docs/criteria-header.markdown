# Best Practices Criteria for Free/Libre and Open Source Software (FLOSS)

<!-- SPDX-License-Identifier: (MIT OR CC-BY-3.0+) -->
<!-- DO NOT EDIT generated file criteria.md !! -->
<!-- The actual criteria and detail text are in config/locales/en.yml -->
<!-- while rationale and other info is in locale/criteria/criteria.yml . -->
<!-- See also files criteria-header.markdown and criteria-footer.markdown . -->

## See the website!

We've recently moved the criteria information to the active website!

There you can see the
<a href="https://www.bestpractices.dev/criteria/0">passing
criteria</a>,
<a href="https://www.bestpractices.dev/criteria">all
criteria</a>, and the
<a href="https://www.bestpractices.dev/criteria_discussion">criteria discussion</a>.

This change makes it easier to see the real criteria in any language,
as well as hide or reveal the details and rationale.

You can also add a "?" and some `&`-separated parameters:

* `details=true` : Show criterion details (clarifications)
* `rationale=true` : Show the criterion rationale
  (why this criterion is included in the set of criteria).
  This option only applies to the English locale.
* `autofill=true` : Show ideas for how to automatically determine this.
  This option only applies to the English locale.

For now, we've kept the old criteria text below, so you're not
surprised by this change.

## (OLD) Introduction

This is a set of best practices
for Free/Libre and Open Source Software (FLOSS) projects.
Projects that follow these best practices
will be able to voluntarily self-certify and show that they've
achieved a Core Infrastructure Initiative (CII) badge.
Projects can do this, at no cost,
by using a web application (BadgeApp)
to explain how they meet these practices and their detailed criteria.

There is no set of practices that can guarantee that software
will never have defects or vulnerabilities;
even formal methods can fail if the specifications or assumptions are wrong.
Nor is there any set of practices that can guarantee that a project will
sustain a healthy and well-functioning development community.
However, following best practices can help improve the results
of projects.
For example, some practices enable multi-person review before release,
which can both help find otherwise hard-to-find technical vulnerabilities
and help build trust and a desire for repeated interaction among developers
from different organizations.

These best practices have been created to:

1. encourage projects to follow best practices,
2. help new projects discover what those practices are, and
3. help users know which projects are following best practices
   (so users can prefer such projects).

The idiom "best practices" means
"a procedure or set of procedures that is preferred or considered
standard within an organization, industry, etc."
(source:
<a href="http://www.dictionary.com/browse/best-practice">Dictionary.com</a>).
These criteria are what we believe are
widely "preferred or considered standard"
in the wider FLOSS community.

The "passing" criteria listed here focus on identifying best practices
that well-run FLOSS projects typically already follow.
The criteria are inspired by a variety of sources;
see the separate "[background](./background.md)" page for more information.

[The criteria for higher/more advanced badges](./other.md)
describe the criteria for the higher-level badges.
These are known as the "silver" and "gold" levels, and sometimes also
described as "other" criteria.
You must achieve the "passing" criteria before you can achieve
silver or gold.

The Linux Foundation also sponsors the
[OpenChain Project](https://www.openchainproject.org/), which
identifies criteria for a "high quality Free
and Open Source Software (FOSS) compliance program."
OpenChain focuses on how organizations can best use FLOSS and contribute
back to FLOSS projects, while the CII Best Practices badge
focuses on the FLOSS projects themselves.
The CII Best Practices badge and OpenChain work together to help
improve FLOSS and how FLOSS is used.

We expect that these practices and their detailed criteria will be updated,
even after badges are released.
Thus, criteria (and badges) probably will have a year identifier
and will phase out after a year or two.
We expect it will be easy to update the information,
so this relatively short badge life should not be a barrier.
We plan to add new criteria but mark them as "future" criteria, so that
projects can add that information and maintain their badge.

Feedback is *very* welcome via the
[GitHub site as issues or pull requests](https://github.com/ossf/best-practices-badge).
There is also a
[mailing list for general discussion](https://lists.coreinfrastructure.org/mailman/listinfo/cii-badges).

Below are the current criteria, along with and where to get more information.
The key words "MUST", "MUST NOT",
"SHOULD", "SHOULD NOT", and "MAY"
in this document are to be interpreted as described in
[RFC 2119](https://tools.ietf.org/html/rfc2119).
The additional term SUGGESTED is added, as follows:

- The term MUST is an absolute requirement, and MUST NOT
  is an absolute prohibition.
- The term SHOULD indicates a criterion that is normally required,
  but there may exist valid reasons in particular circumstances to ignore it.
  However, the full implications must be understood and carefully weighed
  before choosing a different course.
- The term SUGGESTED is used instead of SHOULD when the criterion must
  be considered, but valid reasons
  to not do so are even more common than for SHOULD.
- Often a criterion is stated as something that SHOULD be done, or is
  SUGGESTED, because it may be difficult to implement or the costs
  to do so may be high.
- The term MAY provides one way something can be done, e.g.,
  to make it clear that the described implementation is acceptable.
- To obtain a badge, all MUST and MUST NOT criteria must be met, all
  SHOULD criteria must be met OR the rationale for
  not implementing the criterion must be documented, and
  all SUGGESTED criteria have to be considered (rated as met or unmet).
  In some cases a URL may be required as part of the criterion's justification.
- The text "(Future criterion)" marks criteria that are not currently
  required, but may be required in the future.

We assume that you are already familiar with
software development and running a FLOSS project;
if not, see introductory materials such as
[*Producing Open Source Software* by Karl Fogel](http://producingoss.com/).

## Terminology

A *project* is an active entity that has project member(s) and produces
project result(s).
Its member(s) use project sites to coordinate and disseminate result(s).
A project does not need to be a formal legal entity.
Key terms relating to project are:

*   Project *members* are the
    group of one or more people or companies who work together
    to attempt to produce project results.
    Some FLOSS projects may have different kinds of members, with different
    roles, but that's outside our scope.
*   Project *results* are what the project members work together
    to produce as their end goal. Normally this is software,
    but project results may include other things as well.
    Criteria that refer to "software produced by the project"
    are referring to project results.
*   Project *sites* are the sites dedicated to supporting the development
    and dissemination of project results, and include
    the project website, repository, and download sites where applicable
    (see <a href="#sites_https">sites_https</a>).
*   The project *website*, aka project homepage, is the main page
    on the world wide web (WWW) that a new user would typically visit to see
    information about the project; it may be the same as the project's
    repository site (this is often true on GitHub).
*   The project *repository* manages and stores the project results
    and revision history of the project results.
    This is also referred to as the project *source repository*,
    because we only require managing and storing of the editable versions,
    not of automatically generated results
    (in many cases generated results are not stored in a repository).

## Current criteria: Best Practices for FLOSS

Here are the current criteria.  Note that:

* Text inside square brackets is the short name of the criterion.
* In a few cases rationale is also included.
* We expect that there will be a few other fields for the
  project name, description, project URL, repository URL (which may be the
  same as the project URL), and license(s).
* In some cases N/A ("not applicable") may be an appropriate and permitted
  response.

In some cases we automatically test and fill in information
if the project follows standard conventions and
is hosted on a site (e.g., GitHub) with decent API support.
We intend to improve this automation in the future (improvements welcome!).

The actual criteria are stored in the file "criteria/criteria.yml", including
details, rationale, and how it could be automated.

There is an implied criterion that we should mention here:

- <a name="homepage_url"></a>The project MUST have a public website
  with a stable URL.
  (The badging application enforces this by requiring a URL to
  create a badge entry.)
  <sup>[<a href="#homepage_url">homepage_url</a>]</sup>
