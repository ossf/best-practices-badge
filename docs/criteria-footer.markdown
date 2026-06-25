
## A note on good cryptographic practices

*Note*: These criteria do not always apply because some software has no
need to directly use cryptographic capabilities.
A "project security mechanism" is a security mechanism provided
by the delivered project's software.

## Non-criteria

We do *not* require any specific products or services, and in
general do not require any particular technology.
In particular, we do *not* require
proprietary tools, services, or technology,
since many [free software](https://www.gnu.org/philosophy/free-sw.en.html)
developers would reject such criteria.
For example, we intentionally do *not* require git or GitHub.
We also do not require or forbid any particular programming language.
We do require that additional measures be taken for certain
*kinds* of programming languages, but that is different.
This means that as new tools and capabilities become available,
projects can quickly switch to them without failing to meet any criteria.

We *do* provide guidance and help for common cases.
The criteria *do* sometimes identify
common methods or ways of doing something
(especially if they are FLOSS), since that information
can help people understand and meet the criteria.
We also created an "easy on-ramp" for projects using git on GitHub,
since that is a common case.
But note that nothing *requires* git or GitHub.
We would welcome good patches that help provide an "easy on-ramp" for
projects on other repository platforms;
GitLab was one of the first projects with a badge.

We avoid requiring, at the passing level, criteria that would be
impractical for a single-person project, e.g., something that requires
a significant amount of money.
Many FLOSS projects are small, and we do not want to disenfranchise them.

We do not plan to require active user discussion within a project.
Some highly mature projects rarely change and thus may have little activity.
We *do*, however, require that the project be responsive
if vulnerabilities are reported to the project (see above).

## Uniquely identifying a project

One challenge is uniquely identifying a project.
Our Rails application gives a unique id to each new project, so
we can use that id to uniquely identify project entries.
However, that doesn't help people who searching for the project
and do not already know that id.

The *real* name of a project, for our purposes, is the
URL for its repository, and where that is not available, the
project "front page" URL can help find it.
Most projects have a human-readable name, and we provide a search
mechanisms, but these names are not enough to uniquely identify a project.
The same human-readable name can be used for many different projects
(including project forks), and the same project may go by many different names.
In many cases it will be useful to point to other names for the project
(e.g., the source package name in Debian, the package name in some
language-specific repository, or its name in OpenHub).

In the future we may try to check more carefully that a user can
legitimately represent a project.
For the moment, we primarily focus on checking if GitHub repositories
are involved; there are ways to do this for other situations if that
becomes important.

Non-admin users cannot edit the repo URL once one is entered.
(Exception: they can upgrade http to https.)
If they could change the repo URL,
they might fool people into thinking they controlled
a project that they did not.
That said, creating a bogus row entry does not really help someone very
much; what matters to the software
is the id used by the project when it refers to its badge,
and the project determines that.

## Why have criteria?

The paper [Open badges for education: what are the implications at the
intersection of open systems and badging?](http://www.researchinlearningtechnology.net/index.php/rlt/article/view/23563)
identifies three general reasons for badging systems (all are valid for this):

1. Badges as a motivator of behavior.  We hope that by identifying
   best practices, we'll encourage projects to implement those
   best practices if they do not do them already.
2. Badges as a pedagogical tool.  Some projects may not be aware
   of some of the best practices applied by others,
   or how they can be practically applied.
   The badge will help them become aware of them and ways to implement them.
3. Badges as a signifier or credential.
   Potential users want to use projects that are applying best
   practices to consistently produce good results; badges make it easy
   for projects to signify that they are following best practices,
   and make it easy for users to see which projects are doing so.

We have chosen to use self-certification, because this makes it
possible for a large number of projects (even small ones) to
participate.  There's a risk that projects may make false claims,
but we think the risk is small, and users can check the claims for themselves.

## Improving the criteria

We are hoping to get good suggestions and feedback from the public;
please contribute!

We launched with a single badge level called *passing*.
For higher level badges, see [other](./other.md).

You may also want to see the "[background](./background.md)" file
for more information about these criteria,
and the "[implementation](./implementation.md)" notes
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

* [Criteria for passing badge](https://www.bestpractices.dev/criteria/0)
* [Criteria for all badge levels](https://www.bestpractices.dev/criteria)

Development processes and security:

* [requirements.md](requirements.md) - Requirements (what's it supposed to do?)
* [design.md](design.md) - Architectural design information
* [implementation.md](implementation.md) - Implementation notes
* [testing.md](testing.md) - Information on testing
* [security.md](security.md) - Why it's adequately secure (assurance case)
