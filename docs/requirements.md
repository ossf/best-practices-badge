# Requirements

<!-- SPDX-License-Identifier: (MIT OR CC-BY-3.0+) -->

We have implemented a simple web application called "BadgeApp" that
quickly captures self-assertion data, evaluates criteria automatically
when it can, and provides badge information.
Our emphasis is on keeping the program relatively *simple*.

This file provides information on the basic high-level requirements
of the BadgeApp.  Putting them here will hopefully make certain choices
clear, and also perhaps eliminate useless repeat arguments.
In a few cases we briefly note how we currently meet the requirements.

In this document we'll use the term "open source software" (OSS),
and treat Free/Libre and Open Source Software (FLOSS) as a synonym.
A "badge entry" is the full set of badge data about a project; a
"badge" is the small image showing the summarized status of a project.

## High-level requirements

The BadgeApp web application MUST:

1. **Support basic login and editing functionality.**
   The application MUST
   allow users to sign in (login) using GitHub or an email account.
   The application MUST allow authenticated users (and only
   authenticated users) to create project badge entries, edit those
   badge entries (if authorized), and log out.
   The system MUST calculate and show a project's progress
   towards getting a badge, and MUST support multiple badge levels
   with their own criteria.
   When users edit a badge entry and have JavaScript enabled, the system MUST
   provide immediate feedback on how their changes are affecting progress
   towards getting a badge.
   The application MUST allow anyone (authenticated or not) to
   see current badge entries and badges.
   Admins MUST be able to edit or remove arbitrary projects
   (e.g., to deal with spam and false claims).
2. **Meet its own criteria.**
   This implies that it MUST be open source software
   (OSS).  We release the source code
   under the MIT license, which achieves this.
3. **Be capable of being developed and run using *only* OSS.**
   This means that all *required* dependencies MUST be OSS
   (and we *strongly* prefer dependencies with OSI-approved licenses).
   It may *run* on proprietary software; portability improvements are welcome.
   It's also fine if it can use proprietary services, as long as it can
   *run* without them.
   See [CONTRIBUTING.md](../CONTRIBUTING.md) for more.
4. **Support modern web browsers.**
   Support users of relatively-modern widely used web browsers, including
   Chrome, Firefox, Safari, and Internet Explorer version 10 and up.
   We expect Internet Explorer pre-10 users will use a different browser.
   We expect to drop support for Internet Explorer in the future.
5. **NOT require JavaScript to be enabled.**
   JavaScript MUST NOT be required on the user web browser for basic
   functions, since some security-conscious people disable JavaScript.
   Instead, the system MUST support graceful degradation.
   Many features will work much better if JavaScript is enabled, but the
   basic functions MUST work without it (e.g., be able to see and
   edit project entries).  Requiring CSS is fine.
6. **Support web browsers on laptops, desktops, and mobile.**
   Users must be supported if they are running web browsers on
   Linux (Ubuntu, Debian, Fedora, Red Hat Enterprise Linux),
   Microsoft Windows, or Apple MacOS, Android, and iOS.
   This implies that it MUST have a responsive design.
   We expect users will *edit* information primarily on larger screens,
   but they need to be *able* to edit on small screens.
7. **NOT require projects use a particular hosting environment or VCS.**
   Here "VCS" means "version control system" (such as git).
   In particular, the system MUST NOT require that
   projects or users use either GitHub or git.
   We do use GitHub and git to *develop* BadgeApp (that's different).
8. **Automatically fill in some criteria where it can on GitHub projects.**
   Automating filling in data is a never-ending
   process of refinement.
   Thus, we intend to fill a few to start, and then
   add more automation over time.
   At a minimum we intend to automate projects hosted on GitHub, but
   we welcome automation for projects hosted elsewhere.
9. **Be secure.**  See the separate
   [security](security.md) document for more about security, including
   its requirements.
10. **Protect users and their privacy.**  In particular, we MUST
   comply with the EU General Data Protection Regulation (GDPR).
   We don't expose user email addresses,
   and we don't expose user activities to unrelated sites
   (including social media sites) without that user's consent.
   In particular, we do not include "like" buttons that reveal that the
   user viewed that particular page.
11. **Be accessible.**
   We strive to comply with the
   <a href="https://www.w3.org/TR/WCAG20/">Web Content Accessibility
   Guidelines (WCAG 2.0)</a> (especially at the A and AA level).
12. **Support internationalization/localization.**
13. **Be reliable.**
   As a matter of policy we require that our test suite
   have at least 90% statement coverage (in practice we exceed that),
   the development process MUST use a variety of tools
   to help detect problems early, and there MUST be a continuous
   integration platform (to immediately test check-ins).
14. **Perform well.**  Users avoid slow sites.
   Our primary pages (front page, login, project list, show or edit
   project) must perform reasonably well.
   The front page MUST get to "first interactive" use for a new user
   in less than 3 seconds on average on a high-speed link
   (e.g. as measured by https://www.webpagetest.org given Dulles, Virginia
   as the test location).  In practice we achieve much better than this;
   see the design document discussion about performance.
15. **NOT require a large amount of effort to develop or maintain.**
   We choose systems that easy to develop and maintain in, such as
   Ruby on Rails, to do this.
16. **Record aggregate statistics.**
   We need these aggregate statistics to monitor the
   status of the badging project, and focus primarily on projects.
   These are aggregations, to help preserve user privacy.
   See `/project_stats` and `/criteria` for these statistics.

We do *not* need to support offline editing of data.

## Specific requirements

There are many specific requirements.
Instead of having a huge unread requirements document,
specific requirements are normally proposed and processed via the
[GitHub issue tracker](https://github.com/ossf/best-practices-badge/issues).
See [CONTRIBUTING](../CONTRIBUTING.md) for more about our process.

## See also

Project participation and interface:

* [CONTRIBUTING.md](../CONTRIBUTING.md) - How to contribute to this project
* [INSTALL.md](INSTALL.md) - How to install/quick start
* [governance.md](governance.md) - How the project is governed
* [roadmap.md](roadmap.md) - Overall direction of the project
* [background.md](background.md) - Background research
* [api](api.md) - Application Programming Interface (API), inc. data downloads

Criteria:

* [Criteria for passing badge](https://www.bestpractices.dev/criteria/0)
* [Criteria for all badge levels](https://www.bestpractices.dev/criteria)

Development processes and security:

* [requirements.md](requirements.md) - Requirements (what's it supposed to do?)
* [design.md](design.md) - Architectural design information
* [implementation.md](implementation.md) - Implementation notes
* [testing.md](testing.md) - Information on testing
* [assurance-case.md](assurance-case.md) - Why it's adequately secure (assurance case)
