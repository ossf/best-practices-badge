# Security Audit Report: OpenSSF Best Practices Badge

**Original Audit Date:** Sunday, May 10, 2026
**Amended:** Monday, May 11, 2026
**Scope:** Core Controllers, Models, Validators, and Helpers.

> **Amendment Notice (2026-05-11):** This report was originally produced by Gemini on May 10,
> 2026. It was reviewed by David A. Wheeler on May 11, 2026, assisted by Claude (Anthropic).
> Changes are annotated inline with `[Amendment, 2026-05-11]:` markers. A consolidated summary
> of all changes and their rationale appears in the
> [Report Amendments](#report-amendments) section at the end.
> The report serves as both the implementation plan for all recommended improvements and a record
> of the reasoning behind each decision.

---

## Executive Summary

The OpenSSF Best Practices Badge application demonstrates a mature security posture. The codebase
implements advanced defensive patterns, including email encryption, blind indexing, constant-time
authentication, and strict input validation.
Our audit found **no critical vulnerabilities** (such as RCE or SQL injection). We identified
several areas that initially appeared suspicious but were determined to be safe upon deeper
investigation due to existing defensive layers.

In short, there is only 1 extremely minor vulnerability, VULN-001.
This is a timing vulnerability that might allow an attacker to determine
if an email address that the attacker already knows is in use.

The other findings aren't really vulnerabilities.
However, we try to make adjustments so that it is *really* obvious
that something is (or is not) a vulnerability. This
(1) hardens the system so changes are unlikely to become vulnerabilities, and
(2) makes future reviews more effective because they can
quickly determine "there is no problem" and thus spend more
review time focusing on other areas where there might be a vulnerability.

---

## Findings

### 1. Potential Vulnerability Review (Determined Secure)

#### A. User Search Wildcards

- **Initial Observation:** `UsersController#search_name` uses a `LIKE` query with unescaped user
  input: `User.where('lower(name) LIKE ?', "%#{desired_name.strip.downcase}%")`.
- **Determination:** **FALSE POSITIVE / INTENTIONAL**.
- **Reasoning:** The code explicitly documents this as intentional for admin users to support GDPR
  and legal requests. Access is strictly controlled by a `current_user.admin?` check in
  `search_users`.
- **Improvement Plan:** To make this security intent "locally obvious" and provide defense-in-depth:
    - **Move to Private:** Relocate `search_name`, `search_email`, and `search_users_by_lists`
      to the `private` section of `UsersController`.
    - **Internal Admin Check:** Add an explicit `return User.none unless current_user&.admin?`
      check inside `search_users_by_lists` and `search_name`. This is the highest-priority
      improvement: it provides machine-enforced protection that cannot be bypassed by a future
      caller that omits the outer check. Searching by email is security-sensitive; searching by
      name imposes load we do not want non-admins to impose.

> **[Amendment, 2026-05-11]:** The original plan listed "Enhanced Comments" (updating method
> headers) as a third bullet. That recommendation is removed as a primary action item. The
> project prefers automated enforcement over documentation: the internal admin guard (`return
> User.none unless current_user&.admin?`) is the meaningful mitigation; prose comments are
> easily missed and do not prevent misuse. A brief inline note is acceptable if the guard's
> purpose is non-obvious, but it is not a separate work item.

---

#### B. Open Redirects in Sessions

- **Initial Observation:** `SessionsController` uses `params[:return_to]` and
  `omniauth.params['return_to']` for post-login redirects.
- **Determination:** **FALSE POSITIVE / SECURE**.
- **Reasoning:** Every instance of a user-supplied return path is validated using
  `valid_return_path?` in `SessionsHelper`. This method rejects non-server-relative paths (must
  start with `/` but not `//`) and blocks sensitive paths like `/login` or `/signout`.
- **Improvement Plan:**
    - **Add `allow_other_host: false` to `redirect_back_or`:** The `successful_login` method in
      `SessionsController` already passes `allow_other_host: false` when redirecting to a
      `return_to_path`. The remaining gap is `redirect_back_or` in `SessionsHelper` (line 266),
      which redirects to `session[:forwarding_url]` without that flag. Add the flag there:

      ```ruby
      def redirect_back_or(default)
        forwarding_url = session[:forwarding_url]
        session.delete(:forwarding_url)
        redirect_to(forwarding_url || force_locale_url(default, I18n.locale),
                    allow_other_host: false)
      end
      ```

      The `forwarding_url` stored in the session is already validated as same-host by
      `store_internal_referer`, so there is no active vulnerability — this change is
      defense-in-depth against future refactoring that might widen the set of stored URLs.

> **[Amendment, 2026-05-11]:** The original plan had two bullets with unresolved uncertainty:
>
> 1. "Warning Comments" on `valid_return_path?` — removed. The method already has a YARD
>    docblock explaining its role; a large "SECURITY NOTE" block would be documentation, not
>    enforcement, which conflicts with the project's preference for automated prevention.
>
> 2. "Explicit Enforcement" — the original text said "it's not clear if we should implement
>    [a new combined method], and if we do, where it should go." That question is now resolved:
>    **no new method is needed.** The existing code paths already do the right thing in
>    `successful_login`; only `redirect_back_or` is missing the flag. A new abstraction would
>    be premature — there is one call site, and the project's coding guidelines explicitly
>    caution against abstractions that are not required by the immediate task. If a combined
>    helper were ever warranted, the correct location would be `SessionsHelper` (where
>    `valid_return_path?` and `redirect_back_or` already live), not `ApplicationController`.

---

#### C. SQL Injection in Project Deletion

- **Initial Observation:** `params[:deletion_rationale]` is passed to a mailer and potentially
  logged.
- **Determination:** **FALSE POSITIVE / SECURE**.
- **Reasoning:** The rationale is treated as a plain string. It is rendered in a text email
  template (`report_project_deleted.text.erb`) and is not used in any database query or shell
  command.
- **Improvement Plan:**
    - **Clarifying Comment:** Add a brief inline comment in `ProjectsController#destroy` where
      `deletion_rationale` is extracted, noting that it is for informational/logging use only
      and must not be used in database queries. Keep it to one line — the purpose of the
      variable is the non-obvious thing worth noting.

---

#### D. PII in Logs

- **Initial Observation:** Numerous controllers handle emails and tokens.
- **Determination:** **FALSE POSITIVE / SECURE**.
- **Reasoning:** `config/initializers/filter_parameter_logging.rb` contains a comprehensive
  filter list: `%i[passw email secret token _key crypt salt certificate otp ssn]`. This filters
  PII from Rails' automatic request parameter logging.
- **Important Scope Limitation:** `filter_parameters` only applies to what Rails logs
  automatically (the parameter snapshot for each request). It does **not** filter explicit
  `Rails.logger.info/warn/error` calls where values are interpolated directly into the string.
  Code such as `Rails.logger.info "Email: #{user.email}"` would reach the log unfiltered,
  regardless of the filter list.
- **Existing Good Practice:** The codebase already demonstrates the correct pattern for explicit
  log calls. In `app/controllers/unsubscribe_controller.rb`, the developer manually strips the
  email address to its domain before logging and annotates each call with a brief comment (e.g.,
  `# Security: Log potential security incident (without PII)`). This is the right approach.
- **Improvement Plan:**
    - Review all explicit `Rails.logger.*` calls across controllers to confirm no PII is
      interpolated directly. Where the absence of PII is non-obvious, add a brief inline comment
      following the pattern established in `unsubscribe_controller.rb`.
    - Do **not** add a comment at each log call pointing to `filter_parameter_logging.rb` as
      justification — that initializer does not protect explicit logger calls and citing it there
      would mislead reviewers about the actual scope of protection.

> **[Amendment, 2026-05-11]:** The original finding stated the filter list "ensures PII is
> masked in Rails logs" without qualification. This overstates the filter's scope: it only covers
> automatic request parameter logging, not explicit `Rails.logger.*` calls. The improvement plan
> is new — the original had none for this item. The note about not citing
> `filter_parameter_logging.rb` in logger-call comments was specifically requested to prevent
> reviewers from being misled about the filter's actual coverage.

---

#### E. Weak URL Detection in Justifications

- **Initial Observation:** `Project#contains_url?` uses a very loose regex:
  `%r{https?://[^ ]{5}}`.
- **Determination:** **NOT A VULNERABILITY**.
- **Reasoning:** These URLs serve as pointers to evidence for criteria fulfillment. The
  application does not automatically traverse or trust these URLs as part of a secure workflow,
  nor does it verify the relevance of the evidence they point to. They are strictly informational
  data.
- **Improvement Plan:** While not a security flaw, we plan to improve the regex to require a
  dot in the hostname portion, rejecting obvious nonsense like `https://12345` while remaining
  intentionally loose for legitimate evidence URLs. The dot must appear before any `/` to ensure
  it is in the host, not the path (so `https://localhost/path.html` is correctly rejected).
  The trailing character class needs no `+` quantifier because the regex is used as a search
  (does the text *contain* this pattern?), not a full match — one non-space character after the
  dot is sufficient to confirm a match; consuming more would not change the boolean result.
    - **Ruby (Backend):** `app/models/project.rb`, method `contains_url?` (Line 413):
      `%r{https?://[^/. ]+\.[^ ]}`
    - **JavaScript (Frontend):** `app/assets/javascripts/project-form.js`, function
      `containsURL` (Line 91):
      `/https?:\/\/[^\/. ]+\.[^ ]/`
    - **Tests:** Add or update tests for the new regex behavior to cover the added constraint.
      Both files must stay in sync; a test documents the expected behavior and catches future
      drift between the two implementations.

> **[Amendment, 2026-05-11]:** The original plan said only "require at least one period" without
> specifying the regex. The regex is now specified. The dot must be in the hostname (not the
> path), which requires excluding `/` from the segment before the dot. The trailing `+`
> quantifier is omitted because the regex is a search pattern, not a full match — a single
> character after the dot is enough for detection. The test requirement was also added here;
> the original plan mentioned updating two files but did not call out the need to keep them in
> sync or to add test coverage.

---

## Identified Risks and Recommendations

### VULN-001: Potential Timing Attack on Local Account Activation

- **Severity:** Very Low (practical impact very narrow — see scope note below)
- **Vulnerability Type:** Security (Account Enumeration)
- **Description:** `AccountActivationsController` finds users by email before checking the
  activation token. Because Ruby's `&&` operator short-circuits, a request for a non-existent
  email returns almost instantly (~5ms), while a request for a valid email with an unactivated
  account performs a slow BCrypt comparison (~100ms+). This timing difference could allow an
  attacker to enumerate email addresses via timing analysis.
- **Scope:**
  This timing attack can only confirm to an attacker who *already* knows
  a given email address, and wants to confirm whether or not that given email
  address is present in our database.
  What's more, cases where this confirmation *can* leak are extremely narrow.
  The slow path (BCrypt) was only reached when
  the email belonged to a user who was
  present in the database **and** local (not GitHub) **and**
  not yet activated. Specifically:
    - Emails not in the database → fast (short-circuit on nil user)
    - Emails belonging to already-activated users → fast (short-circuit on `!user.activated?`)
    - GitHub OAuth users → always created as activated, so always fast
    - Only emails belonging to **local users who have registered but not yet clicked the
      activation link** → slow (BCrypt runs)
  The practical window of exposure is extremely narrow: most users activate their account
  within minutes of receiving the email, so the population of exploitable addresses at any
  given moment is very small.
  Nevertheless, the fix is straightforward and eliminates the
  leak entirely.
- **Reference Pattern:** A secure version of this logic already exists in `app/models/user.rb`
  within the `authenticate_local_user` method, which uses `DUMMY_HASH` to ensure a BCrypt
  operation occurs even when no user is found.
- **Remediation Plan:**
    - **Target File:** `app/controllers/account_activations_controller.rb`
    - **Target Method:** `edit`
    - **Implementation Details:** Refactor the conditional to perform a constant-time check.
      Explicitly evaluate both the user's presence and the token's validity, ensuring the slow
      BCrypt operation is triggered regardless of whether the user exists. The fix mirrors the
      `DUMMY_HASH` pattern from `authenticate_local_user`.

      Note: `DUMMY_HASH` is a BCrypt digest of a password string, while `params[:id]` is an
      activation token (a random string). Conceptually they are different, but both are
      arbitrary strings verified against a BCrypt digest using `BCrypt::Password#is_password?`,
      so the timing characteristics are identical — this reuse is correct.

    - **Proposed Fix:**

      ```ruby
      def edit
        user = User.find_by(email: params[:email])
        unactivated = user && !user.activated?
        if unactivated
          token_valid = user.authenticated?(:activation, params[:id])
        else
          # Always perform BCrypt to prevent timing-based user enumeration
          User.verify_password_against_hash?(User::DUMMY_HASH, params[:id])
          token_valid = false
        end

        if unactivated && token_valid
          user.can_login_starting_at = Time.zone.now + LOCAL_LOGIN_COOLOFF_TIME
          user.activate
          flash[:success] = t('account_activations.activated') + ' ' +
                            t(
                              'account_activations.delay',
                              count: LOCAL_LOGIN_COOLOFF_TIME / 3600.0
                            )
          redirect_to login_path
        else
          flash[:danger] = t('account_activations.failed_activation')
          redirect_to root_url
        end
      end
      ```

> **[Amendment, 2026-05-11]:** The original proposed fix was functionally correct but was
> revised for three reasons:
>
> 1. **Comment style:** The original used a numbered multi-line comment block. The project's
>    coding guidelines say "default to writing no comments" and "never write multi-line comment
>    blocks — one short line max." The revised fix has one short comment on the else branch
>    explaining the non-obvious WHY (timing protection), and the success/failure logic is
>    spelled out in full rather than left as `# ... rest of success logic ...` placeholders.
>
> 2. **Conceptual clarification:** Added a note in the implementation details explaining why
>    reusing `DUMMY_HASH` (a password digest) against an activation token (a random string) is
>    valid. Both go through the same `BCrypt::Password#is_password?` path, so timing is
>    identical. This is documented here rather than in a code comment because it belongs in the
>    rationale, not cluttering the implementation.
>
> 3. **Scope of the original vulnerability clarified:** The original description said "a request
>    for a valid email performs a slow BCrypt comparison," implying any email in the database was
>    exposed. In fact, BCrypt only ran for emails belonging to **unactivated local users** — the
>    `&&` short-circuit meant GitHub OAuth users (always activated) and already-activated local
>    users both returned fast. The exploitable population at any moment is very small, since
>    users typically activate within minutes of receiving the email. Severity remains Low, but
>    the practical impact is even narrower than the original description suggested.
>
> 4. **Further refactoring in implementation:** The fix as implemented went beyond the proposed
>    fix above. The timing-safe logic was extracted into a new `User.find_unactivated_by_valid_token(email, token)`
>    class method (parallel to the existing `User.authenticate_local_user`), leaving the
>    controller a simple `if user / else` branch. This makes the logic unit-testable in
>    isolation and keeps the timing-safety concern in the model where it belongs. Four unit
>    tests were added to `test/models/user_test.rb` covering all branches of the new method.

---

## Conclusion

The application is exceptionally well-hardened. The developers have consistently applied
security best practices, and many "potential" flaws were found to have been anticipated and
mitigated by existing architectural choices (like `valid_return_path?` and
`filter_parameters`).

**Audit Status:** CLEAN (with minor low-severity recommendations)

---

## Report Amendments

This section consolidates all changes made to the original Gemini report on 2026-05-11, with
rationale. Each item is cross-referenced to the finding it affects.

| Finding | Change | Rationale |
|---------|--------|-----------|
| **1A** | Removed "Enhanced Comments" as a primary action item | The project prefers automated enforcement (the admin guard) over documentation. Prose comments can be ignored; a guard clause cannot be bypassed. |
| **1B** | Removed "Warning Comments" bullet | `valid_return_path?` already has a clear YARD docblock; a large security-note comment block adds noise without adding protection. |
| **1B** | Resolved the "new combined method?" question: **no new method** | One call site does not justify a new abstraction. The project's coding guidelines explicitly caution against premature abstraction. The single fix is adding `allow_other_host: false` to `redirect_back_or`. |
| **1B** | Resolved "where would the new method go?": **`SessionsHelper`** | If a combined helper were ever warranted in the future, `SessionsHelper` already owns `valid_return_path?` and `redirect_back_or` and is the cohesive location — not `ApplicationController`. Documented here for completeness. |
| **1D** | Corrected overstated scope; added improvement plan | The original said filtering "ensures PII is masked in Rails logs" — this is only true for automatic request parameter logging, not for explicit `Rails.logger.*` calls with interpolated values. Added an improvement plan to audit explicit log calls and follow the pattern already established in `unsubscribe_controller.rb`. Noted that pointing from explicit log calls to `filter_parameter_logging.rb` would mislead reviewers. |
| **1E** | Specified the regex; explained trailing `+` omission; added test requirement | The original said only "require at least one period." The regex is now fully specified: the dot must be in the hostname (excluding `/` before the dot), and the trailing `+` is omitted because the regex is a search pattern — one character after the dot suffices for detection. Test requirement added for sync between Ruby and JavaScript implementations. |
| **VULN-001** | Replaced multi-line comment block with single-line comment | Project guidelines: "never write multi-line comment blocks — one short line max." |
| **VULN-001** | Expanded fix to include actual success/failure logic | The original left `# ... rest of success logic ...` placeholders, making the fix incomplete as a direct implementation guide. |
| **VULN-001** | Added note clarifying `DUMMY_HASH` reuse | The conceptual mismatch (password digest vs. activation token) could cause a reviewer to question the fix. The explanation belongs in the rationale, not the code. |
| **VULN-001** | Corrected and narrowed the vulnerability scope | The original said "a request for a valid email performs a slow BCrypt comparison" — overstated. BCrypt only ran for unactivated local users; already-activated users and GitHub OAuth users always returned fast. The exploitable window is very small since users activate quickly. |
| **VULN-001** | Documented further refactoring to `User.find_unactivated_by_valid_token` | The timing-safe logic was extracted into a new `User` class method parallel to `authenticate_local_user`, making it unit-testable. Four unit tests were added covering all branches. |
