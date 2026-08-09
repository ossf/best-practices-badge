# Fuzz testing with OSS-Fuzz and Ruzzy

This directory contains the configuration files needed to add this project to
[Google OSS-Fuzz](https://github.com/google/oss-fuzz), Google's continuous
fuzzing service for open source software (OSS).
The fuzz harnesses themselves live in `script/fuzz_*.rb` so they are
maintained alongside the rest of the project code.
Much of this can be reused by other fuzzing frameworks.

## Directory layout

```
test/fuzz/
  project.yaml   – OSS-Fuzz project metadata
  Dockerfile     – Derives from gcr.io/oss-fuzz-base/base-builder-ruby
  build.sh       – Installs gems, builds targets, packs seed corpora
  README.md      – This file

script/
  fuzz_url_validator.rb       – Fuzzes URL validation logic
  fuzz_markdown_processor.rb  – Fuzzes the markdown processing pipeline
```

## Fuzzer overview

The project uses [Ruzzy](https://github.com/trailofbits/ruzzy) (Trail of Bits),
a coverage-guided fuzzer for Ruby that wraps libFuzzer.  It is pre-installed in
the `base-builder-ruby` OSS-Fuzz base image.

### fuzz\_url\_validator

Targets `app/validators/url_validator.rb`.  The harness loads the real
`UrlValidator` class via ActiveModel (no database required).

Security properties checked:

- ReDoS via catastrophic backtracking in `URL_REGEX`
- Encoding attacks through malformed percent-encoded byte sequences
- Edge cases in the `unescape_unforced` → `force_encoding('UTF-8')` pipeline

### fuzz\_markdown\_processor

Targets `app/lib/markdown_processor.rb` and `app/lib/invoke_commonmarker.rb`.
The harness stubs the two ActiveSupport string extensions the module uses
(`html_safe`, `blank?`) so Rails does not need to be loaded.

Security properties checked:

- ReDoS in `MARKDOWN_UNNECESSARY` (complex possessive-quantifier regex)
- ReDoS in `PREFIXED_URL_REGEX`
- XSS bypass via the URL-protocol sanitization (`javascript:`, `data:`, etc.)
- Memory-safety bugs in the CommonMarker Rust/C extension surfaced through
  Ruby-level input

## Running locally with Ruzzy

Ruzzy requires clang to build its C extension.  Follow the full installation
instructions at <https://github.com/trailofbits/ruzzy> (set `CC`, `CXX`,
`LDSHARED`, and `LDSHAREDXX` to your clang binaries), then:

```bash
export ASAN_OPTIONS="allocator_may_return_null=1:detect_leaks=0:use_sigaltstack=0"
```

Run the URL-validation harness (requires activemodel):

```bash
gem install activemodel
mkdir -p tmp/corpus-url
LD_PRELOAD=$(ruby -e 'require "ruzzy"; print Ruzzy::ASAN_PATH') \
  ruby script/fuzz_url_validator.rb tmp/corpus-url
```

Run the markdown harness (install commonmarker first if not already installed):

```bash
gem install commonmarker
mkdir -p tmp/corpus-md
LD_PRELOAD=$(ruby -e 'require "ruzzy"; print Ruzzy::ASAN_PATH') \
  ruby script/fuzz_markdown_processor.rb tmp/corpus-md
```

## Testing with the OSS-Fuzz infrastructure locally

Requires Docker and a local checkout of
[google/oss-fuzz](https://github.com/google/oss-fuzz).
First copy the three files from `test/fuzz/` into
`projects/best-practices-badge/` inside that checkout (see "Submitting"
below), then from the root of the oss-fuzz checkout run:

```bash
python3 infra/helper.py build_image best-practices-badge
python3 infra/helper.py build_fuzzers --sanitizer address best-practices-badge
python3 infra/helper.py check_build best-practices-badge
python3 infra/helper.py run_fuzzer best-practices-badge fuzz_url_validator
python3 infra/helper.py run_fuzzer best-practices-badge fuzz_markdown_processor
```

## Submitting to OSS-Fuzz

1. Fork <https://github.com/google/oss-fuzz>.
2. Create `projects/best-practices-badge/` in your fork.
3. Copy these four files into that directory:
   - `test/fuzz/project.yaml`
   - `test/fuzz/Dockerfile`
   - `test/fuzz/build.sh`
   - `test/fuzz/oss-fuzz-README.md` → rename to `README.md`
4. Use `test/fuzz/oss-fuzz-pr-body.md` as the body of the pull request.
5. Verify `primary_contact` in `project.yaml` is a Google-account-linked
   address (required by OSS-Fuzz for ClusterFuzz dashboard access).
6. Open a pull request against `google/oss-fuzz` following the guidance at
   <https://google.github.io/oss-fuzz/getting-started/accepting-new-projects/>.

The `build.sh` references `script/fuzz_*.rb` via the git clone of this repo,
so the harnesses stay in sync automatically once the PR is merged.

## Adding a new fuzz target

1. Create `script/fuzz_<name>.rb` following the pattern of the existing
   harnesses (implement `test_one_input` as a lambda and call `Ruzzy.fuzz`).
2. Add a `ruzzy-build` line for the new file in `test/fuzz/build.sh`.
3. Optionally add seed corpus entries in the corresponding `mkdir`/`zip` block
   in `build.sh` to help the fuzzer find interesting paths faster.
4. Run locally to confirm it works before committing.

## Candidate future targets

These are high-priority targets for future harnesses, listed with enough detail
to implement them when the time comes.

### fuzz\_project\_validators (full model validation pipeline)

**Goal:** exercise the full set of validators that run when a `Project` record
is created or updated, using real ActiveRecord/ActiveModel validation but
without a live database.

**Relevant code:**

- `app/models/project.rb` (all `validates` and `validate` declarations)
- `app/validators/` (custom validators: `UrlValidator`, `MinLengthValidator`,
  `RepoValidator`, and others)

**Approach:** instantiate a `Project` in isolation using
`ActiveModel::Validations` (or a lightweight in-memory ActiveRecord model)
and call `project.valid?` with fuzz-generated attribute values.
The tricky part is loading enough of Rails that ActiveRecord validators run
without requiring a PostgreSQL connection; the standard pattern is to use
`ActiveModel::Model` as a mix-in on a plain Ruby struct that mirrors the
relevant string attributes.  Seed the corpus with known-good and known-bad
values from `test/fixtures/projects.yml`.

**Security properties checked:**

- ReDoS in any validator regex not already covered by `fuzz_url_validator`
- Unexpected exceptions from malformed input reaching deep validation logic
- Interaction effects between validators (e.g., conditional validators that
  change behavior based on other field values)

### fuzz\_project\_update\_params (JSON API update path)

**Goal:** exercise `ProjectsController#update` via the JSON API path, which
is the primary automation surface used by bots and CI integrations.

**Relevant code:**

- `app/controllers/projects_controller.rb`: the `update` action and the
  `project_params` strong-parameter filter
- `app/models/project.rb`: `assign_attributes` and the validation chain

**Approach:** build a minimal Rack environment (using `Rack::MockRequest`)
that posts JSON to `/en/projects/:id.json` with fuzz-generated bodies; run
it through the controller stack up to (but not including) the database write
by stubbing `project.save`.  This exercises JSON parsing, strong-parameter
filtering, and the full validation pipeline in one shot.  The harness needs
a pre-seeded in-memory `Project` instance as the target record.

**Security properties checked:**

- Mass-assignment bypass attempts via unexpected parameter keys
- ReDoS and encoding attacks on any field accepted by `project_params`
- Exception-safety of the JSON deserialization path under malformed input

### fuzz\_cleanup\_input\_params (controller before-filter)

**Goal:** exercise the `cleanup_input_params` before-action in
`ProjectsController`, which runs on every create and update and rewrites
user-supplied parameters before they reach the model.

**Relevant code:**

- `app/controllers/projects_controller.rb`: the `cleanup_input_params`
  method (called via `before_action` on `create` and `update`)

**Approach:** call `cleanup_input_params` directly on a controller instance
initialized with a fuzz-generated `params` hash.  No database or full
request cycle is needed; instantiate the controller, set `params` from the
fuzz input (parsed as a flat string-to-string hash), and invoke the method.
Check that it does not raise and that the resulting params satisfy expected
invariants (e.g., no unexpected keys survive).

**Security properties checked:**

- Input that causes unexpected mutation or deletion of other parameter keys
- Strings that survive cleanup but trigger downstream failures in validators
  or the model (latent injection surface)
