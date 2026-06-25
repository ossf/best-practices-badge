# Roadmap

The OpenSSF Best Practices badge project is essentially in a
"sustainment" mode.  That doesn't mean the project is static,
it just means that we've already achieved our "big" objectives.
This is similar to the situation of the Linux kernel, which is
not static either but has also achieved its original key goals.

In particular, we've met our original key objectives:

* created a set of tiered criteria (starting with 1 level),
* a website so people can fill in those criteria and receive a badge
* automation to help fill in some information
* internationalization

## 2026 goal: analyze baseline vs. metal

We implement OpenSSF baseline *and* the metal criteria.
This year we intend to compare them and see if we can further merge them.
This will involve many discussions.
Our current expectation is that the metal criteria will eventually
become a superset of the baseline criteria.

Once we've decided what to do, we expect to implement changes in the
metal series and give projects time to adjust to them; this is
likely to be the key task in 2027.

Beyond, this we focus on sustainment.

## Handle pull requests and issues

At this point, we are primarily driven by specific pull requests and
issues, which have to be prioritized.

Since pull requests take much less time for us to process (in general),
and represent a more significant investment of time by the proposer
(so at least the proposer considers them important), they will tend to
be much more likely to be accepted.

Issues marked as "next" are also considered higher priority.

## General changes to expect in the future

The following are general goals in the 1-2 year horizon:

* Continue to let others know about the badging program
* Encourage projects to get & display a badge and/or pursue higher levels
* Add more locales
* Update the criteria annually as more is learned
* Reduce monthly hosting costs (without hurting user experience)

The timeframe for many of these will depend on how much other people
provide support for them (this is especially true for adding new locales).

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
