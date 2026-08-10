# Gemini Security Audit Report - 2026-05-14

## Executive Summary

This report documents the preliminary findings of a security audit performed by the Gemini CLI agent. The audit focuses on the Best Practices Badge system, focusing on core controllers, models, and utility libraries.

## Current Audit Scope

- **Controllers**: `ProjectsController`, `UsersController`, `SessionsController`, `ApplicationController`.
- **Models**: `Project`, `User`.
- **Libraries**: `MarkdownProcessor`, `GithubContentAccess`.

## Preliminary Findings and Concerns

### 1. Potential XSS in Markdown Optimization

- **Location**: `app/lib/markdown_processor.rb`
- **Description**: The system uses a complex regular expression (`MARKDOWN_UNNECESSARY`) to identify text that doesn't require Markdown processing. If matched, the text is returned as `.html_safe`.
- **Risk**: High. Any bypass in the regex that allows HTML tags or dangerous entities through would lead to direct XSS, as the application bypasses the standard sanitizer.
- **Investigation Plan**: Perform a "stress test" on the `MARKDOWN_UNNECESSARY` regex to identify potential bypasses.

### 2. Potential SQL Injection in Search Scopes

- **Location**: `app/models/project.rb` (scopes: `text_search`, `url_search`, `search_for`)
- **Description**: User-provided search strings (`params[:q]`, `params[:pq]`, `params[:url]`) are passed to ActiveRecord scopes.
- **Risk**: Medium-High. While some scopes use parameterization, the `text_search` scope uses Arel's `.matches()` with manual wildcard concatenation (`#{sanitize_sql_like(text)}%`).
- **Investigation Plan**: Trace the data flow from `ProjectsController#retrieve_projects` to these scopes and verify that the underlying database driver correctly parameterizes the resulting SQL.

### 3. Open Redirect Risk in Locale and Session Logic

- **Location**: `app/controllers/application_controller.rb` (`redir_missing_locale`) and `SessionsController`.
- **Description**: Redirections are performed based on `request.original_url` or `params[:return_to]`.
- **Risk**: Medium. If these redirects do not strictly enforce same-origin or an allow-list, they could be used for phishing attacks.
- **Investigation Plan**: Verify the implementation of `safe_internal_url` and `valid_return_path?` (if it exists) to ensure they prevent off-site redirects.

### 4. DoS/SSRF Vulnerability in GitHub Content Access

- **Location**: `app/lib/github_content_access.rb`
- **Description**: The `get_content` method relies on trusting GitHub's reported file size before fetching. Because the Octokit gem reads the entire response into memory, a malicious "upstream" could cause an Out-Of-Memory (OOM) condition.
- **Risk**: Low-Medium (Requires compromised GitHub or MITM).
- **Status**: Noted as a known architectural limitation with a "trust but verify" mitigation.

### 5. Privacy of User Data

- **Observation**: User email addresses are protected using `attr_encrypted` (AES-256-GCM) and `blind_index` for searching.
- **Conclusion**: This appears to be a robust implementation of privacy best practices for PII.

## Results of Further Investigation

Following the preliminary audit, a detailed investigation was performed on the four key areas of concern. This section provides an exhaustive technical account of the analysis, including specific file and line references, reproduction methods, and the architectural justifications for the final security conclusions.

### 1. Markdown Optimization and XSS Prevention

- **Primary Files**: `app/lib/markdown_processor.rb`
- **Key Symbols**: `MARKDOWN_UNNECESSARY` (lines 177-183), `MARKDOWN_UNNECESSARY_LINE` (lines 120-171), `PREFIXED_URL_REGEX` (lines 257-285).
- **Analysis Method**: The investigation focused on whether the "fast path" optimization (returning text as `.html_safe` without escaping) could be bypassed to inject malicious HTML tags.
- **Approach & Justification**:
    - **Step 1: Regex Audit**: The `MARKDOWN_UNNECESSARY_LINE` regex was analyzed for its "Safe Character Set" (line 145). It explicitly excludes `<` and `&`. It also excludes characters like `*`, `_`, and `` ` `` to ensure that any text requiring Markdown rendering is passed to the full processor.
    - **Step 2: Stress Testing**: A custom test suite was executed against the regexes. Payloads included literal tags (`<script>`), encoded entities (`&lt;script&gt;`, `&#60;script`), and Unicode variants (`＜script＞`).
    - **Step 3: Justification of Approach**: The optimization is justified by significant performance data (lines 20-35) showing that ~58% of non-nil texts match the "unnecessary" path. Avoiding the Markdown processor for these cases provides a critical performance benefit.
- **Detailed Findings**:
    - **Safety Logic**: The regex uses possessive quantifiers (`++`) to prevent catastrophic backtracking and ensures that if a `<` is present anywhere in the line, the entire regex fails to match.
    - **HTML Entities**: The regex explicitly allows valid HTML entities (lines 167-170). While these render as special characters (e.g., `&lt;` as `<`), they are **rendered** by the browser but not **executed** as tags. This is a crucial distinction that maintains security.
    - **URL Path**: The `PREFIXED_URL_REGEX` handles cases where a user provides a single URL. Crucially, the code at lines 333-334 calls `CGI.escapeHTML` on all user-supplied components before concatenation. This provides a second layer of defense-in-depth.
- **Alternatives Considered**:
    - *Always escape*: We considered always calling `html_escape` on the result. However, the performance stats show that this would add unnecessary string allocations and processing for millions of safe strings.
    - *Removing optimization*: This would increase server load significantly during bulk project listings.
- **Final Conclusion**: **VERIFIED SAFE**. The regex acts as a robust, fail-secure gatekeeper. Any input that could potentially be dangerous is rejected by the optimization path and handled by the sanitized Markdown processor.

### 2. Project Search Scopes and SQL Injection

- **Primary Files**: `app/models/project.rb` (lines 255-267), `app/controllers/projects_controller.rb` (line 1313).
- **Key Symbols**: `:text_search` scope.
- **Analysis Method**: Verification of the SQL generation logic using the Rails environment to confirm that user input is correctly parameterized.
- **Approach & Justification**:
    - **Step 1: Data Flow Tracing**: We traced `params[:pq]` from `ProjectsController#retrieve_projects` (line 1313) to the `Project.text_search` scope.
    - **Step 2: Empirical SQL Verification**: We ran the following command to inspect the generated SQL for a malicious payload:

      ```bash
      bundle exec rails runner "puts Project.text_search(\"test' OR 1=1 --\").to_sql"
      ```

- **Detailed Findings**:
    - **ActiveRecord/Arel Logic**: The scope uses `Project.arel_table[:name].matches(start_text)`. Arel's `matches` method is database-aware; for PostgreSQL, it generates an `ILIKE` clause and automatically handles the escaping of the single quote (`'`).
    - **Evidence**: The command output was: `SELECT "projects".* FROM "projects" WHERE (("projects"."name" ILIKE 'test'' OR 1=1 --%' OR ...`. The presence of the double single-quote (`''`) confirms that the database driver treated the payload as a literal string.
    - **Wildcard Safety**: The code at line 258 uses `sanitize_sql_like(text)`. This ensures that characters like `%` or `_` provided by the user are escaped (e.g., `\%`), preventing "Denial of Service" style queries where a user could force an expensive full-table scan.
- **Alternatives Considered**:
    - *Raw SQL Concatenation*: Using `where("name LIKE '#{text}%'")` would be a classic critical vulnerability. The application correctly avoids this pattern.
- **Final Conclusion**: **VERIFIED SAFE**. The implementation leverages framework-level protections (ActiveRecord/Arel) that are the industry standard for SQL injection prevention.

### 3. Locale Redirection and Host Security

- **Primary Files**: `lib/locale_utils.rb` (lines 64-85), `app/controllers/application_controller.rb` (line 371).
- **Key Symbols**: `LocaleUtils.safe_internal_url`.
- **Analysis Method**: Audit of the URL parsing and reconstruction logic to detect open-redirect or host-header injection risks.
- **Approach & Justification**:
    - **Step 1: URI Parsing Analysis**: We audited how `safe_internal_url` manipulates URLs at line 65 using `URI.parse`.
    - **Step 2: Host Enforcement Check**: We analyzed the code at line 66: `url.host = ENV.fetch('PUBLIC_HOSTNAME', url.host)`.

- **Detailed Findings**:
    - **Security Invariant**: By explicitly setting `url.host`, the application ensures that even if an attacker manages to pass an external URL as the "original URL," the resulting redirect will be forced back to the project's official `PUBLIC_HOSTNAME`.
    - **Redirection Logic**: In `ApplicationController#redir_missing_locale` (line 371), the method uses `request.original_url`. Since this value is derived from the server's own environment and verified against the `Host` header (which Rails validates against an allow-list if configured), it is a safe source for redirection.
- **Final Conclusion**: **VERIFIED SAFE**. The explicit host-setting logic in `LocaleUtils` effectively mitigates open-redirect attacks during locale switching.

### 4. Session Return Paths and Open Redirects

- **Primary Files**: `app/helpers/sessions_helper.rb` (lines 14-25, 274-282), `app/controllers/sessions_controller.rb`.
- **Key Symbols**: `valid_return_path?`, `INVALID_RETURN_TO_PATH_REGEX`.
- **Analysis Method**: Review of path validation logic and framework-level redirection fail-safes.
- **Approach & Justification**:
    - **Step 1: Regex Audit**: We reviewed `INVALID_RETURN_TO_PATH_REGEX` (lines 14-25), which blocks redirects to sensitive auth endpoints like `/login` or `/signout`.
    - **Step 2: Prefix Validation**: We audited `valid_return_path?` (line 274), which ensures the path is server-relative (`/`) but not protocol-relative (`//`).
- **Detailed Findings**:
    - **Defense-in-Depth**: The application does not rely solely on regex. In `SessionsController`, the `successful_login` method (and others) uses `redirect_to return_to_path, allow_other_host: false`.
    - **Framework Enforcement**: The `allow_other_host: false` parameter (a Rails-native security feature) ensures that if any validation were bypassed and an external URL were provided, Rails would raise an `UnsafeRedirectError` rather than redirecting the user's browser.
- **Alternatives Considered**:
    - *Relying only on Rails*: While `allow_other_host: false` is strong, the additional `valid_return_path?` check provides better error handling and prevents internal redirect loops (e.g., redirecting back to the login page).
- **Final Conclusion**: **VERIFIED SAFE**. The combination of strict path-prefix validation and Rails-native host enforcement provides a highly secure redirection model.

## Future Improvements

To simplify future security analyses and make the system's safety properties more "discoverable" and "self-verifying," the following improvements are recommended. These changes focus on enhancing auditability without significantly impacting runtime performance.

### 1. Architectural Self-Documentation

The security rationale for optimizations should be made explicit in the code to assist future auditors.

- **Markdown Processor**: Add a comment directly above the `MARKDOWN_UNNECESSARY` regex (line 177) explicitly stating: `SECURITY: This regex MUST NOT match '<' or '&' (outside of valid entities) because the result is marked .html_safe.`
- **Search Scopes**: Add a comment above the `text_search` scope (line 255) noting: `SECURITY: We use Arel .matches here specifically to ensure DB-level parameterization of user input.`

### 2. Startup "Self-Tests" (Smoke Tests)

Implement a few "smoke tests" that run once during the application's startup sequence. These tests would provide immediate, automated evidence of safety.

- **Regex Integrity Check**: Test `MARKDOWN_UNNECESSARY` against known malicious strings (like `<script>`). If the regex incorrectly returns `true`, the application should fail to start with a descriptive error message.
- **Redirect Guard Validation**: A similar check for `valid_return_path?` to ensure it continues to block protocol-relative URLs (`//`).

These checks should be *very* close to the items they address, so that AI systems and humans can easily see that they are checked. E.g., immediately after their declaration.

We require 100% statement coverage, so an in-line `if...` check that raises on problem" could be a problem (the `raise` would never run and could not be tested). We can use an inline "unless" trick, but fooling the test coverage system isn't really the goal. Instead, let's create a special security assertion, which we can also test. Something like this:

File `security_utils.rb`:

~~~~ruby
# frozen_string_literal: true

# Copyright the Linux Foundation and the
# OpenSSF Best Practices badge contributors
# SPDX-License-Identifier: MIT

# Security utility methods
module SecurityUtils
  class SecurityAssertionError < StandardError; end

  # This method is used to enforce security invariants at load time.
  # It is intended as a "fail-fast" mechanism to prevent the application from
  # booting if a security check fails.
  # By using a method for this, we can test the error-raising branch
  # in unit tests to satisfy 100% statement coverage requirements.
  def self.security_assertion(condition, message)
    if !condition
      raise SecurityAssertionError, "SECURITY CRITICAL: #{message}"
    end
  end
end
~~~~

  ✓  WriteFile  security_utils_test.rb → Accepted (+22, -0)

~~~~ruby
# frozen_string_literal: true

# Copyright the Linux Foundation and the
# OpenSSF Best Practices badge contributors
# SPDX-License-Identifier: MIT

require 'test_helper'
require 'security_utils'

class SecurityUtilsTest < ActiveSupport::TestCase
  test 'security_assertion does nothing if condition is true' do
    # This should pass without error
    SecurityUtils.security_assertion(true, 'Should not raise')
  end

  test 'security_assertion raises SecurityAssertionError if
condition is false' do
    err = assert_raises(SecurityUtils::SecurityAssertionError) do
      SecurityUtils.security_assertion(false, 'My error message')
    end
    assert_match(/SECURITY CRITICAL: My error message/, err.message)
  end
end
~~~~

This will modify markdown_processor.rb as follows:

~~~~
      185
      186  # SECURITY: Fail-fast smoke test to ensure regex rejects
           dangerous tags.
      187   # This runs once when the class is loaded.
      188 - if '<script>'.match?(MARKDOWN_UNNECESSARY)
      189 -   raise 'Security Critical: MARKDOWN_UNNECESSARY regex has a
          bypass!'
      190 - end
      188 + SecurityUtils.security_assertion(
      189 +   !'<script>'.match?(MARKDOWN_UNNECESSARY),
      190 +   'MARKDOWN_UNNECESSARY regex has a bypass!'
      191 + )
      192
      193  # The following pattern *only* matches simple bare URLs,
           optionally
      194   # prefixed with "simple" text, so that
~~~~

and modify project.rb as:

~~~~
      276   # SECURITY: Fail-fast smoke test to ensure SQL parameterization.
      277   # This runs once when the class is loaded.
      278   # Note: .to_sql is a read-only metadata operation.
      279 - unless text_search("test' OR 1=1").to_sql.include?("''")
      280 -   raise 'Security Critical: text_search scope has an SQLi
          bypass!'
      281 - end
      279 + SecurityUtils.security_assertion(
      280 +   text_search("test' OR 1=1").to_sql.include?("''"),
      281 +   'text_search scope has an SQLi bypass!'
      282 + )
      283
      284   # Search for exact match on URL
      285   # (home page, repo, and maybe package URL someday)
~~~~

#### Rationale for "Fail-Fast" Direct Assertions

The preferred implementation for these tests is the "Direct Assertion" approach (e.g., `raise "Security Bypass!" if ...`) placed immediately following the constant or method definition. This is considered the "most honest" and effective method for several reasons:

- **Prevention Over Detection**: By running during the class-loading phase, these checks ensure the application **fails to boot** if a security invariant is violated. This prevents a vulnerability from ever reaching a running environment.
- **Locality of Context**: Keeping the verification logic adjacent to the security-critical code ensures that both humans and AI models are immediately alerted to the security constraints whenever the code is modified. It serves as "executable documentation."
- **Negligible Performance Cost**: Since these checks run only once during the boot sequence (or during a code reload in development), their impact on per-request performance is zero, and their impact on startup time is sub-millisecond.
- **Linter Justification**: While side effects in class bodies are generally discouraged, security invariants are a valid exception. Using `# rubocop:disable` with a clear explanation is the correct way to handle linter warnings in this context.

### 3. Explicit Security Wrappers and Naming

Using named methods that imply security would make auditing trivial by signaling intent.

- **Descriptive Naming**: Rename the helper formerly known as `force_locale_url`, and then known as `safe_internal_url` to `safe_localized_internal_url`. This signals to an auditor that host-enforcement logic is expected to be present within the method.
- **Standardized Utilities ("Safe by Construction")**:
    To eliminate the risk of the complex search logic being accidentally corrupted during future edits to `Project.rb`, the logic should be abstracted into a localized helper method within the `Project` class. This ensures the security-critical sanitization steps are "bundled" together and not spread across multiple lines in a lambda.

    #### Current State (The "Before"):
    **File**: `app/models/project.rb` (Lines 255-266)

    ```ruby
    scope :text_search, (
      lambda do |text|
        start_text = "#{sanitize_sql_like(text)}%"
        where(
          Project.arel_table[:name].matches(start_text).or(
            Project.arel_table[:homepage_url].matches(start_text)
          ).or(
            Project.arel_table[:repo_url].matches(start_text)
          )
        )
      end
    )
    ```

    *Risk*: The sanitization of `text` is decoupled from the `matches` calls. A developer modifying this scope might accidentally remove the `sanitize_sql_like` call or change how `start_text` is constructed without realizing they've broken a security invariant.

    #### Proposed Implementation (The "After"):
    **File**: `app/models/project.rb`

    ```ruby
    class Project < ApplicationRecord
      # ...
      scope :text_search, (
        lambda do |text|
          where(
            prefix_match(:name, text).or(
              prefix_match(:homepage_url, text)
            ).or(
              prefix_match(:repo_url, text)
            )
          )
        end
      )

      # ... (in private or protected class methods)
      def self.prefix_match(column_name, text)
        # Bundles sanitization and parameterization into a single, trusted call.
        safe_text = "#{sanitize_sql_like(text)}%"
        arel_table[column_name].matches(safe_text)
      end
    end
    ```

    #### Verification and Testing Strategy:
    - **Unit Testing**: Add a test case to `test/models/project_test.rb` that calls `Project.prefix_match(:name, "test%").to_sql` and verifies that the output correctly escapes the wildcard (`\%`).
    - **SQL Inspection**: Verify that `Project.text_search("test'").to_sql` results in properly escaped single quotes (`''`).

    #### Benefits for AI and Human Reviewers:
    - **Atomicity**: The security logic (sanitization + parameterization) is now atomic; you cannot call `prefix_match` without getting both.
    - **Clarity**: Future auditors can verify the `prefix_match` method once and then simply ensure the `text_search` scope uses it correctly.

## Final Summary of Audit

All four high-priority investigation tasks have been completed. In each case, the codebase was found to have robust, multi-layered protections that mitigated the theoretical risks identified in the preliminary audit. No code changes are necessary to fix security vulnerabilities.

However, a few potential future improvements were identified to make it easier to make this determination in the future. Those changes would make it easier to resolve these issues, and let analysis tools focus on other issues.
