# Add best-practices-badge to OSS-Fuzz

## Project overview

The [OpenSSF Best Practices Badge](https://www.bestpractices.dev/) is the
Linux Foundation / OpenSSF's official security-badging system for free and
open source software. Over **10,000 open source software projects**
have registered,
including critical infrastructure such as the Linux kernel, curl, OpenSSL,
Node.js, and Kubernetes. It provides security criteria to help these
projects determine valuable next steps, as well as showing the world
how well they're doing.

Like all web applications, the application is under continuous attack.
It is publicly accessible, widely known, and serves as security
infrastructure for the broader open source ecosystem.

## Threat model

A vulnerability in the badge application could:

- Yield **remote code execution** on infrastructure that thousands of projects
  depend on to demonstrate their security posture
- Allow corruption or forgery of badge status of arbitrary projects,
  undermining trust in the badging system globally
- Expose private data (in particular encrypted maintainer emails)

The most dangerous attack surfaces are the input-processing pipelines that
handle untrusted data from project maintainers worldwide: URL fields and
free-text markdown justification fields.

## Fuzz targets

The application is a Ruby on Rails web app.
Two [Ruzzy](https://github.com/trailofbits/ruzzy)-based harnesses
target the security-critical input paths.

We intend to eventually do more, but we wanted to start with specific
improvements.

### `fuzz_url_validator`

Loads the real `UrlValidator` class (`app/validators/url_validator.rb`)
via ActiveModel. Exercises:

- The custom `URL_REGEX` pattern for ReDoS via catastrophic backtracking
- The percent-decode → `force_encoding('UTF-8')` pipeline for encoding attacks

### `fuzz_markdown_processor`

Targets `MarkdownProcessor.render` (`app/lib/markdown_processor.rb` +
`app/lib/invoke_commonmarker.rb`). Exercises all three code paths:

- `PREFIXED_URL_REGEX` fast path — ReDoS risk in a complex possessive-quantifier regex
- `MARKDOWN_UNNECESSARY` fast path — ReDoS risk in a large multi-guard regex
- CommonMarker (Rust/comrak) HTML generation + URL-protocol sanitization
  (`javascript:`, `data:`, and other dangerous schemes stripped to prevent XSS)

## Technical notes

- **Language:** Ruby
- **Fuzzing library:** [Ruzzy](https://github.com/trailofbits/ruzzy)
  (Trail of Bits), which wraps libFuzzer
- **Engine:** libFuzzer only.
  Ruzzy does not support AFL, honggfuzz, or centipede
- **Sanitizers:** AddressSanitizer and UndefinedBehaviorSanitizer;
  MemorySanitizer is excluded because it requires every dependency to be
  fully instrumented, which is not feasible for Ruby's native C/Rust extensions
- **Dependencies:** `activemodel` (for `UrlValidator`) and `commonmarker`
  (Rust-backed CommonMark parser); commonmarker ships a pre-built
  `x86_64-linux` native gem so no Rust toolchain is needed in the image
- **Harnesses:** maintained in the project repository at `script/fuzz_*.rb`;
  `build.sh` clones the repo and references them directly so they stay in sync

## References

- Production site: <https://www.bestpractices.dev/>
- Source repository: <https://github.com/ossf/best-practices-badge>
- Security policy: <https://github.com/ossf/best-practices-badge/blob/main/SECURITY.md>
- Vulnerability reports: <https://github.com/ossf/best-practices-badge/security/advisories/new>

In the longer term we expect to move the GitHub location
to the OpenSSF GitHub organization (ossf).
