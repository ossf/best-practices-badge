# Other criteria for higher-level badges

<!-- SPDX-License-Identifier: (MIT OR CC-BY-3.0+) -->

## See the website!

We've recently moved the criteria information to the active website!

There you can see the
<a href="https://bestpractices.coreinfrastructure.org/criteria/0">passing
criteria</a>,
<a href="https://bestpractices.coreinfrastructure.org/criteria">all
criteria</a>, and the
<a href="https://bestpractices.coreinfrastructure.org/criteria_discussion">criteria discussion</a>.

This change makes it easier to see the real criteria in any language,
as well as hide or reveal the details and rationale.

For now, we've kept the old criteria text below, so you're not
surprised by this change.

## Introduction

This document describes the criteria for badges beyond the "passing" level
(the "silver" and "gold" levels).
Please
[post an issue](https://github.com/ossf/best-practices-badge/issues)
if you have comments on these criteria.
These criteria build on the
<a href="./criteria.md">criteria for the "passing" level</a>.
Note that passing is by itself an achievement; at the time of this writing
only about 10% of projects that are pursuing a badge achieve the
passing level.

These higher levels are named "silver" and "gold":

* Silver (formerly "passing+1") is a more stringent set of criteria
  than the passing level, but these criteria
  are still expected to be achievable by small and
  single-organization projects.
* Gold (formerly "passing+2") is an even more stringent
  set of criteria than the silver level, but
  include criteria that are possibly not achievable by small or
  single-organization projects.

Historically we called these levels "passing+1" and "passing+2"
so that we could create their names as a separate process.
We considered naming systems such as the
<a href="http://www.usgbc.org/leed">LEED certification naming system of certified, silver, gold, platinum</a>
and how the
<a href="http://www.linuxfoundation.org/about/members">Linux Foundation ranks membership (silver, gold, platinum)</a>.
An alternative is the Olympic system naming (bronze, silver, gold).
We chose these names in part because we could add yet another level
later (presumably calling it platinum).

Note that in several cases SHOULD criteria become MUST in higher level
badges, and SUGGESTED criteria at lower levels become SHOULD or MUST
in higher level badges.

## Silver (passing+1) criteria

You must achieve the lower (passing) badge.  In addition,
some SHOULD will become MUST, and some SUGGESTED will become
SHOULD or MUST.

### Upgrade of SHOULD and SUGGESTED

Upgrade some "passing" level SHOULD and SUGGESTED:

#### Upgrade: Basics

*   Upgrade contribution_requirements from SHOULD to MUST.
    "The information on how to contribute MUST include the
    requirements for acceptable contributions (e.g., a reference to
    any required coding standard)."

*   Upgrade report_tracker from SHOULD to MUST -
    "The project MUST use an issue tracker for tracking individual issues."

    Note: The Linux kernel project has indicated that using an issue
    tracker is difficult at their scale.

*   Unchanged:

    - floss_license_osi -
      "It is SUGGESTED that any required license(s) be <a
      href="https://opensource.org/licenses">approved by the Open Source
      Initiative (OSI).</a>"

    - english -
      "The project SHOULD include documentation in English and be able
      to accept bug reports and comments about code in English."

#### Upgrade: Change Control

*   Unchanged:

    - repo_distributed -
      "It is SUGGESTED that common distributed version control software
      be used (e.g., git)."

    - version_semver -
      "It is SUGGESTED that the <a href="http://semver.org">Semantic
      Versioning (SemVer) format</a> be used for releases."

    - version_tags -
      "It is SUGGESTED that projects identify each release within
      their version control system. For example, it is SUGGESTED
      that those using git identify each release using git tags."

#### Upgrade: Reporting

*   Unchanged:

    - enhancement_responses:
      "The project SHOULD respond to a majority of enhancement requests in the
      last 2-12 months (inclusive)."

#### Upgrade: Quality

*   tests_documented_added.  Upgrade from SUGGESTED to MUST.
    "The project MUST include, in its documented instructions for
    change proposals, the policy that tests are to be added for major
    new functionality."<br>
    This is a change from, "It is SUGGESTED that this policy on
    adding tests be <i>documented</i> in the instructions for change
    proposals."

*   <a name="warnings_strict"></a>
    warnings_strict -
    Projects MUST be maximally strict with warnings, where practical.
    <sup>[<a href="#warnings_strict">warnings_strict</a>]</sup>

    *Details*: Some warnings cannot be effectively enabled on some projects.
    What is needed is evidence that the project is striving to enable
    warning flags where it can, so that errors are detected early.

*   Unchanged:

    - build_common_tools -
      "It is SUGGESTED that common tools be used for building the software."

    - build_floss_tools -
      "The project SHOULD be buildable using only FLOSS tools."

    - test_invocation -
      "A test suite SHOULD be invocable in a standard way for that language."

    - test_most -
      "It is SUGGESTED that the test suite cover most (or ideally all)
      the code branches, input fields, and functionality."

      *NOTE*: Statement/branch coverage is covered separately; they are
      increased, so we are not changing the level of this one.

    - test_continuous_integration -
      "It is SUGGESTED that the project implement continuous integration
      (where new or changed code is frequently integrated into a central
      code repository and automated tests are run on the result)."

      *NOTE*: This is upgraded to MUST in gold, and silver adds
      an intermediate criterion called <a
      href="#automated_integration_testing">automated_integration_testing</a>.

#### Upgrade: Security

*   Upgrade crypto_weaknesses from SHOULD to MUST.
    The default security mechanisms within the software produced
    by the project MUST NOT depend on
    cryptographic algorithms or modes with known serious weaknesses
    (e.g., the SHA-1 cryptographic hash algorithm or the CBC mode in SSH).

*   Unchanged:

    - crypto_call

    - crypto_pfs

    - vulnerabilities_critical_fixed
      "Projects SHOULD fix all critical vulnerabilities rapidly after
      they are reported."

      *NOTE*: We'd like this to always be true, but some vulnerabilities
      are hard to fix, so it's difficult to mandate this.
      We *could* require activities to actively work to fix it, and
      that is worth considering, but are uncertain that would really help users.
      So we have left it this way.

#### Upgrade: Analysis

*   Upgrade static_analysis_common_vulnerabilities from SUGGESTED to MUST:
    "A project MUST use at least one static analysis tool
    with rules or approaches to look for common vulnerabilities
    in the analyzed language or environment, if
    there is at least one FLOSS tool that can implement this criterion
    in the selected language."

    *NOTE*: We'd like all projects to use this kind of static analysis tool,
    but there may not be one in the chosen language, or it may only be
    proprietary (and some developers will therefore not use it).

*   Upgrade dynamic_analysis_unsafe from SUGGESTED to MUST.
    <i>If</i> the software produced by the project includes
    software written using a memory-unsafe language (e.g., C or C++),
    <i>then</i> the project MUST use
    at least one dynamic tool (e.g., a fuzzer or web
    application scanner) be routinely used in combination with
    a mechanism to detect memory safety problems such as buffer
    overwrites.
    If the project does not produce software written
    in a memory-unsafe language, choose "not applicable" (N/A).

    *NOTE*:
    This would mean that C/C++ would be required to use something like
    ASAN during some testing and/or fuzz testing. See:
    <a href="https://github.com/ossf/best-practices-badge/issues/256">consider giving links to asan/msan/tsan/ubsan and libFuzzer</a>

*   Unchanged:

    - static_analysis_often -
      "It is SUGGESTED that static source code analysis occur on every
      commit or at least daily."

    - dynamic_analysis -
      "It is SUGGESTED that at least one dynamic analysis tool be applied
      to any proposed major production release of the software before
      its release."

      *Note*: There are good arguments for increasing this at silver,
      clearly using different kinds of tools can find different things.
      However, while these tools can find problems, they often miss many,
      and it's often harder to backtrack the problem to determine
      how to fix it.  We encourage use of these tools, but that doesn't
      mean we should mandate them in all cases at this level.
      We've chosen instead to focus on requiring these kinds of tools for
      memory-unsafe languages, and thus upgraded dynamic_analysis_unsafe.

    - dynamic_analysis_enable_assertions -
      "It is SUGGESTED that the software include many run-time assertions
      that are checked during dynamic analysis."

### Basics

*   <a name="dco"></a>The project SHOULD have a legal mechanism where
    all developers of non-trivial amounts of project software assert that
    they are legally authorized to make these contributions. The most
    common and easily-implemented approach for doing this is by using a
    <a href="http://developercertificate.org/">Developer Certificate of Origin (DCO)</a>,
    where users add "signed-off-by" in their commits and
    the project links to the DCO website.
    However, this MAY be implemented as a
    Contributor License Agreement (CLA), or other legal mechanism.
    <sup>[<a href="#dco">dco</a>]</sup>

    *Details*: The DCO is the recommended
    mechanism because it's easy to implement, tracked in the source code,
    and git directly supports a "signed-off" feature using "commit -s".
    To be most effective it is best if the project documentation
    explains what "signed-off" means for that project.
    A CLA is a legal agreement that defines
    the terms under which intellectual works have been licensed to an
    organization or project.  A contributor assignment agreement (CAA)
    is a legal agreement that transfers rights in an intellectual work
    to another party; projects are not required to have CAAs, since
    having CAA increases the risk that potential contributors
    will not contribute, especially if the receiver is
    a for-profit organization.
    The
    [Apache Software Foundation CLAs (the individual contributor license and the corporate CLA)](https://www.apache.org/licenses/)
    are examples of CLAs, for projects which determine that the risks
    of these kinds of CLAs to the project are less than their benefits.

*   <a name="code_of_conduct"></a>The project MUST adopt a code of conduct and
    post it in a standard location.
    <sup>[<a href="#code_of_conduct">code_of_conduct</a>]</sup>

    *Details*: Projects may be able to improve the civility of their
    community and to set expectations about acceptable conduct by adopting a
    code of conduct. This can help avoid problems before they occur and make
    the project a more welcoming place to encourage contributions.
    This should focus only on behavior within the community/workplace of the
    project.
    Example codes of conduct are the
    <a href="https://www.kernel.org/doc/html/latest/process/code-of-conflict.html">Linux kernel code of conflict</a>,
    the <a href="http://contributor-covenant.org/">Contributor
    Covenant Code of Conduct</a>,
    the <a href="https://www.debian.org/code_of_conduct">Debian Code of Conduct</a>,
    the <a href="https://www.ubuntu.com/about/about-ubuntu/conduct">Ubuntu Code of Conduct</a>,
    the <a href="https://getfedora.org/code-of-conduct">Fedora Code of Conduct</a>,
    the <a href="https://wiki.gnome.org/action/show/Foundation/CodeOfConduct">GNOME Code Of Conduct</a>,
    the <a href="https://www.kde.org/code-of-conduct/">KDE Community Code of Conduct">,
    the <a href="https://www.python.org/psf/codeofconduct/">Python Community Code of Conduct</a>,
    the <a href="https://www.ruby-lang.org/en/conduct/">The Ruby Community Conduct Guideline</a>, and
    the <a href="https://www.rust-lang.org/en-US/conduct.html">The Rust Code of Conduct</a>.

    *Rationale* Suggested in
    <a href="https://github.com/ossf/best-practices-badge/issues/608">issue#608</a>
    by Dan Kohn and in the NYC 2016 brainstorm session.
    The long list of examples shows that many widely-used FLOSS projects
    have a code of conduct (obviously there's no way to list them all!).

*   <a name="governance"></a>The project MUST clearly define and document
    its project governance model (the way it makes decisions,
    including key roles).
    <sup>[<a href="#governance">governance</a>]</sup>

    *Details*: There needs to be some well-established documented way
    to make decisions and resolve disputes.
    In small projects, this may be as simple as "the project owner and lead
    makes all final decisions".
    There are various governance models, including benevolent dictator
    and formal meritocracy; for more details, see
    <a href="http://oss-watch.ac.uk/resources/governancemodels">Governance models</a>.
    Both centralized (e.g., single-maintainer) and decentralized
    (e.g., group maintainers) approaches have been successfully used
    in projects.
    The governance information does not need to document the possibility
    of creating a project fork, since that is always possible
    for FLOSS projects.

    *Rationale*:
    There are many different governance models used by a wide array of
    successful projects.  Therefore, we do not believe that we should
    specify a particular governance model.  However, we do think it is
    important to have a governance model, and clearly define it, so that
    all participants and potential participants will know how decisions
    will be made.
    This was inspired by the
    <a href="https://web.archive.org/web/20171123114606/https://projects.ow2.org/bin/view/ow2/OMM">OW2 Open-source Maturity Model</a>,
    in particular RDMP-1 and STK-1.

*   <a name="roles_responsibilities"></a>
    The project MUST clearly define and publicly document the key roles in the
    project and their responsibilities, including any tasks those roles
    must perform.  It MUST be clear who has which role(s), though this
    might not be documented in the same way.
    <sup>[<a href="#roles_responsibilities">roles_responsibilities</a>]</sup>

    *Details*: The documentation for
    <a href="#governance">governance</a> and roles and responsibilities
    may be in one place.

    Rationale: Much knowledge about the project roles builds up
    over the years, and is not sufficiently passed down to new people.
    Documenting the roles can help recruit, train, and mentor new
    project members.  Projects may choose document the roles
    and responsibilities in one place, and identify who has the roles
    separately, so that the project doesn't need to update the role
    information when people change roles.
    The goal is to make underlying assumptions clear.

#### Documentation

*   <a name ="documentation_roadmap"></a>The project MUST have a documented
    roadmap that describes what the project intends to do and not do for
    at least the next year.
    <sup>[<a href="#documentation_roadmap">documentation_roadmap</a>]</sup>

    *Details*: The project might not achieve the roadmap,
    and that's fine; the purpose of the roadmap is to help potential
    users and contributors understand the intended direction of the
    project. It need not be detailed.

*   <a name="documentation_architecture"></a>
    The project MUST include documentation
    of the architecture (aka high-level design) of the software
    produced by the project.
    If the project does not produce software,
    select "not applicable" (N/A).
    <sup>[<a href="#documentation_architecture">documentation_architecture</a>]</sup>

    *Details*:
    A software architecture explains a program's fundamental structures,
    i.e., the program's major components, the relationships among them, and
    the key properties of these components and relationships.

    *Rationale*: Documenting the basic design makes it easier for potential
    new developers to understand its basics.
    This is related to know_secure_design, as well
    as implement_secure_design and proposed documentation_security.

*   <a name="documentation_security"></a>
    The project MUST document what the user can and cannot expect
    in terms of security from the software produced by the project.
    The project MUST identify the security requirements
    that the software is intended to meet and an
    assurance case that justifies why these requirements are met.
    The assurance case MUST include: a description of the threat model,
    clear identification of trust boundaries, and
    evidence that common security weaknesses have been countered.
    <sup>[<a href="#documentation_security">documentation_security</a>]</sup>

    *Details*:
    An assurance case is
    "a documented body of evidence that provides a convincing and valid
    argument that a specified set of critical claims regarding a system’s
    properties are adequately justified for a given application in a given
    environment"
    (<a href="http://nvlpubs.nist.gov/nistpubs/ir/2009/ir7608.pdf">"Software
    Assurance Using Structured Assurance Case Models", Thomas Rhodes et al,
    NIST Interagency Report 7608</a>).
    Trust boundaries are
    boundaries where data or execution changes its level of trust, e.g.,
    a server's boundaries in a typical web application.

    *Rationale*: Writing the specification helps the developers think about the
    interface (including the API) the developers are providing, as well
    letting any user or researcher know what to expect.
    Many sources discuss the rationale for an "assurance case".
    This was inspired by
    <a href="https://github.com/ossf/best-practices-badge/issues/502">Security specification and facilitation of bug bounties</a>
    and by the
    <a href="https://github.com/ossf/best-practices-badge/issues/473">NYC 2016 brainstorming session</a>.

*   <a name="documentation_quick_start"></a>
    The project MUST provide a "quick start" guide for new users
    to help them quickly do something with the software.
    <sup>[<a href="#documentation_quick_start">documentation_quick_start</a>]</sup>
    *Details*:
    The idea is to show users how to get started and make the software do
    anything at all. This is critically important for potential users to
    get started.

    *Rationale*:
    This is based on a conversation with Mike Milinkovich,
    Executive Director of the Eclipse Foundation, about the OSS project
    criteria and "what is important".
    He believes, based on his long experience, that it is critically
    important that any project have some sort of "quick start" guide to
    help someone get started and do something with the software;
    this feeling of accomplishment and demonstration that it works
    builds understanding and confidence in the user.
    https://github.com/ossf/best-practices-badge/issues/645

*   <a name="documentation_current"></a>
    The project MUST make an effort to
    keep the documentation consistent with the current version of the
    project results (including software produced by the project).
    Any <i>known</i> documentation defects making it inconsistent
    MUST be fixed.
    If the documentation is generally current, but erroneously
    includes some older information that is no longer true,
    just treat that as a defect, then track and fix as usual.
    <sup>[<a href="#documentation_current">documentation_current</a>]</sup>

    *Details*:
    The documentation MAY include information about differences or changes
    between versions of the software and/or link to older versions of
    the documentation.
    The intent of this criterion is that an effort is made to keep
    the documentation consistent, not that the documentation
    must be perfect.

    *Rationale*: It's difficult to keep documentation up-to-date, so the
    criterion is worded this way to make it more practical.
    Information on differences or changes between versions of the
    software helps users of older versions
    and users who are transitioning from older versions.

*   <a name="documentation_achievements"></a>
    The project repository front page and/or website MUST
    identify and hyperlink to any achievements,
    including this best practices badge, within 48 hours
    of public recognition that the achievement has been attained.
    <sup>[<a href="#documentation_achievements">documentation_achievements</a>]</sup>

    *Details*: An achievement is any set of external criteria that the project
    has specifically worked to meet, including some badges.
    This information does not need to be on the project website front page.
    A project using GitHub can put achievements on the repository front page
    by adding them to the README file.

    *Rationale*: Users and potential co-developers need to be able to
    see what achievements have been attained by a project they are considering
    using or contributing to.  This information can help them determine
    if they should.  In addition, if projects identify their achievements,
    other projects will be encouraged to follow suit and also make those
    achievements, benefitting everyone.

#### Other

*   <a name ="sites_password_security"></a>
    If the project sites (website, repository, and download URLs)
    store passwords for authentication of external users, the passwords
    MUST be stored as iterated hashes with a per-user salt by
    using a key stretching (iterated) algorithm (e.g., PBKDF2, Bcrypt
    or Scrypt).
    If the project sites do not store passwords for this purpose,
    select N/A.

    *Details*:
    Note that the use of
    <a href="https://help.github.com/articles/github-security/">GitHub</a>
    meets this criterion.
    This criterion only applies to passwords used for authentication of
    external users into the project sites.
    If the project sites must log in to other sites, they may need to store
    passwords for that purpose differently (since using an algorithm like
    Bcrypt would make those passwords useless).
    This applies criterion crypto_password_storage
    to the project sites, similar to sites_https.

#### Accessibility and Internationalization

*   <a name ="accessibility_best_practices"></a>
    The project (both project sites and project results) SHOULD
    follow accessibility best practices so that
    persons with disabilities can still participate in the project and
    use the project results where it is reasonable to do so.
    <sup>[<a href="#accessibility_best_practices">accessibility_best_practices</a>]</sup>

    *Details*:
    For web applications, see the
    <a href="https://www.w3.org/TR/WCAG20/">Web Content Accessibility
    Guidelines (WCAG 2.0)</a> and its supporting document
    <a href="https://www.w3.org/TR/UNDERSTANDING-WCAG20/Overview.html">Understanding WCAG 2.0</a>;
    see also
    <a href="https://www.w3.org/standards/webdesign/accessibility">W3C accessibility information</a>.
    For GUI applications, consider using the environment-specific
    accessibility guidelines (such as
    <a href="https://developer.gnome.org/accessibility-devel-guide/stable/">Gnome</a>,
    <a href="https://accessibility.kde.org/">KDE</a>,
    <a href="http://docs.xfce.org/xfce/xfce4-settings/accessibility">XFCE</a>,
    <a href="https://developer.android.com/guide/topics/ui/accessibility/">Android</a>,
    <a href="https://developer.apple.com/accessibility/ios/">iOS</a>,
    <a href="http://www.apple.com/accessibility/osx/voiceover/">Mac</a>, and
    <a href="https://msdn.microsoft.com/en-us/windows/uwp/accessibility/accessibility-overview">Windows</a>).
    Some TUI applications (e.g. `ncurses` programs) can do
    certain things to make themselves more accessible (such as `alpine`'s
    `force-arrow-cursor` setting).
    Most command-line applications are fairly accessible as-is.
    This criterion is often N/A, e.g., for program libraries.
    Here are some examples of actions to take or issues to consider:

    <ul>
    <li>Provide text alternatives for any non-text content so
      that it can be changed into other forms people need, such as
      large print, braille, speech, symbols or simpler language (<a
      href="https://www.w3.org/TR/UNDERSTANDING-WCAG20/text-equiv.html">WCAG
      2.0 guideline 1.1</a>)
    <li>Color is not used as the only visual means of conveying
      information, indicating an action, prompting a response, or
      distinguishing a visual element. (<a
      href="https://www.w3.org/TR/UNDERSTANDING-WCAG20/visual-audio-contrast-without-color.html">WCAG
      2.0 guideline 1.4.1</a>)
    <li>The visual presentation of text and images of text has a contrast
      ratio of at least 4.5:1, except for large text, incidental text,
      and logotypes (<a
      href="https://www.w3.org/TR/UNDERSTANDING-WCAG20/visual-audio-contrast-contrast.html">WCAG
      2.0 guideline 1.4.3</a>)
    <li>Make all functionality available from a keyboard (WCAG guideline 2.1)
    <li>A GUI or web-based project SHOULD test with at least one
      screen-reader on the target platform(s) (e.g. NVDA, Jaws, or WindowEyes
      on Windows; VoiceOver on Mac & iOS; Orca on Linux/BSD; TalkBack on
      Android). TUI programs MAY work to reduce overdraw to prevent redundant
      reading by screen-readers.
    </ul>

*   <a name="internationalization"></a>
    The software produced by the project SHOULD be internationalized to enable
    easy localization for the target audience's culture, region, or
    language.
    If internationalization (i18n) does not apply (e.g., the software
    doesn't generate text intended for end-users and
    doesn't sort human-readable text), select "not applicable" (N/A).
    <sup>[<a href="#internationalization">internationalization</a>]</sup>

    Details:
    Localization "refers to the adaptation of a product, application or
    document content to meet the language, cultural and other requirements
    of a specific target market (a locale)."
    Internationalization is the "design and development of a product,
    application or document content that enables easy localization for
    target audiences that vary in culture, region, or language."
    (See <a href="https://www.w3.org/International/questions/qa-i18n">W3C's "Localization vs. Internationalization"</a>.)
    Software meets this criterion simply by being internationalized.
    No localization for another specific language is required, since
    once software has been internationalized it's possible for others
    to work on localization.

    Rationale:
    When software is internationalized, the software can be used by far
    more people.  By itself, that's valuable.
    In addition, software that can be used by far more people is more
    likely to lead to larger communities, which increases the likelihood
    of contributions and reviews.

#### Continuity

* <a name="access_continuity"></a>The project MUST be able to continue
    with minimal interruption if any one person dies, is incapacitated, or is
    otherwise unable or unwilling to continue support of the project.
    In particular, the project MUST be able to create and close
    issues, accept proposed changes, and release versions of software,
    within a week of confirmation of the loss of support from any one
    individual.  This MAY be done by ensuring someone else has any
    necessary keys, passwords, and legal rights to continue the
    project.  Individuals who run a FLOSS project MAY do this by
    providing keys in a lockbox and a will providing any needed legal
    rights (e.g., for DNS names).  <sup>[<a
    href="#access_continuity">access_continuity</a>]</sup>

*   <a name="bus_factor"></a>The project SHOULD have a "bus factor" of 2 or more.
    <sup>[<a href="#bus_factor">bus_factor</a>]</sup>

    *Details*: A "bus factor" (aka "truck factor") is the
    minimum number of project members that have to suddenly disappear from
    a project ("hit by a bus") before the project stalls
    due to lack of knowledgeable or competent personnel.
    The <a href="https://github.com/mtov/truck-factor">truck-factor</a> tool can
    estimate this for projects on GitHub.  For more information, see
    <a href="https://www.researchgate.net/publication/272824568_assessing_the_bus_factor_of_git_repositories">Assessing the Bus Factor of Git Repositories</a>
    by Cosentino et al.

### Change Control

*   <a name="maintenance_or_update"></a>
    The project MUST maintain the most often used older versions of the product
    <i>or</i> provide an upgrade path to newer versions.
    If the upgrade path is difficult, the project MUST document how
    to perform the upgrade (e.g., the interfaces that have changed and
    detailed suggested steps to help upgrade).
    <sup>[<a href="#maintenance_or_update">maintenance_or_update</a>]</sup>

    *Rationale*:
    This was inspired by <a href="https://web.archive.org/web/20171123114606/https://projects.ow2.org/bin/view/ow2/OMM">DFCT-1.2</a>

### Reporting

*   <a name="vulnerability_report_credit"></a>The project MUST give credit
    to the reporter(s) of all vulnerability reports resolved in the last 12
    months, except for the reporter(s) who request anonymity.
    (N/A allowed).
    <sup>[<a href="#vulnerability_report_credit">vulnerability_report_credit</a>]</sup>

    *Details*: If there have been no vulnerabilities resolved in the last 12 months,
    choose "not applicable" (N/A).

    *Rationale*: It is only fair to credit those who provide vulnerability
    reports.  In many cases, the only reporter requirement is that
    they receive credit.  This is also important long-term, because giving
    credit encourages additional reporting.

    *Rationale*:
    Recommended in the
    <a href="https://github.com/ossf/best-practices-badge/issues/473">NYC 2016 brainstorming session</a>.

*   <a name="vulnerability_response_process"></a>The project MUST have a
    documented process for responding to vulnerability reports.
    <sup>[<a href="#vulnerability_response_process">vulnerability_response_process</a>]</sup>

    *Details*: This is strongly related to vulnerability_report_process,
    which requires that there be a documented way to report vulnerabilities.
    It also related to vulnerability_report_response, which requires
    response to vulnerability reports within a certain time frame.

    *Rationale*: This is inspired by
    <a href="http://community.apache.org/apache-way/apache-project-maturity-model.html">Apache Project Maturity Model</a>
    QU30.

### Quality

#### Test

*   <a name="automated_integration_testing"></a>
    An automated test suite MUST be applied on each check-in to a shared
    repository for at least one branch.  This test suite MUST
    produce a report on test success or failure.
    <sup>[<a href="#automated_integration_testing">automated_integration_testing</a>]</sup>

    *Details*: This requirement can be viewed as
    a subset of test_continuous_integration, but
    focused on just testing, without requiring continuous integration.

    *Rationale*: This is inspired by continuous integration.
    Continuous integration provides much more rapid feedback
    on whether or not changes will cause test failures,
    including regressions.  The term "continuous integration" (CI)
    is defined in Wikipedia as "merging all developer working copies
    to a shared mainline several times a day".
    <a href="http://martinfowler.com/articles/continuousIntegration.html">Martin Fowler</a>
    says that
    "Continuous Integration is a software development practice where
    members of a team integrate their work frequently, usually each
    person integrates at least daily - leading to multiple integrations
    per day. Each integration is verified by an automated build (including
    test) to detect integration errors as quickly as possible. Many teams
    find that this approach leads to significantly reduced integration
    problems and allows a team to develop cohesive software more rapidly."
    However, while merging all developer working copies at this pace can
    be very useful, in practice many projects do not or cannot always do this.
    In practice, many developers maintain at least some branches that are
    not merged for longer than a day.

*   <a name="test_policy_mandated"></a>
    The project MUST have a formal written policy that as major
    new functionality is added, tests for it MUST be added to an automated
    test suite.
    <sup>[<a href="#test_policy_mandated">test_policy_mandated</a>]</sup>

    *Rationale*: This ensures that major new functionality is tested.
    This is related to the criterion test_policy, but is rewritten
    to be stronger.

*   <a name="regression_tests_added50"></a>
    The project MUST add regression tests to an automated test suite
    for at least 50% of the bugs fixed within the last six months.
    <sup>[<a href="#regression_tests_added50">regression_tests_added50</a>]</sup>

    *Rationale*: Regression tests prevent undetected resurfacing of
    defects.  If a defect has happened before, there is an increased
    likelihood that it will happen again.  We only require 50% of bugs to
    have regression tests; not all bugs are equally likely to recur,
    and in some cases it is extremely difficult to build robust tests for
    them.  Thus, there is a diminishing point of return for adding
    regression tests.  The 50% value could be argued as being arbitrary,
    however, requiring less than 50% would mean that projects could
    get the badge even if a majority of their bugs in the time frame
    would not have regression tests.  Projects may,
    of course, choose to have much larger percentages.
    We choose six months, as with other requirements, so that projects
    that have done nothing in the past (or recorded nothing in the past)
    can catch up in a reasonable period of time.

*   <a name="test_statement_coverage80"></a>
    The project MUST have FLOSS automated test suite(s) that provide at least
    80% statement coverage if there is at least
    one FLOSS tool that can measure this criterion in the selected language.
    Many FLOSS tools are available to measure test coverage,
    including gcov/lcov, Blanket.js, Istanbul, and JCov.
    Note that meeting this criterion is not a guarantee that the
    test suite is thorough, instead, failing to meet this criterion is
    a strong indicator of a poor test suite.
    <sup>[<a href="#test_statement_coverage80">test_statement_coverage80</a>]</sup>

    *Rationale*: Statement coverage is widely used as a test quality measure;
    it's often a first "starter" measure for test quality.
    It's well-supported, including by gcov/lcov and codecov.io.
    Bad test suites could also meet this requirement, but it's generally
    agreed that any good test suite will meet this requirement, so it
    provides a useful way to filter out clearly-bad test suites.
    After all, if your tests aren't even *running* many of the program's
    statements, you don't have very good tests.
    Only FLOSS test suites are considered, to ensure that the test
    suite can be examined and improved over time.

    A good automated test suite enables rapid response
    to vulnerability reports.  If a vulnerability is reported to a project,
    the project may be able to quickly repair it, but that is not enough.
    A good automated test suite is necessary so the project can rapidly
    gain confidence that the repair doesn't break anything else so it can
    field the update.

    It could be argued that anything less than 100% is unacceptable, but
    this is not a widely held belief.
    There are many ways to determine if a program is correct -
    testing is only one of them.  Some conditions are hard to create
    during testing, and the return-on-investment to get those last few
    percentages is arguably not worth it.  The time working to get 100%
    statement coverage might be much better spent on checking the results
    more thoroughly (which statement coverage does *not* measure).

    The 80% suggested here is supported by various sources.
    The defaults of
    <a href="http://docs.codecov.io/docs/coverage-configuration">codecov.io</a>.  They define
    70% and below as red, 100% as perfectly green, and anything between
    70..100 as a range between red and green. This renders ~80% as yellow,
    and somewhere between ~85% and 90% it starts looking pretty green.

    The paper
    <a href="http://www.bullseye.com/minimum.html">"Minimum Acceptable Code Coverage" by Steve Cornett</a>
    claims, "Code
    coverage of 70-80% is a reasonable goal for system test of most
    projects with most coverage metrics. Use a higher goal for projects
    specifically organized for high testability or that have high failure
    costs. Minimum code coverage for unit testing can be 10-20% higher
    than for system testing... Empirical studies of real projects found
    that increasing code coverage above 70-80% is time consuming and
    therefore leads to a relatively slow bug detection rate. Your goal
    should depend on the risk assessment and economics of the project...
    Although 100% code coverage may appear like a best possible effort,
    even 100% code coverage is estimated to only expose about half the
    faults in a system. Low code coverage indicates inadequate testing,
    but high code coverage guarantees nothing."

    <a href="http://martinfowler.com/bliki/TestCoverage.html">"TestCoverage" by Martin Fowler (17 April 2012)</a>
    points out the
    problems with coverage measures.  he states that "Test coverage is
    a useful tool for finding untested parts of a codebase. Test coverage
    is of little use as a numeric statement of how good your tests are...
    The trouble is that high coverage numbers are too easy to reach with
    low quality testing... If you are testing thoughtfully and well,
    I would expect a coverage percentage in the upper 80s or 90s. I
    would be suspicious of anything like 100%... Certainly low coverage
    numbers, say below half, are a sign of trouble. But high numbers don't
    necessarily mean much, and lead to ignorance-promoting dashboards."

#### Coding standards

*   <a name="coding_standards"></a>
    The project MUST identify the specific coding style guides
    for the primary languages it uses, and require that contributions
    generally comply with it.
    <sup>[<a href="#coding_standards">coding_standards</a>]</sup>

    *Details*:
    In most cases this is done by referring to some existing style guide(s),
    possibly listing differences.
    These style guides can include ways to improve readability and
    ways to reduce the likelihood of defects (including vulnerabilities).
    Many programming languages have one or more widely-used style guides.
    Examples of style guides include
    <a href="https://github.com/google/styleguide">Google's style guides</a> and
    <a href="https://www.securecoding.cert.org/">SEI CERT Coding Standards</a>.

*   <a name="coding_standards_enforced"></a>
    The project MUST automatically enforce its selected coding style(s)
    if there is at least one FLOSS tool that can do so in the selected
    language(s).
    <sup>[<a href="#coding_standards_enforced">coding_standards_enforced</a>]</sup>

    *Details*:
    This MAY be implemented using static analysis tool(s) and/or by
    forcing the code through code reformatters.
    In many cases the tool configuration is included in the project's
    repository (since different projects may choose different configurations).
    Projects MAY allow style exceptions (and typically will);
    where exceptions occur, they MUST be rare and documented
    in the code at their locations, so that these exceptions can be reviewed
    and so that tools can automatically handle them in the future.
    Examples of such tools include ESLint (JavaScript) and Rubocop (Ruby).

#### Externally-maintained components

*   <a name="external_dependencies"></a>
    The project MUST list external dependencies in a computer-processable
    way. <sup>[<a href="#external_dependencies">external_dependencies</a>]</sup>

    *Details*:
    Typically this is done using the conventions of package manager
    and/or build system.
    Note that this helps implement installation_development_quick.

    *Rationale*:
    Inspired by the
    <a href="https://github.com/ossf/best-practices-badge/issues/473">NYC 2016 brainstorming session</a>.

*   <a name="updateable_reused_components"></a>
    The project MUST either
    (1) make it easy to identify and update reused externally-maintained components or
    (2) use the standard components provided by the system or programming language.
    Then, if a vulnerability is found in a reused component, it will be
    easy to update that component.
    <sup>[<a href="#updateable_reused_components">updateable_reused_components</a>]</sup>

    *Details*: A typical way to meet this criterion is to use
    system and programming language package management systems.
    Many FLOSS programs are distributed with "convenience libraries"
    that are local copies of standard libraries (possibly forked).
    By itself, that's fine.
    However, if the program *must* use these local (forked) copies,
    then updating the "standard" libraries as a security update will
    leave these additional copies still vulnerable.
    This is especially an issue for cloud-based systems;
    if the cloud provider updates their "standard" libraries but the program
    won't use them, then the updates don't actually help.
    See, e.g.,
    <a href="http://spot.livejournal.com/312320.html">"Chromium: Why it isn't in Fedora yet as a proper package" by Tom Callaway</a>.

    *Rationale*: A very common problem is to have obsolete components with
    known vulnerabilities.  This is OWASP Top 10 (2013) number A9
    (using known vulnerable components).  See also
    <a href="http://www.aspectsecurity.com/research-presentations/the-unfortunate-reality-of-insecure-libraries">The Unfortunate Reality of Insecure Libraries</a>.
    This partly deals with
    vendoring, where code is copied in with the
    express intent of *only* using that copied version?
    (These are intentional forks.)  There's a risk of divergence
    and failure to apply security fixes both ways.
    For an example, see
    <a href="https://lwn.net/Articles/713175/">"LZ4: vendoring in the kernel"
    by Jonathan Corbet (LWN, February 1, 2017)</a>, based on a
    2017 linux.conf.au talk by Robert Lefkowitz.
    Lefkowitz talked about the process of "vendoring" - the copying
    of code from other projects into one's own repository rather than
    accepting a dependency on those projects - and
    LZ4 in the Linux kernel.

*   <a name="interfaces_current"></a>
    The project SHOULD avoid using deprecated or obsolete functions
    and APIs where FLOSS alternatives are available in the set of
    technology it uses (its "technology stack") and to a supermajority
    of the users the project supports (so that users have ready access
    to the alternative).
    <sup>[<a href="#interfaces_current">interfaces_current</a>]</sup>

#### Build

*   <a name="build_standard_variables"></a>
    Build systems for native binaries MUST honor the relevant compiler and
    linker (environment) variables passed in to them (e.g., CC, CFLAGS,
    CXX, CXXFLAGS, and LDFLAGS) and pass them to compiler and linker
    invocations. A build system MAY extend them with additional flags;
    it MUST NOT simply replace provided values with its own.
    <sup>[<a href="#build_standard_variables">build_standard_variables</a>]</sup>

    *Details*: It should be easy to enable special build features like
    Address Sanitizer (ASAN), or to comply with distribution hardening
    best practices (e.g., by easily turning on compiler flags to do so).
    If no native binaries are being generated, select "N/A".

    *Rationale*: See
    <a href="https://github.com/ossf/best-practices-badge/issues/453">Build system should honor CC, CFLAGS, CXX, CXXFLAGS</a>

*   <a name="build_preserve_debug"></a>
    The build and installation system SHOULD preserve debugging information if
    they are requested in the relevant flags (e.g., "install -s" is not used).
    If there is no build or installation system (e.g.,
    typical JavaScript libraries), this is N/A.
    <sup>[<a href="#build_preserve_debug">build_preserve_debug</a>]</sup>

    *Details*: E.G., setting CFLAGS (C) or CXXFLAGS (C++) should create the
    relevant debugging information if those languages are used, and they
    should not be stripped during installation. Debugging information
    is needed for support and analysis, and also useful for measuring
    the presence of hardening features in the compiled binaries.

*   <a name="build_non_recursive"></a>
    The build system for the software produced by the project MUST NOT
    recursively build subdirectories if there are cross-dependencies
    in the subdirectories.
    <sup>[<a href="#build_non_recursive">build_non_recursive</a>]</sup>

    *Details*: The project build system's internal dependency information
    needs to be
    accurate, otherwise, changes to the project may not build correctly.
    Incorrect builds can lead to defects (including vulnerabilities).
    A common mistake in large build systems is to use a "recursive build"
    or "recursive make", that is,
    a hierarchy of subdirectories containing source files,
    where each subdirectory is independently built.
    Unless each subdirectory is fully independent, this is a mistake,
    because the dependency information is incorrect.

    *Rationale*:
    For more information, see
    <a href="https://web.archive.org/web/20200209034547/http://aegis.sourceforge.net/auug97.pdf">"Recursive Make Considered Harmful" by Peter Miller</a>
    (note that this incorrect approach can be used in any build system,
    not just <i>make</i>).
    Note that
    <a href="http://research.microsoft.com/en-us/um/people/simonpj/papers/ghc-shake/ghc-shake.pdf">"Non-recursive Make Considered Harmful"</a>
    agrees that recursive builds are bad; its argument is that
    for large projects you should use a tool other than make.
    In many cases it is better to automatically determine the dependencies,
    but this is not always accurate or practical, so we did not require
    that dependencies be automatically generated.

*   <a name="build_repeatable"></a>
    The project MUST be able to repeat the process of
    generating information from source files and get exactly
    the same bit-for-bit result.
    If no building occurs (e.g., scripting languages where the source code
    is used directly instead of being compiled), select "N/A".
    <sup>[<a href="#build_repeatable">build_repeatable</a>]</sup>

    *Details*: GCC and clang users may find the -frandom-seed option useful;
    in some cases, this can be resolved by forcing some sort order.
    More suggestions can be found at the
    <a href="https://reproducible-builds.org/">reproducible build</a> site.

    *Rationale*: This is a step towards having a
    <a href="https://reproducible-builds.org/">reproducible build</a>.
    This criterion is much easier to meet, because it does not require
    that external parties be able to reproduce the results - merely
    that the project can.
    Supporting full reproducible builds requires that projects provide
    external parties enough information about their build environment(s),
    which can be harder to do - so we have split this requirement up.
    See the <a href="#reproducible_build">reproducible build criterion</a>.

#### Installation

*   <a name="installation_common"></a>
    The project MUST provide a way for end-users to easily install and
    uninstall the software produced by the project
    using a commonly-used convention.
    <sup>[<a href="#installation_common">installation_common</a>]</sup>

    *Details*: Examples include using a language-level package manager (such as npm,
    pip, maven, or bundler), system-level package manager (such as apt-get
    or dnf), "make install/uninstall" (supporting DESTDIR), a container in
    a standard format, or a virtual machine image in a standard format. The
    installation and uninstallation process (e.g., its packaging) MAY be
    implemented by a third party as long as it is FLOSS.

*   <a name="installation_standard_variables"></a>
    The installation system for end-users MUST honor standard conventions for
    selecting the location where built artifacts are written to
    at installation time.  For example, if it installs
    files on a POSIX system it MUST honor the DESTDIR environment variable.
    If there is no installation system or no standard convention,
    select "N/A".
    <sup>[<a href="#installation_standard_variables">installation_standard_variables</a>]</sup>

    *Rationale*   : This supports capturing the artifacts (e.g., for analysis)
    without interfering with the build or installation system due to
    system-wide changes. See
    <a href="https://github.com/ossf/best-practices-badge/issues/455">DESTDIR honored at install time</a>
    This doesn't apply when there's no "installation" process, or
    when POSIX filesystems aren't supported during installation (e.g.,
    Windows-only programs).  See
    <a href="https://github.com/ossf/best-practices-badge/issues/453">Build system should honor CC, CFLAGS, CXX, CXXFLAGS</a>

*   <a name="installation_development_quick"></a>
    The project MUST provide a way for potential developers to quickly install all
    the project results and support environment necessary to make changes,
    including the tests and test environment.
    This MUST be performed with a commonly-used convention.
    <sup>[<a href="#installation_development_quick">installation_development_quick</a>]</sup>

    *Details*: This MAY be implemented using a generated container and/or
    installation script(s).
    External dependencies would typically be installed by invoking
    system and/or language package manager(s), per external_dependencies.

    *Rationale*:
    Recommended in the
    <a href="https://github.com/ossf/best-practices-badge/issues/473">NYC 2016 brainstorming session</a>.

### Security

*   <a name="implement_secure_design"></a>
    The project MUST implement secure design principles
    (from "know_secure_design"), where applicable.
    <sup>[<a href="#implement_secure_design">implement_secure_design</a>]</sup>

    *Details*:
    For example, the project results should have fail-safe defaults
    (access decisions should deny by default,
    and projects' installation should be secure by default).
    They should also have
    complete mediation (every access that might be limited must be
    checked for authority and be non-bypassable).
    Note that in some cases principles will conflict, in which case
    a choice must be made
    (e.g., many mechanisms can make things more complex, contravening
    "economy of mechanism" / keep it simple).
    If the project is not producing software, this may be N/A.

    *Rationale*:
    This was inspired by the
    <a href="https://github.com/ossf/best-practices-badge/issues/473">NYC 2016 brainstorming session</a>.

*   <a name="input_validation"></a>
    The project results MUST check
    all inputs from potentially untrusted sources to ensure
    they are valid (an *allowlist*), and reject invalid inputs,
    if there are any restrictions on the data at all.
    <sup>[<a href="#input_validation">input_validation</a>]</sup>

    *Details*:The project results MUST check
    all inputs from potentially untrusted sources to ensure
    they are valid (an *allowlist*), and reject invalid inputs,
    if there are any restrictions on the data at all.

*   <a name="hardening"></a>Hardening mechanisms
    SHOULD be used in the software produced by the project
    so that software defects are less likely to result in security
    vulnerabilities.<sup>[<a href="#hardening">hardening</a>]</sup>

    *Details*: Hardening mechanisms may include HTTP headers like Content
    Security Policy (CSP), compiler flags to mitigate attacks (such
    as -fstack-protector), or compiler flags to eliminate undefined
    behavior. For our purposes least privilege is not considered a hardening
    mechanism (least privilege is important, but separate).

#### Cryptography

*   <a name="crypto_algorithm_agility"></a>
    The project SHOULD support multiple
    cryptographic algorithms, so users can quickly switch if one is broken.
    Common symmetric key algorithms include AES, Twofish, and Serpent.
    Common cryptographic hash algorithm alternatives include SHA-2
    (including SHA-224, SHA-256, SHA-384 AND SHA-512) and SHA-3.
    <sup>[<a href="#crypto_algorithm_agility">crypto_algorithm_agility</a>]</sup>

    *Rationale*:
    The advantage of crypto agility is that if one crypto algorithm is
    broken, other algorithms can be used instead.
    Many protocols, including TLS and IPSEC, are specifically designed to
    support crypto agility.
    There is disagreement by some experts who argue that this
    negotiation can itself be a point of attack, and that
    people should instead simply choose and stay with with one good algorithm.
    The problem with this position is that no one can be certain about
    what that "one good algorithm" is; a new attack could be found at any time.
    See the discussion at
    <a href="https://github.com/ossf/best-practices-badge/issues/215">Remove requirement for supporting alternative crypto algorithms (crypto_alternatives)?</a>

*   <a name="crypto_credential_agility"></a>
    The project MUST support storing authentication credentials (such as
    passwords and dynamic tokens) and private cryptographic keys in files
    that are separate from other information (such as configuration files,
    databases, and logs), and permit users to update and replacement
    them without code recompilation. This is N/A if the project never
    processes authentication credentials and private cryptographic keys.
    (N/A allowed).
    <sup>[<a href="#crypto_credential_agility">crypto_credential_agility</a>]</sup>

*   <a name="crypto_used_network"></a>The
    software produced by the project
    SHOULD support secure protocols for all of its network
    communications, such as SSHv2 or later, TLS1.2 or later (HTTPS),
    IPsec, SFTP, and SNMPv3. Insecure protocols such as FTP, HTTP, telnet,
    SSLv3 or earlier, and SSHv1 SHOULD be disabled by default,
    and only enabled if the user specifically configures it.  (N/A allowed).
    <sup>[<a href="#crypto_used_network">crypto_used_network</a>]</sup>

*   <a name="crypto_tls12"></a>
    The software produced by the project SHOULD,
    if it supports or uses TLS, support at least TLS version 1.2.
    Note that the predecessor of TLS was called SSL.
    If the software does not use TLS,
    select "not applicable" (N/A).
    (N/A allowed).
    <sup>[<a href="#crypto_tls12">crypto_tls12</a>]</sup>

*   <a name="crypto_certificate_verification"></a>
    The software produced by the
    project MUST, if it supports TLS, perform TLS certificate verification
    by default when using TLS, including on subresources.
    If the software does not use TLS,
    select "not applicable" (N/A).
    (N/A allowed).
    <sup>[<a href="#crypto_certificate_verification">crypto_certificate_verification</a>]</sup>

    *Details*: Note that having incorrect TLS certificate
    verification is a common mistake. For more information, see
    <a href="http://crypto.stanford.edu/~dabo/pubs/abstracts/ssl-client-bugs.html">"The
    Most Dangerous Code in the World: Validating SSL Certificates in Non-Browser Software" by Martin Georgiev et al.</a>
    and
    <a href="https://blogs.gnome.org/mcatanzaro/2016/03/12/do-you-trust-this-application/">"Do you trust this application?" by Michael Catanzaro</a>.

*   <a name="crypto_verification_private"></a>
    The software produced by the project
    MUST, if it supports TLS, perform certificate verification before sending
    HTTP headers with private information (such as secure cookies).
    (N/A allowed).
    <sup>[<a href="#crypto_verification_private">crypto_verification_private</a>]</sup>

#### Secure Release

*   <a name="signed_releases"></a>
    The project MUST cryptographically sign
    releases of the project results intended for widespread use, and
    there MUST be a documented
    process explaining to users how they can obtain the public signing keys
    and verify the signature(s).
    The private key for these signature(s) MUST NOT
    be on site(s) used to directly distribute the software to the public.
    <sup>[<a href="#signed_releases">signed_releases</a>]</sup>

    *Details*:
    The project results include both source code and any
    generated deliverables where applicable (e.g., executables,
    packages, and containers).
    Generated deliverables MAY be signed separately from source code.
    These MAY be implemented as signed git tags
    (using cryptographic digital signatures).
    Projects MAY provide generated results separately
    from tools like git, but in those cases, the separate results
    MUST be separately signed.

    *Rationale*:
    This provides protection from compromised distribution systems.
    The public key must be accessible so that recipients can check the
    signature.  The private key must not be on sites(s) distributing the
    software to the public; that way, even if those sites are compromised,
    the signature cannot be altered.  This is sometimes called "code signing".
    A common way to implement this is by using GPG to sign the code,
    for example, the GPG keys of every person who signs releases
    could be in the project README.
    Node.js implements this via GPG keys in the README, but note that
    in the criterion we are intentionally more general:
    <a href="https://github.com/nodejs/node#release-team">Node.js Release Team</a>

*   <a name="version_tags_signed"></a>
    It is SUGGESTED that in the version control system,
    each important version tag (a tag that is part of a major
    release, minor release, or fixes publicly noted vulnerabilities)
    be cryptographically signed and verifiable as described in
    <a href="#signed_releases">signed_releases</a>.
    <sup>[<a href="#version_tags_signed">version_tags_signed</a>]</sup>

    *Details*: See also
    <a href="#signed_releases">signed_releases</a> and
    <a href="#version_tags">version_tags</a>.

    *Rationale*: This was suggested by Kevin W. Wall (@kwwall)
    in issue #709.

### Analysis

*   <a name="dependency_monitoring"></a>
    Projects MUST monitor or periodically check their external dependencies
    (including convenience copies) to detect known vulnerabilities, and
    fix exploitable vulnerabilities or verify them as unexploitable.
    <sup>[<a href="#dependency_monitoring">dependency_monitoring</a>]</sup>

    *Details*:
    This can be done using an origin analyzer / dependency checking tool
    such as
    <a href="https://www.owasp.org/index.php/OWASP_Dependency_Check">OWASP's Dependency-Check</a>,
    <a href="https://www.sonatype.com/nexus-auditor">Sonatype's Nexus Auditor</a>,
    <a href="https://www.blackducksoftware.com/products/protex">Black Duck's Protex</a>,
    <a href="http://www.protecode.com/">Synopsys' Protecode</a>, and
    <a href="https://github.com/rubysec/bundler-audit">Bundler-audit (for Ruby)</a>.
    Some package managers include mechanisms to do this.
    It is acceptable if the components' vulnerability cannot be exploited,
    but this analysis is difficult and it is sometimes easier to
    simply update or fix the part.

    *Rationale*:
    This must be monitored or periodically checked, because
    new vulnerabilities are continuously being discovered.

## Gold (passing+2) criteria

*   Achieve the lower silver (passing+1) badge.

### Upgrade of SHOULD and SUGGESTED (or not)

Here we list upgrades from silver.
We also identify criteria that were not upgraded,
but we discussed possibly upgrading them.

#### Upgrade: Basics

*   Upgrade bus_factor from SHOULD to MUST.
    "The project MUST have a "bus factor" of 2 or more.
    <sup>[<a href="#bus_factor">bus_factor</a>]</sup>

*   Unchanged:

    - dco
    - accessibility
    - floss_license_osi -
      "It is SUGGESTED that any required license(s) be <a
      href="https://opensource.org/licenses">approved by the Open Source
      Initiative (OSI).</a>"

    - english -
      "The project SHOULD include documentation in English and be able
      to accept bug reports and comments about code in English."

#### Upgrade: Change Control

*   Upgrade repo_distributed from SUGGESTED to MUST
    "The project MUST use a common distributed version control software
    (e.g., git or mercurial)."

*   Unchanged:

    - version_semver -
      "It is SUGGESTED that the <a href="http://semver.org">Semantic
      Versioning (SemVer) format</a> be used for releases."

    - version_tags -
      "It is SUGGESTED that projects identify each release within
      their version control system. For example, it is SUGGESTED
      that those using git identify each release using git tags."

#### Upgrade: Reporting

#### Upgrade: Quality

*   Upgrade test_invocation from SHOULD to MUST
    "A test suite MUST be invocable in a standard way for that language."

*   Upgrade test_continuous_integration from SUGGESTED to MUST.
    "A project MUST implement continuous integration,
    where new or changed code is frequently integrated into a central
    code repository and automated tests are run on the result."

    *Details*: This criterion is merely SUGGESTED at passing level.
    A subset of this criterion is required for silver; see
    <a href="#automated_integration_testing">automated_integration_testing</a>.
    Here, we require both the continuous check-in <i>and</i> its testing.
    In most cases this means that each developer who works full-time on
    the project integrates at least daily.

*   Unchanged:

    - build_common_tools -
      "It is SUGGESTED that common tools be used for building the software."

    - build_floss_tools -
      "The project SHOULD be buildable using only FLOSS tools."

    - test_most -
      "It is SUGGESTED that the test suite cover most (or ideally all)
      the code branches, input fields, and functionality."

      *NOTE*: Statement/branch coverage is covered separately; they are
      increased, so we are not changing the level of this one.

    - build_preserve_debug

#### Upgrade: Security

*   Upgrade hardening from SHOULD to MUST.
    "The project software MUST use hardening mechanisms
    so software defects are less likely to result in security
    vulnerabilities.  If the project does not produce software,
    choose N/A."

*   Upgrade crypto_used_network from SHOULD (NOT) to MUST (NOT).
    "The project MUST NOT use
    unencrypted network communication protocols (such as HTTP
    and telnet) if there is an encrypted equivalent (e.g., HTTPS/TLS and SSH),
    unless the user specifically requests or configures it.
    (N/A allowed).
    <sup>[<a href="#crypto_used_network">crypto_used_network</a>]</sup>

*   Upgrade crypto_tls12 from SHOULD to MUST.
    The project MUST, if it supports TLS, support at least TLS version 1.2.
    Note that the predecessor of TLS was called SSL.
    (N/A allowed).
    <sup>[<a href="#crypto_tls12">crypto_tls12</a>]</sup>

* Unchanged:

    - crypto_agility

    - crypto_call -
      "If the project software is an application or library, and
      its primary purpose is not to implement cryptography, then it
      SHOULD only call on software specifically designed to implement
      cryptographic functions; it SHOULD NOT re-implement its own."

    - crypto_pfs -
      "The project SHOULD implement perfect forward secrecy for key
      agreement protocols so a session key derived from a set of
      long-term keys cannot be compromised if one of the long-term keys
      is compromised in the future."

    - vulnerabilities_critical_fixed -
      "Projects SHOULD fix all critical vulnerabilities rapidly after
      they are reported."

      *NOTE*: We'd like this to always be true, but some vulnerabilities
      are hard to fix, so it's difficult to mandate this.
      We *could* require activities to actively work to fix it, and
      that is worth considering - but would that really help users?

#### Upgrade: Analysis

*   Upgrade dynamic_analysis from SUGGESTED to MUST.
     "The project MUST apply at least one dynamic analysis tool
     to any proposed major production release of the software before
     its release."

*   Upgrade dynamic_analysis_enable_assertions from SUGGESTED to SHOULD.
    "The project MUST include many run-time assertions in the software
    it produces, and those assertions MUST be checked during dynamic analysis."

    It was: "It is SUGGESTED that the software include many run-time assertions
    that are checked during dynamic analysis."

*   Unchanged:

    - static_analysis_often -
      "It is SUGGESTED that static source code analysis occur on every
      commit or at least daily."

### Basics

*   <a name="copyright_per_file"></a>
    The project MUST include a copyright statement in each source file,
    identifying the copyright holder (e.g., the [project name] contributors).
    <sup>[<a href="#copyright_per_file">copyright_per_file</a>]</sup>

    *Details*:
    This MAY be done by including the following inside a
    comment near the beginning of each file: "<tt>Copyright
    the [project name] contributors.</tt>". See
    <a href="https://www.linuxfoundation.org/blog/2020/01/copyright-notices-in-open-source-software-projects/"
    >"Copyright Notices in Open Source Software Projects" by Steve Winslow</a>.

    *Rationale*: This isn't legally required in most jurisdictions, per the
    Berne Convention.  For example, copyright notices have not been required
    in the US since 1979.
    On the other hand, this is not hard to add.
    <a href="http://ben.balter.com/2015/06/03/copyright-notices-for-websites-and-open-source-projects/">Ben Balter's "Copyright notices for open source projects"</a>
    provides some good arguments for why it *should* be included:
    "First, someone may want to use your work in ways not allowed
    by your license; notices help them determine who to ask for
    permission. Explicit notices can help you prove that you and your
    collaborators really are the copyright holders. They can serve to put
    a potential infringer on notice by providing an informal sniff test to
    counter the 'Oh yeah, well I didn’t know it was copyrighted'
    defense. For some users the copyright notice may suggest higher
    quality, as they expect that good software will include a notice...
    Git can track these things, but people may receive software outside
    of git or where the git history has not been retained."
    In addition, we have been informed by the Linux Foundation's SPDX
    community that having this information is extremely valuable for
    relicensing and for checking to determine if a copyrighted work is
    derived from another.  While version control systems do track versioning
    within a project, when files are copied between projects this information
    is often lost.  Having the copyright notice information helps
    those researching sources, e.g., if they wish to try
    to relicense something.

*   <a name="license_per_file"></a>
    The project MUST include a license statement in each source file.
    This MAY be done by including the following inside a comment
    near the beginning of each file:
    <a href="https://spdx.dev/ids/#how"><tt>SPDX-License-Identifier: [SPDX license expression for project]</tt></a>.
    <sup>[<a href="#license_per_file">license_per_file</a>]</sup>

    *Details*:
    This MAY also be done by including a statement in natural language
    identifying the license.
    The project MAY also include a stable URL
    pointing to the license text, or the full license text.
    Note that the criterion license_location requires the
    project license be in a standard location.
    See
    <a href="https://github.com/david-a-wheeler/spdx-tutorial">this SPDX tutorial</a>
    for more information about SPDX license expressions.
    Note the relationship with
    <a href="#copyright_per_file">copyright_per_file</a>, whose content
    would typically precede the license information.

    *Rationale*: Files are sometimes individually copied from one
    project into another.  Per-file license information increases the
    likelihood that the original license will be honored.
    SPDX provides a simple standard way to identify common licenses,
    without having to embed the full license text in each file;
    since this makes the criterion easier to do, we specifically mention it.
    Technically, the text after "SPDX-License-Identifier" is a
    SPDX license expression, not an identifier, but the tag
    "SPDX-License-Identifier" is what is used for backwards-compatibility.

#### Continuity

*   <a name="contributors_unassociated"></a>
    The project MUST have at least two unassociated significant contributors.
    <sup>[<a href="#contributors_unassociated">contributors_unassociated</a>]</sup>

    *Details*: Contributors are associated if they are paid to work
    by the same organization (as an employee or contractor)
    and the organization stands to benefit from the project's results.
    Financial grants do not count as being from the same organization
    if they pass through other organizations
    (e.g., science grants paid to different organizations
    from a common government or NGO source do not cause contributors
    to be associated).
    Someone is a significant contributor if they have made non-trivial
    contributions to the project in the past year.
    Examples of good indicators of a significant contributor are:
    written at least 1,000 lines of code, contributed 50 commits, or
    contributed at least 20 pages of documentation.

    *Rationale*: This reduces the risk of non-support if
    a single organization stops supporting the project as FLOSS.
    It also reduces the risk of malicious code insertion, since there
    is more independence between contributors.
    This covers the case where "two people work for company X, but
    only one is paid to work on this project" (because the non-paid person
    could still have many of the same incentives).
    It also covers the case where "two people got paid working for
    Red Cross for a day, but Red Cross doesn't use the project".

### Change Control

*   <a name="small_tasks"></a>
    The project MUST clearly identify small tasks that can be performed
    by new or casual contributors.
    <sup>[<a href="#small_tasks">small_tasks</a>]</sup>

    *Details*: This identification is typically done by marking selected issues
    in an issue tracker with one or more tags the project uses
    for the purpose, e.g.,
    <a href="http://up-for-grabs.net/#/">up-for-grabs</a>,
    <a href="http://www.firsttimersonly.com/">first-timers-only</a>,
    "Small fix", microtask, or IdealFirstBug.
    These new tasks need not involve adding functionality;
    they can be improving documentation, adding test cases,
    or anything else that aids the project and helps the contributor
    understand more about the project.

    *Rationale*:  Identified small tasks make it easier for new potential
    contributors to become involved in a project, and projects with more
    contributors have an increased likelihood of continuing.
    <a href="http://www.alluxio.org/docs/master/en/Contributing-to-Alluxio.html">Alluxio uses SMALLFIX</a>
    and
    <a href="https://github.com/zaproxy/zaproxy/issues?q=is%3Aopen+is%3Aissue+label%3AIdealFirstBug">ZAP uses IdealFirstBug</a>.
    This is related to criterion installation_development_quick.

*   <a name="require_2FA"></a>
    The project MUST require two-factor authentication (2FA)
    for developers for changing a central repository
    or accessing sensitive data (such as private vulnerability reports).
    This 2FA mechanism MAY use mechanisms without cryptographic mechanisms
    such as SMS, though that is not recommended.
    <sup>[<a href="#require_2FA">require_2FA</a>]</sup>

    *Rationale*: 2FA is used by Node.js and the Linux kernel projects.
    See
    <a href="https://www.linux.com/blog/linux-kernel-git-repositories-add-2-factor-authentication">"Linux Kernel Git Repositories Add 2-Factor Authentication" by Kontin Ryabitsev</a>
    and
    <a href="http://www.securityweek.com/linux-foundation-protects-kernel-git-repositories-2fa">"Linux Foundation Protects Kernel Git Repositories With 2FA" by Eduard Kovacs</a>.

*   <a name="secure_2FA"></a>
    The project's two-factor authentication (2FA) SHOULD use cryptographic
    mechanisms to prevent impersonation.  Short Message Service (SMS) based
    2FA, by itself, does not meet this criterion, since it is not encrypted.
    <sup>[<a href="#secure_2FA">secure_2FA</a>]</sup>

    *Details*: A 2FA mechanism that meets this criterion would be a
    Time-based One-Time Password (TOTP) application that
    automatically generates an authentication code that changes
    after a certain period of time.
    Note that
    <a href="https://help.github.com/articles/configuring-two-factor-authentication-via-a-totp-mobile-app/">GitHub supports TOTP</a>.

    *Rationale*: SMS is easier and lower cost for many people,
    but it also provides much weaker security.  It has been argued
    that SMS isn't really 2FA at all; we permit it, because it's better
    than nothing, but we don't recommend it because of its weaknesses.
    <a href="https://www.wired.com/2016/06/hey-stop-using-texts-two-factor-authentication/">So Hey You Should Stop Using Texts for Two-Factor Authentication</a>

### Reporting

(No new criteria)

### Quality

*   <a name="two_person_review"></a>
    The project MUST have at least 50% of all proposed modifications
    reviewed before release by a person other than the author,
    to determine if it is a worthwhile modification and
    free of known issues which would argue against its inclusion.
    <sup>[<a href="#two_person_review">two_person_review</a>]</sup>

    *Rationale*: Review can counter many problems.
    The percentage here could be changed; 100% would be great but untenable for
    many projects.  We have selected 50%, because
    anything less than 50% would mean that most changes could go unreviewed.
    See, for example, the
    <a href="https://www.kernel.org/doc/Documentation/SubmittingPatches">Linux Kernel's "Reviewer's statement of oversight"</a>.
    Note that the set of criteria allow people within the same organization
    to review each others' work; it is better to require different
    organizations to review each others' work, but in many situations
    that is not practical.

*   <a name="#code_review_standards"></a>
    The project MUST document its code review requirements, including
    how code review is conducted, what must be checked,
    and what is required to be acceptable.
    <sup>[<a href="#code_review_standards">code_review_standards</a>]</sup>

    *Details*: See also
    <a href="#two_person_review">two_person_review</a> and
    <a href="#contribution_requirements">contribution_requirements</a>

    *Rationale*: Code review is a cornerstone of quality and
    secure coding practices. Projects often seek new contributors but lack
    training and documentation to increase the number of reviewers. An
    increase in code reviewers lowers maintainer workload while aiding
    in meeting the badge requirement two_person_review.
    See
    https://github.com/ossf/best-practices-badge/issues/699
    from GeorgLink.

*   <a name="build_reproducible"></a>
    The project MUST have a
    <a href="https://reproducible-builds.org/">reproducible build</a>.
    (N/A allowed).
    <sup>[<a href="#build_reproducible">build_reproducible</a>]</sup>

    *Details*:
    A reproducible build means that multiple parties can independently
    redo the process of generating information from source files and
    get exactly the same bit-for-bit result.  If no building occurs
    (e.g., scripting languages where the source code is used directly
    instead of being compiled), select "N/A". In some cases, this can
    resolved by forcing some sort order. JavaScript developers may
    consider using npm shrinkwrap and webpack OccurrenceOrderPlugin.
    GCC and clang users may find the -frandom-seed option useful.
    The build environment (including the toolset) can often be defined for
    external parties by specifying the cryptographic hash of a specific
    container or virtual machine that they can use for rebuilding. The
    <a href="https://reproducible-builds.org/docs/">reproducible builds project
    has documentation</a>
    on how to do this.

    *Rationale*:
    If a project needs to be built but there is no working build system,
    then potential co-developers will not be able to easily contribute
    and many security analysis tools will be ineffective. Reproduceable
    builds counter malicious attacks that generate malicious executables,
    by making it easy to recreate the executable to determine if the result
    is correct. By itself, reproducible builds do not counter malicious
    compilers, but they can be extended to counter malicious compilers using
    processes such as diverse double-compiling (DDC).

#### Testing

*   <a name="test_statement_coverage90"></a>
    The project MUST have FLOSS automated test suite(s) that provide at least
    90% statement coverage if there is at least
    one FLOSS tool that can measure this criterion in the selected language.
    <sup>[<a href="#test_statement_coverage90">test_statement_coverage90</a>]</sup>

    *Rationale*: This increases the statement coverage requirement
    from the previous badge level, thus requiring even more
    thorough testing (by this measure).

*   <a name="test_branch_coverage80"></a>
    The project MUST have FLOSS automated test suite(s) that provide at least
    80% branch coverage if there is at least
    one FLOSS tool that can measure this criterion in the selected language.
    <sup>[<a href="#test_branch_coverage80">test_branch_coverage80</a>]</sup>

    *Rationale*: This adds another test coverage requirement,
    again requiring more thorough testing.
    A program with many one-armed "if" statements could achieve
    100% statement coverage but only 50% branch coverage
    (if the tests only checked the "true" branches).
    Branch coverage is probably the second most common test coverage
    measure (after statement coverage), and is often added when
    a stricter measure of tests is used.
    Branch coverage is widely (but not universally) implemented.

### Security

*   <a name="security_review"></a>
    The project MUST have performed a security review within the last 5 years.
    This review MUST consider the security requirements and security
    boundary.
    <sup>[<a href="#security_review">security_review</a>]</sup>

    *Details*:
    This MAY be done by the project members and/or an independent evaluation.
    This evaluation MAY be supported by static and dynamic analysis tools,
    but there also must be human review to identify problems (particularly
    in design) that tools cannot detect.

    *Rationale*:
    Security review is important, because security problems often come from
    subtle interactions of components.  Reviewing the system as a whole
    can help find these problems.
    Ideally this would be independent, but that often requires a lot of
    money, and we would rather have some review than none at all.
    We do not require a specific level of review; this is difficult to
    quantify given the different environments, requirements, and sizes
    of various projects.
    Kevin Wall noted, "If passing+2 is going to be the highest back level, I'd
    also like to see some sort of mandatory code inspection (possibly
    SAST assisted), and when applicable, some sort of DAST (for APIs,
    probably just fuzzing), where failed tests would have to be added
    to the regression test suite."
    It's difficult to get agreement on the details of what a security
    review must include, but we believe that the stated criteria would
    be agreed on.

*   <a name="hardened_site"></a>
    "The project website, repository (if accessible
    via the web), and download site (if separate) MUST include key hardening
    headers with nonpermissive values."
    <sup>[<a href="#hardened_site">hardened_site</a>]</sup>

### Analysis

(No new criteria)

## Improving the criteria

We are hoping to get good suggestions and feedback from the public;
please contribute!
Please
[post an issue](https://github.com/ossf/best-practices-badge/issues)
if you have comments on these criteria.

See <a href="./criteria.md">criteria</a> for the main current set of criteria.
You may also want to see the "<a href="./background.md">background</a>" file
for more information about these criteria,
and the "<a href="./implementation.md">implementation</a>" notes
about the BadgeApp application.

## See also

Project participation and interface:

* [CONTRIBUTING.md](../CONTRIBUTING.md) - How to contribute to this project
* [INSTALL.md](INSTALL.md) - How to install/quick start
* [governance.md](governance.md) - How the project is governed
* [roadmap.md](roadmap.md) - Overall direction of the project
* [background.md](background.md) - Background research
* [api](api.md) - Application Programming Interface (API), inc. data downloads

Criteria:

* [Criteria for passing badge](https://bestpractices.coreinfrastructure.org/criteria/0)
* [Criteria for all badge levels](https://bestpractices.coreinfrastructure.org/criteria)

Development processes and security:

* [requirements.md](requirements.md) - Requirements (what's it supposed to do?)
* [design.md](design.md) - Architectural design information
* [implementation.md](implementation.md) - Implementation notes
* [testing.md](testing.md) - Information on testing
* [assurance-case.md](assurance-case.md) - Why it's adequately secure (assurance case)
