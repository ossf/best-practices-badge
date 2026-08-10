# Test coverage

I'm thinking that perhaps we should add some test coverage measurements for higher-level badges (NOT for "passing").  However, there are many options, and a variety of pros and cons.  Below are some of my own thoughts; I'd like to hear others' thoughts.

Basically, I'm currently thinking about perhaps having a "passing+1" criterion for statement-coverage criterion of 80% or more.  For passing+2, perhaps have a branch coverage of 80% as well.  This coverage measure would be a union of all tests (including unit and system/integration), but only for tests that are themselves FLOSS (so they can get fixed!).  These are easily measured by a variety of tools, and applied in many places.  This is absolutely *not* fixed in stone – comments welcome.

--- David A. Wheeler

===================================

At the "passing" level we require automated testing, but we intentionally don't say how much testing is enough.  We instead require that they typically add more tests for major new functionality.  I think that's the right approach for "passing".  There is a rationale for this: It's much easier to add tests once a test framework has been established, so at the "passing" level we're ensuring projects are on the right path for enabling improvements to their automated test suite.

However – what should we do at higher badge levels?  I think we should expect some minimum kind of automated testing at higher levels.  What's more, that minimum shouldn't be some sort of ambiguous feel-good requirement.  Instead, we should have *some* kind of specific, quantifiable test coverage criteria to give an indication of how good the automated testing is.  To make it consistent, we'd need to pick a *specific* measure & define a minimum value for badging purposes.  There are complications, though, because there are a *lot* of ways to measure test coverage <https://en.wikipedia.org/wiki/Code_coverage> and there will always be reasons to debate any specific threshold.  Note that I am including *all* tests (unit and system/integration) together.

I believe the most common kinds of test coverage measurement are, in rough order of difficulty:

1. Statement coverage: % of lines|statements run by at least one test.
  This is what codecov.io does (they only count a line if it's *fully*
  executed).  Un-executable ("dead") code will reduce these scores –
  but that can also reveal problems like Apple's "goto fail; goto fail;"
  vulnerability <http://www.dwheeler.com/essays/apple-goto-fail.html>.
2. Branch coverage: % branches of each control structure (including if,
  case, for, while) executed.  SQLite achieves 100% branch coverage.
3. Decision coverage: For 100% decision coverage, every point of entry
  and exit in the program has been invoked at least once, and every
  decision (branch) in the program has taken all possible outcomes at
  least once.  DO-178B (an avionics standard) requires, if system failure
  is "hazardous", 100% decision coverage and 100% statement coverage.
  <https://en.wikipedia.org/wiki/Modified_condition/decision_coverage>
4. Modified condition/decision coverage (MC/DC); this is used
  in safety-critical applications (e.g., for avionics software).
  DO-178B requires "catastrophic" effect software to have 100% modified
  condition/decision coverage and 100% statement coverage.  SQLite achieves
  100% MC/DC too.

All of these are structural testing measures, and thus can only measure
what *is* in the code.  None can detect by themselves, for example,
if a project *failed* to include some test or information in your code.
There are no obvious solutions to that, though.

Almost every language has FLOSS tools to measure the first two, at least (e.g., GCC users can use gcov/lcov).  The last one is common in safety-critical software, but it's a really harsh requirement that is less well-supported, so I think we can omit MC/DC for the badging project.  There are other measures, but since they're less-used, too coarse (e.g., function coverage), or hard to consistently apply across FLOSS projects (e.g., requirements statement coverage).

SQLite is a big advocate of testing; I quote: "The developers of SQLite have found that full coverage testing is an extremely effective method for locating and preventing bugs. Because every single branch instruction in SQLite core code is covered by test cases, the developers can be confident that changes made in one part of the code do not have unintended consequences in other parts of the code. The many new features and performance improvements that have been added to SQLite in recent years would not have been possible without the availability full-coverage testing. Maintaining 100% MC/DC is laborious and time-consuming. The level of effort needed to maintain full-coverage testing is probably not cost effective for a typical application. However, we think that full-coverage testing is justified for a very widely deployed infrastructure library like SQLite, and especially for a database library which by its very nature 'remembers' past mistakes."  Note that while SQLite is FLOSS, the test suite that yields 100% branch coverage and 100% MC/DC is not.  More information: <https://github.com/ossf/best-practices-badge/blob/main/docs/background.md>

I think at "passing+1" we should perhaps focus on statement coverage.  It seems to be the more common "starter" measure for test coverage, e.g., it's what codecov.io uses.  It's also easier for people to see (it's sometimes not obvious where branches are, especially for novice programmers).  There's also an easy justification: Clearly, if your tests aren't even *running* many of the program's statements, you don't have very good tests.

Next question: How good is "good enough"?  Boris Beizer would say that anything less than 100% is unacceptable.  But I don't think that must be the answer.  There are many ways to determine if a program is correct – testing is only one of them.  Some conditions are hard to create during testing, and the return-on-investment to get those last few percentages is arguably not worth it.  The time working to get 100% statement coverage might be much better spent on checking the results more thoroughly (which statement coverage does *not* measure).

The paper "Minimum Acceptable Code Coverage" by Steve Cornett <http://www.bullseye.com/minimum.html> claims, "Code coverage of 70-80% is a reasonable goal for system test of most projects with most coverage metrics. Use a higher goal for projects specifically organized for high testability or that have high failure costs. Minimum code coverage for unit testing can be 10-20% higher than for system testing… Empirical studies of real projects found that increasing code coverage above 70-80% is time consuming and therefore leads to a relatively slow bug detection rate. Your goal should depend on the risk assessment and economics of the project… Although 100% code coverage may appear like a best possible effort, even 100% code coverage is estimated to only expose about half the faults in a system. Low code coverage indicates inadequate testing, but high code coverage guarantees nothing."

"TestCoverage" by Martin Fowler (17 April 2012) <http://martinfowler.com/bliki/TestCoverage.html> points out the problems with coverage measures.  he states that "Test coverage is a useful tool for finding untested parts of a codebase. Test coverage is of little use as a numeric statement of how good your tests are… The trouble is that high coverage numbers are too easy to reach with low quality testing… If you are testing thoughtfully and well, I would expect a coverage percentage in the upper 80s or 90s. I would be suspicious of anything like 100%... Certainly low coverage numbers, say below half, are a sign of trouble. But high numbers don't necessarily mean much, and lead to ignorance-promoting dashboards."

It's interesting to look at the defaults of codecov.io <http://docs.codecov.io/docs/coverage-configuration>.  They define 70% and below as red, 100% as perfectly green, and anything between 70..100 as a range between red and green. This renders ~80% as yellow, and somewhere between ~85% and 90% it starts looking pretty green.

I'm intentionally not separating unit test from integration/system test.  Which approach is appropriate seems very specific to the technology and circumstance.  From the point-of-view of users, if it's tested, it's tested.

So for passing+1 if we set a statement-coverage criterion of 80% (or around that), we'd have an easy-to-measure and clearly quantified test coverage criterion.  It's true that bad test suites can meet that (e.g., by running the code in tests without checking for anything), but I would expect any good automated test suite to meet that criterion (or something like it).  So it'd still weed out projects that have poor tests.

Adding (or using instead) branch coverage, or adding a branch coverage criterion for passing+2, would also seem sensible to me.  Again, say 80%.

We could also add a warning that just adding tests to make the numbers go up, without thinking, is not a good idea.  Instead, they should *think* about their tests – including what is *not* getting tested.  Many testing experts I know mirror the concerns of Martin Fowler – it's easy to game the system by writing "tests" that run a lot of code without seriously checking anything.  I agree that test coverage measures can be misapplied or gamed… but most other measurements can also be misapplied and gamed.  Perhaps the best antidote to that is transparency.  If it's an OSS project, and the tests are themselves OSS, then poor tests become visible & subject to comment/ridicule.  This implies that perhaps we should require these requirements to be met by a FLOSS test suite – you can have other test suites, but people can't necessarily see or fix them.

Thoughts?

See: <https://lists.coreinfrastructure.org/pipermail/cii-badges/2016-December/000350.html>

Note that Ruby doesn't support branch coverage testing.
