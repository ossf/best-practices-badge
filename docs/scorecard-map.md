# Scorecard Map to Best Practices Badge

This is a map from the
[OpenSSF Scorecard checks](https://github.com/ossf/scorecard/blob/main/docs/checks.md)
to the
[OpenSSF Best Practices badge criteria](https://www.bestpractices.dev/en/criteria?details=true).

Scorecard has 19 checks.
[The OpenSSF best practices criteria statistics](https://www.bestpractices.dev/en/criteria_stats)
has 67 criteria for passing, 48 new criteria for silver, and 14 new criteria
for gold; adding 1 for the existence of the badge leaves 130 total criteria.
Looking at the Scorecard checks, in sum:

* Starting from Scorecard, there are 14 direct maps, 5 partial maps, and 5 scorecard criteria with no mappings at all. (In some cases a single Scorecard criteria maps to more than one Best Practices Badge criteria.)
* Starting from the Best practices badge, there are 19 direct or partial mappings, so 111 criteria are not covered by Scorecard.

## Binary-Artifacts

> This check determines whether the project has generated executable (binary)
artifacts in the source repository.
>
> Including generated executables in the source repository increases user risk.
Many programming language systems can generate executables from source code
(e.g., C/C++ generated machine code, Java `.class` files, Python `.pyc` files,
and minified JavaScript). Users will often directly use executables if they are
included in the source repository, leading to many dangerous behaviors."

No obvious mapping to the OpenSSF Best Practices badge.

## Branch-Protection

> This check determines whether a project's default and release branches are
protected with GitHub's [branch protection](https://docs.github.com/en/github/administering-a-repository/defining-the-mergeability-of-pull-requests/about-protected-branches) settings.
>
> Branch protection allows maintainers to define rules that enforce
certain workflows for branches, such as requiring review or passing certain
status checks before acceptance into a main branch, or preventing rewriting of
public history.

This is a partial map to OpenSSF best practices badge `two_person_review`:

> "The project MUST have at least 50% of all proposed modifications reviewed before release by a person other than the author, to determine if it is a worthwhile modification and free of known issues which would argue against its inclusion {Met justification."

## CI-Tests

> This check tries to determine if the project runs tests before pull requests are merged. It is currently limited to repositories hosted on GitHub, and does not support other source hosting repositories (i.e., Forges).
>
> Running tests helps developers catch mistakes early on, which can reduce the
number of vulnerabilities that find their way into a project.

This maps to the OpenSSF best practices badge `test_continuous_integration`:

> The project MUST implement continuous integration, where new or changed code is frequently integrated into a central code repository and automated tests are run on the result.

## CII-Best-Practices

> This check determines whether the project has earned an [OpenSSF (formerly CII) Best Practices Badge](https://www.bestpractices.dev/) at the passing, silver, or gold level.
>
> The OpenSSF Best Practices badge indicates whether or not that the project uses a set of security-focused best development practices for open
source software. The check uses the URL for the Git repo and the OpenSSF Best Practices badge API.

This maps to the OpenSSF Best Practices badge as a whole.

## Code-Review

> This check determines whether the project requires human code review
before pull requests (merge requests) are merged.
>
> Reviews detect various unintentional problems, including vulnerabilities that can be fixed immediately before they are merged, which improves the quality of the code. Reviews may also detect or deter an attacker trying to insert malicious code (either as a malicious contributor or as an attacker who has subverted a contributor's account), because a reviewer might detect the subversion.

This is a partial map to OpenSSF best practices badge `two_person_review`:

> "The project MUST have at least 50% of all proposed modifications reviewed before release by a person other than the author, to determine if it is a worthwhile modification and free of known issues which would argue against its inclusion {Met justification."

Note that many OSS projects have only one maintainer, where this is
not practical to implement. The best practices badge doesn't require
review of every pull request/merge request.

## Contributors

> This check tries to determine if the project has recent contributors from multiple organizations (e.g., companies). It is currently limited to repositories hosted on GitHub, and does not support other source hosting repositories (i.e., Forges).
>
> The check looks at the `Company` field on the GitHub user profile for authors of recent commits. To receive the highest score, the project must have had contributors from at least 3 different companies in the last 30 commits; each of those contributors must have had at least 5 commits in the last 30 commits.

This maps to OpenSSF Best Practices badge (gold) `contributors_unassociated`:

> The project MUST have at least two unassociated significant contributors.

## Dangerous-Workflow

> This check determines whether the project's GitHub Action workflows has dangerous code patterns. Some examples of these patterns are untrusted code checkouts, logging github context and secrets, or use of potentially untrusted inputs in scripts.  The following patterns are checked:
>
>* Untrusted Code Checkout: This is the misuse of potentially dangerous triggers.  This checks if a `pull_request_target` or `workflow_run` workflow trigger was used in conjunction with an explicit pull request checkout...
>>
>* Script Injection with Untrusted Context Variables: This pattern detects whether a workflow's inline script may execute untrusted input from attackers....

No obvious mapping to the OpenSSF Best Practices badge.

## Dependency-Update-Tool

> This check tries to determine if the project uses a dependency update tool [specifically dependabot and a few others].
>
> Out-of-date dependencies make a project vulnerable to known flaws and prone to attacks.  These tools automate the process of updating dependencies by scanning for outdated or insecure requirements, and opening a pull request to update them if found.
> This check can determine only whether the dependency update tool is enabled; it does not ensure that the tool is run or that the tool's pull requests are merged.

This maps to OpenSSF Best Practices badge `dependency_monitoring`:

> Projects MUST monitor or periodically check their external dependencies (including convenience copies) to detect known vulnerabilities, and fix exploitable vulnerabilities or verify them as unexploitable.

## Fuzzing

> This check tries to determine if the project uses
[fuzzing](https://owasp.org/www-community/Fuzzing)...
>
> Note: A project that fulfills this criterion with other tools may still receive a low score on this test. There are many ways to implement fuzzing, and it is challenging for an automated tool like Scorecard to detect them all. A low score is therefore not a definitive indication that the project is at risk.

This maps to OpenSSF Best Practices badge `dynamic_analysis`:

> (passing) It is SUGGESTED that at least one dynamic analysis tool be applied to any proposed major production release of the software before its release.
>
> (gold) The project MUST apply at least one dynamic analysis tool to any proposed major production release of the software produced by the project before its release.

This is related to OpenSSF Best Practices badge `dynamic_analysis_unsafe` and `dynamic_analysis_enable_assertions` that increase its effectiveness, but these aren't really mappings in any sense.

## License

> This check tries to determine if the project has published a license. It works by using either hosting APIs or by checking standard locations for a file named according to common conventions for licenses.
>
> A license can give users information about how the source code may or may not be used. The lack of a license will impede any kind of security review or audit and creates a legal risk for potential users.

This maps to OpenSSF Best Practices badge `license_location`:

> The project MUST post the license(s) of its results in a standard location in their source repository.

There's some relation to the OpenSSF Best Practices badge criteria
`floss_license` and `floss_license_osi` but they aren't the same thing.

## Maintained

> This check determines whether the project is actively maintained. If the project is archived, it receives the lowest score. If there is at least one commit per week during the previous 90 days, the project receives the highest score.  If there is activity on issues from users who are collaborators, members, or owners of the project, the project receives a partial score.
>
> A project which is not active might not be patched, have its dependencies patched, or be actively tested and used. However, a lack of active maintenance is not necessarily always a problem. Some software, especially smaller utility functions, does not normally need to be maintained.  For example, a library that determines if an integer is even would not normally need maintenance unless an underlying implementation language definition changed. A lack of active maintenance should signal that potential users should investigate further to judge the situation.
>
> This check will only succeed if a Github project is >90 days old. Projects
that are younger than this are too new to assess whether they are maintained
or not, and users should inspect the contents of those projects to ensure they
are as expected.

This maps to OpenSSF Best Practices badge `maintained` (though without a numeric score):

> The project MUST be maintained.

## Packaging

> This check tries to determine if the project is published as a package. It is currently limited to repositories hosted on GitHub, and does not support other source hosting repositories (i.e., Forges).
>
> Packages give users of a project an easy way to download, install, update, and uninstall the software by a package manager. In particular, they make it easy for users to receive security patches as updates.
>
> The check currently looks for [GitHub packaging workflows](https://docs.github.com/en/packages/learn-github-packages/publishing-a-package) and language-specific GitHub Actions that upload the package to a corresponding hub, e.g., [Npm](https://www.npmjs.com/). We plan to add better support to query package manager hubs directly in the future, e.g., for [Npm](https://www.npmjs.com/), [PyPi](https://pypi.org/).

This is a partial map to OpenSSF Best Practices badge `installation_common` (it's only partial because the best practices badge allows alternatives to packaging):

> The project MUST provide a way to easily install and uninstall the software produced by the project using a commonly-used convention.

## Pinned-Dependencies

> This check tries to determine if the project pins dependencies used during its build and release process.  A "pinned dependency" is a dependency that is explicitly set to a specific hash instead of allowing a mutable version or range of versions. It is currently limited to repositories hosted on GitHub, and does not support other source hosting repositories (i.e., Forges).
>
> The check works by looking for unpinned dependencies in Dockerfiles, shell scripts, and GitHub workflows which are used during the build and release process of a project.  Special considerations for Go modules treat full semantic versions as pinned due to how the Go tool verifies downloaded content against the hashes when anyone first downloaded the module.

No obvious mapping to the OpenSSF Best Practices badge.

## SAST

> This check tries to determine if the project uses Static Application Security Testing (SAST), also known as [static code analysis](https://owasp.org/www-community/controls/Static_Code_Analysis).  It is currently limited to repositories hosted on GitHub, and does not support other source hosting repositories (i.e., Forges).
>
> SAST is testing run on source code before the application is run. Using SAST tools can prevent known classes of bugs from being inadvertently introduced in the codebase.
>
> Note: A project that fulfills this criterion with other tools may still receive a low score on this test. There are many ways to implement SAST, and it is challenging for an automated tool like Scorecard to detect them all. A low score is therefore not a definitive indication that the project is at risk.

This generally maps to OpenSSF Best Practices badge `static_analysis` (though this doesn't require security-specific analysis and only no major release):

> At least one static code analysis tool (beyond compiler warnings and "safe" language modes) MUST be applied to any proposed major production release of the software before its release, if there is at least one FLOSS tool that implements this criterion in the selected language.

This also maps to OpenSSF Best Practices badge `static_analysis_common_vulnerabilities`:

> (passing) It is SUGGESTED that at least one of the static analysis tools used for the `static_analysis` criterion include rules or approaches to look for common vulnerabilities in the analyzed language or environment.
>
> (silver) The project MUST use at least one static analysis tool with rules or approaches to look for common vulnerabilities in the analyzed language or environment, if there is at least one FLOSS tool that can implement this criterion in the selected language.

This also maps to OpenSSF Best Practices badge `static_analysis_often`:

> (passing) It is SUGGESTED that static source code analysis occur on every commit or at least daily.

It might be a good idea to modify the best practices badge to
require at least some SAST on every commit, as this has become more
practical today.

## Security-Policy

> This check tries to determine if the project has published a security policy. It works by looking for a file named `SECURITY.md` (case-insensitive) in a few well-known directories.
>
> A security policy (typically a `SECURITY.md` file) can give users information about what constitutes a vulnerability and how to report one securely so that information about a bug is not publicly visible.
>
> This check examines the contents of the security policy file awarding points for those policies that express vulnerability process(es), disclosure timelines, and have links (e.g., URL(s) and email(s)) to support the users.

This maps to OpenSSF Best Practices badge `vulnerability_report_process`:

> The project MUST publish the process for reporting vulnerabilities on the project site.

Also maps to OpenSSF Best Practices badge `vulnerability_report_private`:

> If private vulnerability reports are supported, the project MUST include how to send the information in a way that is kept private.

## Signed-Releases

> This check tries to determine if the project cryptographically signs release
artifacts. It is currently limited to repositories hosted on GitHub, and does
not support other source hosting repositories (i.e., Forges).
>
> Signed releases attest to the provenance of the artifact.
>
> This check looks for the following filenames in the project's last five [release assets](https://docs.github.com/en/repositories/releasing-projects-on-github/about-releases): ...

This maps to OpenSSF Best Practices badge `signed_releases`:

> (silver) The project MUST cryptographically sign releases of the project results intended for widespread use, and there MUST be a documented process explaining to users how they can obtain the public signing keys and verify the signature(s). The private key for these signature(s) MUST NOT be on site(s) used to directly distribute the software to the public.

## Token-Permissions

> This check determines whether the project's automated workflows tokens follow the principle of least privilege. This is important because attackers may use a compromised token with write access to, for example, push malicious code into the project.
>
> It is currently limited to repositories hosted on GitHub, and does not support other source hosting repositories (i.e., Forges).

No obvious mapping to the OpenSSF Best Practices badge.

## Vulnerabilities

> This check determines whether the project has open, unfixed vulnerabilities in its own codebase or its dependencies using the [OSV (Open Source Vulnerabilities)](https://osv.dev/) service.  An open vulnerability is readily exploited by attackers and should be fixed as soon as possible.

This maps to OpenSSF Best Practices badge `vulnerabilities_fixed_60_days`:

> There MUST be no unpatched vulnerabilities of medium or higher severity that have been publicly known for more than 60 days.

Note that the best practices badge text here could be interpreted as
only applying to its own codebase, not necessarily its dependencies.

This also partly maps to OpenSSF Best Practices badge `vulnerabilities_fixed_60_days`:

> There MUST be no unpatched vulnerabilities of medium or higher severity that have been publicly known for more than 60 days.

This also partly maps to OpenSSF Best Practices badge `vulnerabilities_critical_fixed`:

> Projects SHOULD fix all critical vulnerabilities rapidly after they are reported.

There are also OpenSSF Best Practices badge criteria that discuss
fixing vulnerabilities found by the project itself using
static or dynamic analysis, but since those are "internal" instead of
"external" they don't seem to really be a mapping of any kind.

## Webhooks

> This check determines whether the webhook defined in the repository has a token configured to authenticate the origins of requests.

No obvious mapping to the OpenSSF Best Practices badge.
