# Vetting of Best Practices badges

<!-- SPDX-License-Identifier: (MIT OR CC-BY-3.0+) -->

Here we discuss how we vet best practices badges.
To give context, we first discuss other vetting approaches
and why there was a need for an alternative.
We then discuss how we actually vet the badges.

## Other vetting approaches

There are many ways to evaluate projects from a security vantage point.
For example:

* The Common Criteria for Information Technology Security Evaluation
  (abbreviated as Common Criteria or CC) is
  an international standard (ISO/IEC 15408) for computer security certification.
  The Common Criteria is a framework within which security functional and
  assurance requirements (SFRs and SARs respectively) can be specified in
  Protection Profiles (PPs).
  Suppliers can then claim what requirements they meet in a Security Target
  (ST), which could cover 0 or more Protection Profile requirements.
  Typically testing labs evaluate products to determine
  whether they meet the claims stated in their STs.
  Going through a testing lab takes many months (often more than a year)
  and requires a significant amount of money to pay the testing lab for
  each product.
* The Federal Information Processing Standard (FIPS) Publication 140-2
  (FIPS PUB 140-2) is a U.S. government computer security standard used
  to approve cryptographic modules.
  It is designed to only evaluate cryptographic modules, and again
  requires a significant amount of time and money to pass.
* Many companies provide services to evaluate software for its security
  and/or evaluate a software development organization.
  Again, these services typically cost a significant amount of time and money.

## Need for an alternative

There are literally millions of free / libre / open source software (FLOSS)
programs.
Many are not funded by larger organizations and do not have a revenue stream
(they are simply available for free).
As a result, they simply cannot afford to pay a
significant (or any) amount of money to go through an evaluation.
Many are primarily developed by a single individual, so security evaluations
that require lengthy interactions with developers or lengthy specialized
documentation will not work.

In many situations the software changes quickly,
while software-based evaluations generally
only evaluate a specific version of the software.
As a result, evaluations can end up only reporting about historical software,
not the software actually in use.

Finally, many security evaluation processes were originally designed
to evaluate proprietary software.
While they *can* be used to evaluate
free / libre / open source software (FLOSS),
they do not take advantage of the many differences between them.
For example, a significant advantage of FLOSS is that if done well
it permits worldwide security review,
both by humans and a variety of analysis tools.
Yet many evaluation processes do not take into account whether or not
efforts have been made to enable this this review.

This is not to say that FLOSS *cannot* be evaluated using these methods.
FLOSS systems (such as Linux systems and OpenSSL)
have repeatedly passed CC evaluations, FIPS 140-2 evaluations,
and various specialized evaluations.
However, in many cases FLOSS is a poor fit for these other evaluation
mechanisms.
This is a problem, because in many areas FLOSS is a leading or at least
major solution.

We believe there is a need for an approach that helps FLOSS be secure
that can scale up to the millions of FLOSS programs available today and
takes advantage of the distinctive nature of FLOSS.

## OpenSSF Badging approach to vetting

The best practices badge approach is based on self-certification.
There are literally millions of OSS projects (we counted), so it's unlikely
anyone could afford to pay for traditional evaluation processes for even a
majority of them. We also think requiring fees for every OSS project would
mean the vast majority of projects would not participate. In addition,
we focused on "what is important" regardless of whether or not it's
easy to automate (though we prefer criteria that can be automatically
determined where that is reasonable).
Self-certification best resolved these issues.

The problems of self-certification are well-known, so we have various
mechanisms to mitigate its problems:

* Automation. We work to automatically determine answers, and we will not accept answers where can confirm with high confidence that the answer is false. E.g., if you use "http://" for your project or repo URLs, your project fails the criterion `sites_https`. That means that the badge is not strictly self-certification, instead, the badge is merely based on it. In the long term we hope to implement more automation. The file criteria/criteria.yml documents how we think various criteria could be automated. Patches to improve automation are joyfully welcomed.  That said, as noted above, we want to focus on what criteria are *important* - even if we currently require people to determine the answer.
* Public display of answers (for criticism).  People are far more willing to lie in private than in public. It's been long observed that
 “Sunlight is said to be the best of disinfectants; electric light the most efficient policeman.” See [Louis Brandeis, 1914, “What Publicity Can Do”, in Other People's Money and How the Bankers Use It](http://louisville.edu/law/library/special-collections/the-louis-d.-brandeis-collection/other-peoples-money-chapter-v)
* Reduced incentives. We intentionally reduce the incentives for people to create false information.  For example, all links are specifically marked as `rel="nofollow ugc"`; this greatly reduces the incentive to do Search Engine Optimization (SEO) hacking by creating nonsense projects.
* Notifications and spot-checks. We (the managers of the badging process) get notifications of various events or suspicious claims for review. Anyone can post an issue disputing a claim, and again, we can check the claim.
* Answers can be overridden by the Linux Foundation (LF) if false. Those who repeatedly falsify information can be kicked off. We do not do this lightly, but the fact that we can reduces the incentive to try.
* FLOSS.  The badging site is itself FLOSS, so if others can identify ways to improve it and even propose implementations of it.

Nothing is perfect; we believe that the approach we're taking is
improving the FLOSS available to all, and that is the goal.

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
