# Build environment staleness

Our CircleCI test image is frozen at a base built 2025-01-06, and the
procedure for updating it is manual enough that it does not get done.
That single fact produces four of the five problems below. The fifth,
an unpinned Node in the production build, is unrelated and should be
fixed first.

This document is written to be picked up cold. Everything asserted here
was checked on 2026-08-03 or 2026-08-04; where a claim needs
re-verifying before it is relied on, it says so.

## Status

**Already done and merged** (branch `apt-get-update`, deployed to
staging 2026-08-04):

* The `apt-get update` step in the CircleCI `build` job is commented
  out, with the reasoning beside it. It served no purpose and printed an
  error on every build.
* The `deploy` job has its own browser-free image,
  `cimg/node@sha256:8966565f…` (`:24.19.0`), rather than sharing the
  test image. That job holds `HEROKU_API_KEY`, so it should carry as
  little as possible. The Heroku CLI moved to 11.8.1 at the same time,
  because 10.17.0 declared `engines: node 20.x` and Node 20 is end of
  life.

**Step 1 is complete**, 2026-08-05. `package.json` pins Node, and
`heroku/nodejs` is configured ahead of `heroku/ruby` on **both**
applications:

```text
1. buildpack-mimalloc
2. heroku/nodejs
3. heroku/ruby
```

Finding 5 is closed once a production deploy confirms the log reports
24.19.0 and no longer warns that the Node version "is not pinned and
can change over time".

**Decided, not yet built:** steps 4 to 13 of
[The plan](#the-plan).

**Steps 3 to 5 are done** on branch `build_env_image`: there is no test
image at all. See
[Steps 3 to 5](#steps-3-to-5-and-why-they-turned-into-a-deletion).

**Chrome:** decided, built, and **merged** 2026-08-05 as pull request
2902, a second container; see
[Chrome: a second container](#chrome-a-second-container). Landed ahead
of the new test image on purpose, so that it changes one thing against a
known-good baseline instead of arriving mixed in with a new image. CI
passed on the branch, and the subsequent staging deploy passed without
incident, so the browser move is proven twice rather than argued.

Along with it went the Node pin, the pin format change, the remote
browser support and its guard, and the resource diagnostics. `main`
therefore now contains steps 1 (repository half) and the Chrome work.

## Finding 1: a frozen image freezes its trust anchors too

`sudo apt-get update` in the `build` job failed on every run:

```text
Err:5 https://dl.google.com/linux/chrome/deb stable InRelease
  The following signatures couldn't be verified because the public key
  is not available: NO_PUBKEY FD533C07C264648F
```

| What | When |
| ---- | ---- |
| `cimg/ruby:3.4.1-browsers`, our base, was built | 2025-01-06 14:20:58Z |
| Google created signing subkey `FD533C07C264648F` | 2025-01-07 |

The base image was built the day before the key existed, so its copy of
Google's keyring cannot contain it. Today's `InRelease` verifies as
`using RSA key 0E225917414670F4442C250DFD533C07C264648F`.

Pinning by digest froze the image, and the keyring came with it. That is
pinning working as designed.

**The lesson, which outlives this repository.** Two different things
want pinning, at different layers:

* **Artifacts** (images, actions, gems, CLIs) pin by **digest**.
  Identity is the content; freshness comes from a deliberate bump.
* **Trust anchors** (signing keys) pin by **fingerprint**, and fetch the
  material fresh. Identity is the long-lived master key; the material
  must rotate.

Google's master key `EB4C1BFD4F042F6DDDCCEC917721F63BD38B4796` was
created 2016-04-12 and has no expiry. Under it are eight signing
subkeys rotated roughly annually; the newest, `1D09C015006FEAB8`, was
created 2026-03-10 and is not yet in use.

We did not need that here, because nothing in the job uses apt. Checked,
not assumed: there is no `apt-get install` anywhere in
`.circleci/config.yml`; `browser-tools/install-chromedriver` fetches
chromedriver with `curl` and only apt-installs on yum-based systems; and
nothing `rake default` runs touches apt.

It still matters, because `dockerfiles/3.4.1-browsers/Dockerfile:31`
runs its own `apt-get update`. Rebuilding our layer against the same
frozen base would hit the same error.

## Finding 2: the test image is nineteen months old

`.circleci/config.yml` pins `drdavidawheeler/cii-bestpractices` by
digest; that pin arrived in commit `816568f1` on 2025-10-24 and has not
changed. It is built `FROM cimg/ruby@sha256:a0b57bca…`, built
2025-01-06.

This is not a production exposure. Staging and production do not run our
Docker images: the deploy is `git push heroku`, and Heroku builds a slug
with its own Ruby buildpack. Our images are used by CircleCI only.

**The problem is the procedure, not the age.**
`dockerfiles/how-to-create-image.md` describes seven manual steps and
needs DockerHub push access to a personal account. Anything that manual
is out of date most of the time, so "rebuild it" is a reprieve, not a
fix.

## Finding 3: Ruby is nine patch releases behind

The staging deploy of 2026-08-04 reported:

```text
###### WARNING:
       There is a more recent Ruby version available for you to use:
       3.4.10
```

`.ruby-version` says 3.4.1, and the `Gemfile` reads that file, so it
governs both production and the test image. This is the same problem as
finding 2: upgrading Ruby means rebuilding the test image.

## Finding 4: CI tests on a different Ubuntu than production runs

Production and staging build on the **Heroku-24** stack, which is Ubuntu
24.04. Our test image is Ubuntu 22.04, shown by `jammy` throughout the
apt output. Heroku reports that Heroku-26 is available, so upgrading
production would put two LTS releases between them.

**No stock CircleCI image closes this while we are on Ruby 3.4.**
CircleCI pins an operating system per Ruby line:

| cimg-ruby line | Base | Ubuntu |
| -------------- | ---- | ------ |
| 3.4 | `cimg/base:2026.03-22.04` | 22.04 |
| 4.0 | `cimg/base:2026.03` | 24.04 |

`cimg/base:2026.03` and `cimg/base:2026.03-24.04` share digest
`sha256:fdfacc6c…`, so the unsuffixed tag is the 24.04 one. Every
`cimg/ruby:3.4.x` image is Ubuntu 22.04 and will stay so, and nothing
CircleCI publishes is on 26.04 at all.

## Finding 5: the production build installs an unpinned Node

Unrelated to the image, and the one that can break a deploy. From the
same staging deploy:

```text
###### WARNING:
       Default version of Node.js changed (20.9.0 to 24.13.0)
       This version is not pinned and can change over time, causing
       unexpected failures.
```

Node is not incidental. `Gemfile:135` has `gem 'terser'`, which minifies
JavaScript through ExecJS, which uses Node, and the deploy runs
`rake assets:precompile`. So JavaScript minification for production
silently moved four major versions.

We pin CircleCI images by digest, the Codecov CLI by SHA-256, and the
Heroku CLI by SHA-512, and then let the platform choose a Node for the
production build. There is no `package.json` and no `.node-version` to
constrain it.

Heroku's fix is to place the `heroku/nodejs` buildpack ahead of
`heroku/ruby` and pin the version there. See their Ruby support
reference under `devcenter.heroku.com`.

## The decision

**Approach D**, decided 2026-08-04: build the test image on the same
stack image production uses, and build it in the pipeline so no one ever
builds it by hand.

### Why not simply use a stock image

Tempting, because our custom image adds nothing that is still needed:

| What it adds | Why it is not needed |
| ------------ | -------------------- |
| `cmake` | already in `cimg/base`, 22.04 and 24.04 |
| `shared-mime-info` | its comment says "for gem mimemagic"; we use `marcel (1.2.1)`, which carries MIME data internally |
| Bundler 2.7 | `.circleci/config.yml` already installs the version named in `Gemfile.lock`, overriding the image |

But a stock `cimg/ruby` locks us to Ubuntu 22.04 while production runs
24.04 and is heading for 26.04, per finding 4. Ending image maintenance
and matching production pull against each other, and matching
production is what we were asked for. Approach D takes the maintenance
back and removes it a different way, by automating it.

### Also considered

* **Automated rebuild of the present custom image.** Same automation,
  none of the parity. Superseded by D.
* **Browser in a separate `selenium/standalone-chrome` container.**
  Decouples browser from Ruby image, needs Capybara reconfigured for a
  remote driver and the app reachable from that container. Reasonable
  later; solves a coupling that is not hurting now.
* **Building the image inside the test job.** Rejected: it spends the
  test time we are protecting.
* **A parameterized executor fed by dynamic configuration**, instead of
  a mutable stable tag. Removes the tag race entirely, at the price of
  dynamic configuration. Not worth it while the race is judged
  unlikely and self-correcting. Confirm how parameterized executors
  behave before relying on this if that judgement changes.

## The design

### The image

`FROM heroku/heroku:24-build`, pinned by digest resolved at build time,
plus Ruby, Chrome, and chromedriver.

Heroku maintains those base images: `heroku/heroku:24`, `:26`, and both
`-build` variants existed and had been rebuilt on 2026-07-29.

**Install Heroku's own Ruby binary rather than compiling.** The prebuilt
tarballs are publicly readable. The path differs by stack, which is easy
to get wrong:

```text
heroku-24/amd64/ruby-3.4.10.tgz   -> 200
heroku-24/ruby-3.4.1.tgz          -> 403   (no arch segment)
heroku-22/ruby-3.4.1.tgz          -> 200
```

under `https://heroku-buildpack-ruby.s3.us-east-1.amazonaws.com/`.

**Trap:** S3 answers 403 rather than 404 when listing is denied, so a
missing object and a forbidden one look identical. Only a **200** means
anything definite. An earlier version of this document wrongly concluded
these tarballs were private on the strength of a 403 from the path
without the architecture segment.

Using Heroku's binary means the interpreter matches production, not just
the operating system, and the build is a download rather than a compile.

**Install the Node that `package.json` pins**, 24.19.0, from the same
place Heroku's Node buildpack takes it, so CI minifies JavaScript with
the interpreter production minifies with. Node is no longer optional in
this image for a second reason: `license_finder` activates its NPM
scanner on the presence of `package.json`, so `rake default` now shells
out to `npm`. Read the version from `package.json` rather than repeating
it, so the two cannot drift.

**The base was checked before anything was built on it**, 2026-08-05,
because a missing toolchain would have sunk this approach and it is
cheaper to learn that first than last. `heroku/heroku:24-build`, 1.03 GB,
digest `sha256:a6e743f5…` at the time of checking:

| Wanted | Found |
| ------ | ----- |
| the same OS as production | **Ubuntu 24.04.4 LTS** |
| C toolchain | `gcc`, `g++`, `make`, `pkg-config`, `patch` |
| `libpq` for the `pg` gem | `libpq-fe.h` and `libpq.so`, present |
| common gem headers | `zlib.h`, `openssl/ssl.h`, `yaml.h`, present |
| `cmake` | **already present** |
| Node | absent, so we install it |
| Java | absent, and it stays that way |

`ffi.h` is the one thing missing, and it does not matter: `Gemfile.lock`
carries `ffi (1.17.4-x86_64-linux-gnu)` precompiled, so nothing builds
libffi from source.

Note `cmake`. It was one of the three things our custom image existed to
add, and the stack image has it, which removes that reason too.

**Heroku's prebuilt Ruby was then run in that image**, which is the
premise of this whole approach rather than a detail:

```text
heroku-24/amd64/ruby-3.4.1.tgz  ->  29,717,118 bytes
ruby 3.4.1 (2024-12-25 revision 48d4efcb85) +PRISM [x86_64-linux]
gem 3.6.2 | OpenSSL 3.0.13 | zlib ok | psych ok
```

So the interpreter, its OpenSSL, its zlib and its YAML all work as
downloaded, with no compilation at all.

**And the whole bundle installs on it.** Run 2026-08-05, unelevated, in
frozen mode:

```text
Bundle complete! 84 Gemfile dependencies, 215 gems now installed.
The Gemfile's dependencies are satisfied
20 gems built native extensions, including pg, bcrypt, sassc,
puma, nio4r, msgpack, prism, racc, json, bootsnap, websocket-driver
```

328 seconds cold. Two things that proves beyond "it worked": the
toolchain and `libpq` are real, because twenty gems compiled against
them; and **frozen mode passing means `Gemfile.lock` is satisfiable as
written on this platform**, which was a genuine open question, since
`PLATFORMS` lists `x86_64-linux-gnu` and `x86_64-linux-musl` but no bare
`x86_64-linux`, and that is what `RUBY_PLATFORM` reports.

The 328 seconds is also the argument for the image *not* carrying our
gems. CI restores a dependency cache, 115 MiB, and installs into it. The
image supplies Ruby, Node and a toolchain; the gems stay the job's
business.

### Three things the base forces on the CI configuration

None of these are guessable from reading `config.yml`, and each would
have surfaced at step 4 as a puzzling red job.

* **The image is not root.** `Config.User` is `heroku`, uid 1000, and
  `/usr/local`, `/opt` and `/app` are unwritable by it; only `/tmp` is.
  So the `Dockerfile` becomes root to install Ruby, `chown`s the tree to
  `heroku`, and drops back. An earlier smoke test appeared to succeed
  only because it happened to install into `/tmp`.
* **There is no `sudo` in the image**, and `.circleci/config.yml` uses
  it to install bundler. That `sudo` has to go, which is fine, because
  with the Ruby tree owned by `heroku` nothing needs elevating.
* **`gem install bundler` needs `--force`, and `yes |` will not do.**
  Heroku's tarball ships bundler **2.6.2** and its own `bundle`
  binstub, which belongs to no gem, so RubyGems refuses:
  `"bundle" from bundler conflicts with /usr/local/ruby/bin/bundle`.
  That is an error, not a prompt, so the `yes |` in `config.yml` cannot
  answer it; it works on the present `cimg` image only because there the
  binstub *is* gem-owned and genuinely prompts. `--force` skips the
  overwrite check. `Gemfile.lock` wants 2.7.2, so replacing 2.6.2 is
  required rather than optional.

**No browser goes in this image.** Chrome runs as a second container;
see [Chrome: a second container](#chrome-a-second-container).

### Superseded: the image, its registry, and its cache key

Between them, "Pinning", "Caching, and why the check is in the
pipeline", "Why not CircleCI's own cache" and "Registry rate limits"
described building a test image in the pipeline, publishing it, and
keying a cache on the base digest and a recipe hash. **All of that is
gone**, replaced by installing Ruby and Node into `$HOME` on Heroku's
own stack image; see
[Steps 3 to 5](#steps-3-to-5-and-why-they-turned-into-a-deletion).

The reasoning is not preserved here in full, because a design record
that contradicts the code is worse than one that is merely shorter.
Three durable facts from it are worth keeping:

* **A CircleCI docker executor's image must come from a registry.** Its
  image is resolved from static configuration before any step runs, so
  `restore_cache`, which is a step, can never supply it. This is what
  forced a registry for as long as we had an image to publish, and it is
  why the answer was to stop having one.
* **That is a fact about the docker executor, not about CI.** A machine
  executor can `docker load` a cached tarball and run tests inside it.
  It was not chosen because it restructures a working pipeline: our
  PostgreSQL and Chrome containers work *because* they are secondary
  containers sharing localhost, every step runs natively, and machine
  executors start more slowly and cost more.
* **A cache key over an image needs both the base digest and a hash of
  the recipe.** The base alone cannot notice that we changed the
  recipe; the recipe alone caches through an operating system security
  update. This mattered enough to be a recorded design error, and is
  recorded here in case an image ever returns.

## Chrome: a second container

Decided 2026-08-05. Chrome leaves our image entirely and runs as a
second container, `selenium/standalone-chrome`, beside `cimg/postgres`
in the `ruby-postgres` executor. Capybara talks to it over a URL.

**The deciding reason is upgrades, not decoupling.** As an image pinned
in `.circleci/config.yml`, Chrome falls under Renovate's `circleci`
manager, which we are adding anyway. A new Chrome then arrives as an
ordinary pull request, which is the whole interface described under
[Keeping pins current](#keeping-pins-current), with no bespoke
mechanism. Every other option needs something built to keep Chrome
fresh, which is the exact failure this document exists to end.

**Chrome's own version is pinnable.** The image publishes Chrome-version
tags, not merely Selenium ones:

```text
150.0.7871.124
150.0.7871.124-chromedriver-150.0.7871.124-grid-4.46.0-20260707
150.0
```

Pin the plain exact-Chrome tag plus a digest. Chromedriver is matched to
Chrome by construction inside the image, the Grid version rides along in
the digest, and a short tag changes when Chrome changes, which is the
signal worth seeing in a pull request title.

It also **closes finding 1 rather than managing it**: our `Dockerfile`
never adds Google's apt repository, so there is no keyring to rotate,
and the `browser-tools` orb goes away with it.

### Why the usual objection does not apply

A single standalone container serves one session at a time
(`SE_NODE_MAX_SESSIONS=1`), which normally collides with parallel tests.
We never need more than one. `lib/tasks/default.rake:25` says
`test:optimized` "runs regular tests (parallelized) then system tests
(serial)", and `test/test_helper.rb:148` gives the reason: system tests
are serial because `Capybara.server_port` is fixed at 31337. The scale
is 22 test cases in 10 files. Parallel system tests are blocked today by
that fixed port, not by the browser, so this decision forecloses
nothing.

Checked, and we use none of the APIs a remote browser complicates: no
`attach_file` and therefore no file-detector problem, no `within_window`
or `switch_to`, no browser-log reading, no download assertions.

### Where the change goes, which is not where it looks

**Not in `Capybara.register_driver`.**
`ActionDispatch::SystemTesting::Driver#register` calls
`Capybara.register_driver` under its own name, `:selenium`, and makes it
current, so our `Capybara.register_driver :headless_chrome` block is not
what system tests run. Rails builds the driver from
`driven_by`, and passes `options:` straight through to
`Capybara::Selenium::Driver.new`:

```ruby
SELENIUM_REMOTE_URL = ENV.fetch('SELENIUM_REMOTE_URL', nil)
SELENIUM_OPTIONS =
  if SELENIUM_REMOTE_URL
    { browser: :remote, url: SELENIUM_REMOTE_URL }
  else
    {}
  end

driven_by :selenium, using: driver || :headless_chrome,
          screen_size: [1400, 1400], options: SELENIUM_OPTIONS do |option|
```

**`browser: :remote` does real work, and is not decoration.**
`Driver#initialize` reads
`@browser.preload unless @options[:browser] == :remote`, and `preload`
is what resolves a *local* chromedriver through Selenium Manager. Pass
only `url:` and a machine with no browser still tries to download one,
which is the cost we are removing. This does mean the driver becomes a
`Remote::Driver` rather than a `Chrome::Driver`, correcting an earlier
claim here that the class would not change. Nothing we do needs the
Chrome subclass, and the `driven_by` block still configures Chrome
options, which the run below confirms.

**Everything else stands.** The block's `no-sandbox` and
`disable-dev-shm-usage` arguments, Rails' own `--headless`, and
`screen_size` all reach the remote browser unchanged.

### The experiment, including how it first lied

Run 2026-08-05 against `selenium/standalone-chrome:150.0.7871.124`
(digest `sha256:95690147…`) on `--network host`, to match CircleCI's
shared-localhost topology, with the container's default 64 MB
`/dev/shm`, because CircleCI gives no way to raise it.

| Run | Result |
| --- | ------ |
| Baseline, local Chrome, 22 tests | 197 assertions, 0 failures, 104.3s |
| Remote, 22 tests | 197 assertions, 0 failures, 104.1s |
| Negative control, container stopped | `Errno::ECONNREFUSED` on every test |

**The first attempt passed while proving nothing**, because the change
had been made in the `register_driver` block that Rails does not use.
The tests were quietly still driving local Chrome. What exposed it was
asking the container what it had done: `docker logs` showed **zero**
sessions created. The negative control is now the standing check, since
a configuration that cannot fail when the browser is absent is not
testing the browser.

The container log confirms the real run: one session, `browserName
chrome`, `browserVersion 150.0.7871.124`, `chromedriverVersion
150.0.7871.124`, matched by construction, with our arguments present as
`[--disable-search-engine-cho…, --headless, no-sandbox,
disable-dev-shm-usage]`. No crash, no shared-memory complaint.

Both questions this was meant to settle came out yes: **the browser
container reaches the application on localhost**, and **64 MB of
`/dev/shm` is survivable**, the latter because
`test/application_system_test_case.rb` has passed
`disable-dev-shm-usage` all along. There is no measurable time cost;
104.1s against 104.3s is noise.

### Keeping a headed browser available

Remote and headless is what CI wants; a person debugging a test wants
the opposite. Both already work, because `DRIVER` and
`SELENIUM_REMOTE_URL` are independent and all four combinations are
valid. Verified 2026-08-05, each one run:

| `DRIVER` | `SELENIUM_REMOTE_URL` | Result |
| -------- | --------------------- | ------ |
| unset | unset | local, headless. The local default |
| unset | set | remote, headless. What CI does |
| `chrome` | unset | local, headed. A window opens here |
| `chrome` | set | headed in the container, watchable over noVNC |

Rails adds `--headless` only for `:headless_chrome`, so `DRIVER=chrome`
is genuinely headed: the container log for the fourth row shows
`args: [--disable-search-engine-cho…, no-sandbox,
disable-dev-shm-usage]` with no `--headless`, and the image's noVNC
answers on port 7900.

**No new knob.** `DRIVER` already existed, is already used by
`docs/testing.md`, and adding a `HEADED` alias would be a second way to
say one thing. What was missing was accurate documentation, since
`docs/testing.md` was still describing `test/features/`, which no longer
exists, and `poltergeist`, which left the `Gemfile` long ago.

One caveat, unresolved: headed runs failed intermittently in the
development container used for this work, roughly twice in eight runs,
then five times clean in a row, and the message was never captured.
Headed mode is the only path needing a real X display, which is the
fragile part of that environment. Watch for it on a real desktop before
concluding anything.

### A green suite is not evidence, so we made it evidence

The false pass above was not a one-off risk; while the old test image
still carries a Chrome, *any* mistake in wiring up the remote browser
fails silently into a local one, and the suite goes green. CI would have
told us nothing.

So `test/system/system_test_configuration_test.rb` now carries a guard:
if `SELENIUM_REMOTE_URL` is set, the driver must actually be using it.
It asserts twice on purpose, once that we asked for the right thing and
once that asking worked, since reading `page.driver.browser` forces a
real session to exist.

It was tested by breaking the thing it guards. With the configuration
deliberately reverted to ignore `SELENIUM_REMOTE_URL`, exactly
reproducing the earlier bug, the guard failed as it should:

```text
Minitest::Assertion: Expected: "http://127.0.0.1:4444"
3 tests, 5 assertions, 1 failures, 0 errors, 0 skips
```

It skips when the variable is unset, so local work is unaffected. A
guard that has never been seen to fail is a guess.

### What went into the pipeline

* A third container in the `ruby-postgres` executor,
  `selenium/standalone-chrome:150.0.7871.124@sha256:95690147…`, and
  `SELENIUM_REMOTE_URL: http://127.0.0.1:4444` in the primary
  container's environment.
* **A readiness wait.** CircleCI starts secondary containers but does
  not wait for what is *inside* them, and the grid takes a few seconds,
  so the first system test would otherwise race the browser's startup.
  The step polls `/status` and fails loudly after 60 seconds. Both its
  patterns were checked against real output rather than guessed.
* **The `browser-tools` orb is gone**, and with it the last orb, so the
  `orbs` key no longer exists. Chrome's own container carries a matched
  chromedriver.
* `google-chrome --version` dropped from the version banner. The Chrome
  that matters is in the other container, and the wait step prints it.
  Any Chrome in the test image is not the one under test.

### What the green run actually reported

Measured in CI 2026-08-05, from the first pipeline with the browser in
its own container:

```text
ruby 3.4.1 (2024-12-25 revision 48d4efcb85) +PRISM [x86_64-linux]
v22.12.0
CPUs visible: 36
memory limit (cgroup v2): 4294967296
Mem: 4096 total   Swap: 0
```

So `resource_class: medium` is **exactly 4 GiB and no swap**, which we
had never confirmed. Against that, the browser container's measured 719
MB peak is comfortable.

**36 is not what we are allowed. The real allowance is 2.** The Selenium
container, in the same job, reported:

```text
[NodeOptions.getSessionFactories] - Detected 2 available processors
```

The two numbers are both correct, and the gap between them is the
finding. **A CPU quota and a CPU affinity mask are different things, and
different programs read different ones.** Demonstrated locally
2026-08-05 rather than argued:

| Reader | Sees | Because |
| ------ | ---- | ------- |
| `nproc`, and Ruby's `Etc.nprocessors` | the host's count | reads the affinity mask |
| a container-aware JVM | the real allowance | reads the cgroup quota |

Running a container under `--cpus=2` gives `cpu.max: 200000 100000`, a
quota of exactly two processors, while `Cpus_allowed_list` stays `0-3`
and `nproc` still says 4. And under `taskset -c 0,1`,
`Etc.nprocessors` drops to 2, which is what shows it follows the mask.
So a quota constrains what we may *use* without changing what we may
*see*.

**So Java was never the problem here; we are.** CircleCI's warning about
`/proc`-reading runtimes is real in general, but the JVM has been
container-aware for years and got this right. Ruby did not.
`test/test_helper.rb` says
`parallelize(workers: :number_of_processors, with: :processes)`, and
`:number_of_processors` is `Etc.nprocessors`. So CI forks **36 Rails
test worker processes, each with its own test database, for an
allowance of 2 processors** inside 4 GiB with no swap. Eighteen times
oversubscribed.

This is not new and not currently breaking: it predates all of this work
and the suite passes. It is recorded, and not yet changed, because the
right worker count is a measurement and only CI can take it.
`ENV["PARALLEL_WORKERS"]` overrides the count, so the experiment is one
variable: try 2, then 4, compare wall time against the present 36, keep
the winner. Do not assume lower is faster, and do not assume it is
slower either.

For completeness, Selenium sized itself correctly off that same
detection: `max-sessions = 1`, which is what serial system tests need.

**Node in the test image is v22.12.0.** That is a third version in play,
against the 24.19.0 that `package.json` pins for production and that the
`deploy` job's image carries. One more reason the new image should
install the Node `package.json` names, and evidence that the current
image drifted from production in more ways than Ruby and Ubuntu.

### The resource budget, now measured rather than assumed

`.circleci/config.yml:105` sets `resource_class: medium` on the `build`
job, and has since commit `687477ba`. That is good practice in itself:
CircleCI's reference says the default "is subject to change" and that
specifying one explicitly is preferred. The `deploy` job sets none and
so takes that changeable default.

**What `medium` grants is now measured**, and the memory half of the
familiar "2 vCPU, 4 GB" is confirmed exactly: 4294967296 bytes, no swap.
The CPU half is not confirmed and cannot be read from inside, because
`nproc` reports the host's 36; see the run above. The version-banner
step keeps printing both, which is the method CircleCI's own reference
recommends, so a future stack or plan change shows up as data rather
than as a surprise. The block handles cgroup v1 and v2, since v2
replaced `hierarchical_memory_limit` with `memory.max`, and says so
plainly rather than failing if neither is readable.

The budget is shared by every container in the job, and adding a
Java-plus-Chrome container made it tighter without anyone measuring it.
If the grid never becomes ready, or a container is killed, that is the
first place to look, and `large` is the first thing to try.

### Trimming the browser container, measured

Asked 2026-08-05 whether the container could be made cheaper, on the
reasoning that we run Java but never compile it, so a JRE would do.
That instinct is right about the image and wrong about the cost. The
image is a **JDK**, `javac` and all, and 2.12 GB, but a JDK costs disk
and pull time rather than memory. Selenium publishes no JRE variant,
and building our own would reintroduce exactly the maintenance this
whole document exists to remove.

The saving is elsewhere. The image ships a **desktop**, so that a person
can watch a test over VNC:

```text
java 149MB   Xvfb 40MB   python3 x4 104MB   supervisord 28MB
x11vnc 19MB  fluxbox 15MB  pulseaudio 13MB
```

Headless Chrome needs none of the display half. Setting
`SE_START_XVFB=false` and `SE_START_VNC=false` removes Xvfb, x11vnc and
fluxbox:

| Container | Idle | Peak during suite | Result |
| --------- | ---- | ----------------- | ------ |
| as shipped | 233 MB | 816 MB | 23 tests, 199 assertions, pass |
| display off | 174 MB | 719 MB | 23 tests, 199 assertions, pass |

**Do not also cap the JVM heap.** `SE_JAVA_OPTS=-Xmx256m` looks like
free money and is not: it saves nothing measurable, since the JVM's
resident size is about 145 MB either way and its default maximum is
already a fraction of container memory, and combined with the display
settings it produced **18 errors** of `Net::ReadTimeout` across the
suite. Isolated by testing each change alone, which is the only reason
we know which one was at fault: the display settings pass on their own,
and adding the heap cap to them is what breaks it.

A suspicion worth recording as *disproved*: that Chrome needs `fluxbox`,
or a window manager at all. It does not, headless. The full suite passes
with Xvfb, x11vnc and fluxbox all absent.

**Nothing we build or test uses Java.** Checked: no JVM-backed gem, and
nothing in `rake default` invokes one. The only Java that matters is
Selenium Grid's, inside its own image. So `java --version` has left the
version banner, and the new test image should install no JDK at all.

### Headless does not mean blind

Asked whether a failing headless test can still be photographed,
expecting no. It can, and the machinery was already there. Verified
2026-08-05 by failing a test on purpose against the container in its CI
configuration, headless with no Xvfb, VNC or window manager: Rails'
`take_failed_screenshot` produced a **1400x1257 PNG showing a fully
rendered page**, fonts, artwork, sponsor logos and all. The compositor
still paints; there is simply no X server showing it to anyone.

It lands in `Capybara.save_path`, which is `tmp/capybara`, and
`.circleci/config.yml` already stored that directory as an artifact. So
failure screenshots have been uploaded all along and continue to be now
that the browser is remote.

Added `RAILS_SYSTEM_TESTING_SCREENSHOT_HTML=1`, which saves the page's
HTML beside the image. For a selector or layout failure the DOM usually
says more than the picture, and it is the DOM *after* JavaScript, which
the server response cannot show. Rails compares against exactly the
string `"1"`, so the value is quoted in the YAML. Confirmed both files
appear, 390 KB of PNG and 19 KB of HTML.

A diagnostic learned by accident: the failed `-Xmx256m` run left
**zero-length** PNGs. An empty screenshot means the browser stopped
answering, not that the page was blank.

**A related trap, from CircleCI's own reference.** Java and other
runtimes that introspect `/proc` for CPU count "may request 32 CPU
cores and run slower than they would when requesting one core" under
resource classes. Selenium Grid is a Java program. If the grid is
mysteriously slow rather than absent, this, not memory, is the likely
cause, and the cure is to pin its thread count rather than to buy a
larger machine.

### Two dead fragments found while doing this

Neither blocks the change, and both should go in a separate cleanup.

* The whole `Capybara.register_driver :headless_chrome` block is
  unreachable from system tests, per the finding above, and nothing
  outside `test/system/` uses Capybara. Inside it,
  `driver.browser.download_path = Capybara.save_path` and
  `browser_options.binary = ENV.fetch('GOOGLE_CHROME_SHIM', nil) if
  ENV['CI']` are dead twice over: `GOOGLE_CHROME_SHIM` is a Heroku
  buildpack convention CircleCI never sets, while `CI` always is, so
  that line assigns nil on every CI run.
* Rails' `default_chrome_options` already adds `--headless` for
  `:headless_chrome`, so the block's own `--headless` is a duplicate of
  something we no longer reach.

### The orb is redundant, which is why dropping it is safe

Established 2026-08-05 by running Selenium Manager directly, the same
binary Selenium invokes:

| Situation | What it resolves |
| --------- | ---------------- |
| No `chromedriver` on `PATH` | one from `~/.cache/selenium`, downloading on a miss |
| `chromedriver` on `PATH` | the one on `PATH` |

Nothing in our code sets `driver_path`, so `DriverFinder` runs Selenium
Manager on every driver creation, and this machine has no `chromedriver`
on `PATH` at all yet holds cached drivers for Chrome 141 through 150. So
`browser-tools/install-chromedriver` is used in CI but not needed:
remove it and Selenium Manager fetches an equivalent driver from the
same place. Under this decision neither is involved, because the driver
lives in the Selenium container.

While looking: the WebMock and VCR allowances for
`chromedriver.storage.googleapis.com/LATEST_RELEASE_*`,
`googlechromelabs.github.io` and `storage.googleapis.com` in
`test/test_helper.rb` are stale. They date from the `webdrivers` gem,
which we no longer use, and they could not affect Selenium Manager in
any case, since it is a separate binary run as a subprocess and WebMock
patches Ruby HTTP libraries. Harmless, but they describe a mechanism
that no longer exists, which is worse than saying nothing.

## Steps 3 to 5, and why they turned into a deletion

**Done 2026-08-05.** There is no test image. The `build` job runs
directly on `heroku/heroku:24-build`, Heroku's own published stack
image, and installs Ruby and Node into `$HOME` in about fourteen
seconds. No `Dockerfile`, no registry, no credential, no
`prepare-image`, no cache key, no mutable tag, no waiting.

That is the answer to findings 1, 2 and 4 together, and it is a smaller
answer than the one this document spent a day designing.

### Which Heroku image, and why it is the build one

`heroku/heroku:24-build`, not `heroku/heroku:24`. They are different
images and the distinction is easy to get backwards:

| Tooling | `:24` (run) | `:24-build` (ours) |
| ------- | ----------- | ------------------ |
| gcc, g++, make | absent | present |
| libpq headers | absent | present |

`:24` is what production **dynos run on**. `:24-build` is what Heroku
**compiles the slug in**. We need the build variant because twenty of
our gems build native extensions, and the run image has no compiler.

So we match production's *build* environment exactly and its *runtime*
environment approximately: same stack, fewer packages in production.
That gap does not matter, because gems are compiled during
`bundle install`, not at runtime.

Note also that Ruby and Node are not test-only additions. Heroku's
`ruby` and `nodejs` buildpacks install exactly those onto exactly this
image when building a slug, so the job is doing roughly what the
buildpack does. The parity is structural rather than accidental, and
nothing in the executor exists only for testing.

### How it got there, because the route matters

**Moving Chrome out first is what made this possible**, and it was
necessary rather than incidental. While the test environment had to
carry a browser, it had to add Google's apt repository, which is
finding 1 walking back in with us owning the key rotation. Only once
Chrome lived in its own pinned container did "just use the stack image"
become available at all.

Approach D was right that CI should run on the same stack as
production. It was wrong to assume that meant *building an image*. The
question "can we cache the image instead of publishing it?" led to a
better one: **does the image have to carry the tools at all?**

It does not. Measured on the stack image, unelevated:

```text
Ruby 3.4.1 from Heroku's tarball ->  5.6s
Node 24.19.0 from nodejs.org     ->  8.7s
```

Fourteen seconds, against a custom image 250 MB larger than the base
precisely because it contained those two things. Pulling them as layers
or fetching them directly is roughly a wash, and the fetch costs no
registry.

`bundle install` then works exactly as it did in the built image: 84
dependencies, 215 gems, 20 native extensions, frozen mode satisfied. It
was in fact **faster in the job than in the image build**, 139 seconds
against 328.

### What this deletes

* The `Dockerfile`, and any procedure for rebuilding it. Finding 2 was
  never really about the image being stale; it was about a manual chore
  that therefore did not happen. The way to end a chore is to remove the
  thing it maintains.
* The registry, and with it the GHCR package, the organisation
  permissions, the machine account, the classic token that would have
  expired at inconvenient times, and the CircleCI context to hold it.
* `prepare-image`, the two-part cache key, the `current` tag and its
  race, and the parameterized-executor escape hatch that race would
  eventually have needed.
* The GitHub Actions publishing workflow considered as an alternative,
  and the polling job that would have waited for it.

The only secret CircleCI holds remains `HEROKU_API_KEY`, in the deploy
job, which is the one that genuinely must exist.

### What survives, because it was never about the image

Every finding from building the image still applies, since the same
base is now the executor:

* **It runs as uid 1000 `heroku` with no `sudo`**, so every step must
  work unelevated. Ruby goes in `$HOME` for exactly this reason.
* **`LANG` is unset**, giving `LC_CTYPE=POSIX` and a US-ASCII default
  encoding. Set in the executor's environment, and a step now asserts
  `Encoding.default_external == Encoding::UTF_8` so this fails with a
  sentence rather than as a mangled character in some later test.
* **`gem install bundler` needs `--force`, and `yes |` cannot help.**
  Heroku's tarball ships a `bundle` binstub owned by no gem, so RubyGems
  raises rather than prompting. The old `sudo sh -c 'yes | gem install'`
  is now an unelevated `gem install --force`.
* **No JDK, no browser, no `psql`.** Nothing we test uses a JVM, Chrome
  is a separate container, and `db/schema.rb` is Ruby-format.

### Staleness, which is the whole point

`heroku/heroku:24-build` is pinned by tag and digest in
`.circleci/config.yml`, beside PostgreSQL and Chrome. So **Renovate
proposes its upgrades with no mechanism of our own**, exactly as it will
for the other two. That is the same argument that decided Chrome, and it
is what the elaborate cache-key design was reinventing by hand.

The Ruby and Node versions come from `.ruby-version` and
`package.json`, the files that already govern them, so there is no third
place to forget.

### Costs, stated plainly

* **Fourteen seconds per build**, unavoidable and uncached; caching 269
  MB would likely cost more than re-fetching 60 MB compressed.
* **Two more hosts must be up during a build**, S3 and `nodejs.org`,
  where before only the registry had to be. Not a new category, since
  `bundle install` already needs rubygems.org, but it is more surface.
* **Less integrity than a digest-pinned image.** Node is verified
  against `SHASUMS256.txt`. Heroku publishes no checksum for its Ruby
  tarball, so that download is trusted on the strength of HTTPS and a
  version-specific URL. Recording our own SHA-256, as the Heroku CLI pin
  does, is possible and would need updating on each Ruby bump; not done,
  and worth revisiting if the exposure ever matters.
* **DockerHub rate limits** are not a concern today: CircleCI's own
  documentation says that since 2020-11-01 pulls through CircleCI are
  not rate limited, by arrangement with Docker. If that changes, the fix
  is an `auth:` block with a read-only token, and only then. This also
  corrects an argument made earlier for `ghcr.io` on metering grounds,
  which does not apply through CircleCI.

## The cache broke, and it was worse than it looked

Found 2026-08-05, on the first staging deploy after the executor
changed. `bundle install` took 2m06s on a supposedly warm cache, and
`restoring cache` took 27 seconds to achieve nothing.

**Two separate bugs, both mine, and the second is the expensive one.**

### Bug 1: the key matched a cache that could not be written

CircleCI stores cache paths as **absolute** paths. The cache had been
saved by the old image, whose user was `circleci`:

```text
Cached paths:
  * /home/circleci/.rubygems
  * /home/circleci/ossf/best-practices-badge/vendor/bundle
```

The new executor runs as `heroku`, cannot create `/home/circleci`, and
the key contained nothing that distinguished the two environments. So
the restore matched, then failed on every single file:

```text
Skipping writing "home/circleci/.rubygems/" - mkdir /home/circleci: permission denied
   ... 23,404 times ...
Extraction duration: 27.154492978s
```

**The fix reads the environment rather than describing it.** A step
before `restore_cache` writes the three things that decide
compatibility, and the key hashes that file:

```text
heroku
/home/heroku
ubuntu-24.04
```

The first attempt at this was a hand-written `v2-heroku24` token, which
would have needed changing by hand on every image or stack move. That is
the sort of chore this document exists to remove, and the stack number
had no business being hardcoded. Reading `id -un`, `$HOME` and
`/etc/os-release` instead means a stack upgrade changes the key by
itself, and nothing needs bumping.

Checked against both images: the old one gives
`circleci | /home/circleci | ubuntu-24.04` and the new one
`heroku | /home/heroku | ubuntu-24.04`. Note the OS is identical, so
hashing the OS alone would *not* have caught this; it was the user and
home that differed. All three parts earn their place.

**Why hash a 33-byte file instead of using the values directly?** A
cache key can only interpolate CircleCI's own templates, and
`{{ .Environment.X }}` is restricted to variables CircleCI exports or a
context supplies, "not any arbitrary environment variable".
`{{ checksum }}` on a file is the only way to get a runtime value into a
key at all. The hashing is a consequence, not a choice, and the step
prints the file so the log stays readable.

### Bug 2: the cached paths held no gems at all

Worse, because it would not have healed itself. With Ruby installed
under `$HOME`, gems no longer live where the old key looked:

```text
Gem.dir      = /home/heroku/ruby/lib/ruby/gems/3.4.0   <- where gems go
~/.rubygems                                            <- what we cached
```

`~/.rubygems` was where the **cimg** image put `GEM_HOME`; on this
executor it does not exist. And `vendor/bundle` is empty because no
`--path` is set. So even with a corrected key, every build would have
reinstalled every gem, for ever, and the cache would have looked healthy
while doing it.

**The fix caches `~/ruby`**, which holds the interpreter *and* every gem,
since `Gem.dir` is inside it. That also removes the Ruby download on a
hit, so the restore now covers more than it ever did.

`~/node` is deliberately not cached: 205 MB extracted to save an 8.7
second download is a bad trade.

### And a third thing, which was never right

The old key ended in `{{ .Branch }}` with **no fallback keys at all**, so
every new branch started completely cold no matter how many identical
gem sets were already cached. That alone is a large part of why
iterating felt slow. There are now three keys, progressively looser:

| Key | Matches |
| --- | ------- |
| `…-{{ checksum "Gemfile.lock" }}-{{ .Branch }}` | this Ruby, these gems, this branch |
| `…-{{ checksum "Gemfile.lock" }}-` | this Ruby and these gems, any branch |
| `…-{{ checksum ".ruby-version" }}-` | this Ruby, any gems |

`{{ arch }}` comes before the checksums so the looser fallbacks cannot
cross architectures.

### Guarded, and tested by breaking it

Because the cache now carries the interpreter, a stale cache could
silently test the wrong Ruby. The install step therefore verifies rather
than trusts: it runs `$HOME/ruby/bin/ruby -v` to decide whether the
cache really delivered something usable, and then compares the result
against `.ruby-version`. Verified all three ways:

```text
miss  -> Installing Ruby 3.4.1 for heroku-24
hit   -> Ruby restored from cache: ruby 3.4.1 ...
stale -> ERROR: .ruby-version says 3.4.10, but the Ruby
         in $HOME is 3.4.1. Refusing to test the wrong one.   (exit 1)
```

## The deploy job, and what was actually slow in it

Asked 2026-08-05 whether a 51 second "Install Heroku CLI tools" and a
3m08s "Deploy to Heroku" were caused by the cache breakage. **Neither
was**: the deploy job uses the `deploy-only` executor and has no
`restore_cache` at all. They are two separate stories.

### The CLI install was ours, and worth fixing

Measured: the published tarball is **592 KB**, and `npm install -g`
turns it into **381 MB across 45,233 files**. For a tool we use for
exactly three commands.

It is now cached, keyed on a file holding the version, so a version bump
invalidates the cache by itself. The install step checks by *running*
the restored binary and matching `heroku/<version>` in its output,
rather than testing for a directory, so a half-restored cache
reinstalls instead of failing later.

Verified the detection both ways: it matches
`heroku/11.8.1 linux-x64 node-v22.23.1` and does not match a different
version.

A standalone tarball would avoid npm entirely, but Heroku publishes it
only at unversioned channel URLs, which cannot be pinned, so it is not
an improvement under our pinning policy.

**Longer term, two of the three CLI uses do not need a CLI at all.**
`heroku git:remote` only sets a git remote URL, and `maintenance:on/off`
is one Platform API call. Only `heroku run` for the migration genuinely
needs it, because an attached one-off dyno is real work to reproduce. If
that is ever solved, 381 MB leaves the deploy job.

### The deploy itself is mostly Heroku's time

`git push heroku` blocks while Heroku builds the slug: bundle install
and `assets:precompile`, on their machines. Very little of 3m08s is
ours.

That figure is also **not a fair baseline**. Release v844 was the first
deploy after `heroku/nodejs` joined the buildpack chain, which
invalidates Heroku's build cache and adds a Node install. Compare the
next one before concluding anything.

One thing in that step *was* ours: the push ran under
`GIT_CURL_VERBOSE=1 GIT_TRACE=1`, which log every HTTP header and git
operation. They arrived with "Fix git push to heroku (#1798)" in **March
2022** as debugging aids for a problem long since fixed, and stayed four
years, burying the Heroku build output that actually matters. Removed,
with a note to set them temporarily rather than permanently.

## Migrations move to a release phase

Done 2026-08-05, on its own so it could be watched on staging before
anything else in the deploy job moved.

**Verified on staging**, release v845, `Deploy 09446ffe`. Maintenance
mode came back off by itself, and the release history shows something
worth noticing: the earlier deploy, which failed at the baseline check,
created **no release at all**. It refused before pushing, so there is
nothing orphaned between v844 and v845. A failure that leaves no trace
is the point of checking before the push rather than after it.

Still unproven: the failure path, that a broken migration blocks the
release and turns CI red. Everything about it is documented and
simulated, and the guard has now refused a real deploy for a real
reason, but nobody has yet watched a migration fail on purpose.

`Procfile` now carries `release: bundle exec rails db:migrate`. Heroku
runs that in a one-off dyno after a successful build and **before any
dyno boots on the new release**, and its documentation is explicit: "If
the release command exits with a non-zero exit status ... the release is
not deployed to the app's dyno formation."

That is safer than what it replaces, not merely cheaper. Previously CI
pushed the slug and ran the migration afterwards, so a failed migration
left the new code already live against an unmigrated database. Now a
failed migration means the new release never goes live and the previous
one keeps serving.

### Do not trust the push's exit status. It is undocumented.

Asked directly whether `git push heroku` fails when the release phase
fails, "even if it does today, it might not in the future unless
something documents that". Checked, and the answer is that **it is not
documented**. Heroku says only:

* "It is possible for a *build* to succeed and its associated *release*
  to fail."
* "For real-time detection during CI/CD pipelines, you would need to use
  the Platform API rather than rely solely on the `git push` exit code."

So the deploy job asks the API instead. Every part of that rests on
documented behaviour, taken from the machine-readable schema at
`https://api.heroku.com/schema` rather than from prose:

| Thing | Documented as |
| ----- | ------------- |
| `Release.status` | enum `failed`, `pending`, `succeeded`, `expired` |
| newest release | `GET /apps/{app}/releases` |
| ordering | `Range: version ..; order=desc,max=1;` |

Note `expired` is a fourth terminal state, presumably the one-hour cap,
so the check insists on `succeeded` rather than merely "not failed".

### Two traps, one of which was in my own first draft

**The release that is already live looks newest.** Poll immediately
after the push and the newest release may still be the previous one,
whose status is `succeeded`. So the job records the newest version
*before* pushing and ignores anything not greater than it.

**And that guard let a bug straight back in.** With the skip
implemented as `continue`, the loop variable `$status` still held the
*old* release's `succeeded`, so a final `[ "$status" != succeeded ]`
check passed even when a new release never appeared at all. A deploy
that produced no release would have reported success. Found by testing
rather than by reading: success is now recorded in a dedicated flag that
only the success branch sets.

### A review found two more, and they were the same mistake twice

The deploy job sets no `shell:`, so it runs under CircleCI's default
**`/bin/bash -eo pipefail`**. That matters more than it looks.

`version="$(... | grep -o ... | head -1 | cut ...)"` fails the whole
pipeline when `grep` finds nothing, and `-e` then aborts the step **with
no message**, so the retry written right beside it could never run. The
same construction can also hand `grep` a SIGPIPE when `head` exits
early, which `pipefail` turns into a failure on a *successful* match.

Both are now `grep -om1 ... || true`, with an explicit emptiness check
that retries and says so. `head` is gone from this step entirely.

The same flags also made a *third* thing wrong in principle: falling
back to `prev=0` when the current version could not be read. Zero makes
the release already live look newer than the baseline, so the check
after the push would accept it and report success for a deploy that
released nothing. Under `-e` the step happened to abort first, so it was
correct by accident. It now refuses to deploy, and says why.

A second review found the same wrong default surviving in the *other*
half of the code: the wait step still did
`prev="$(cat ... || echo 0)"`. The Deploy step guarantees that file, so
it could not bite today, but it is the identical mistake and a future
step reordering would have made it live. It now refuses rather than
guessing. Both API calls also gained `--max-time 30`, because a hung
connection could otherwise block until CircleCI's 20 minute
no-output timeout killed the job with a message pointing nowhere near
the cause.

A third pass caught a bug introduced by the second. `grep -m1` caps
matching **lines**, not matches, and this JSON is a single line, so `-o`
still emitted every match on it: with more than one release in the body,
`version` became two lines and the integer comparison would have died
with a bash error. The original `head -1` had been right about that; the
fix traded a real bug for a latent one. It now uses `sed -n 1p`, which
takes the first match and reads its whole input, so it cannot give grep
a SIGPIPE either, and the version is validated as a bare integer rather
than merely non-empty.

That case is now tested, along with the two ways the `Range` header
could let us down. If it were ignored but ordering stayed descending,
the newest release is still first and the check works. If it were
ignored *and* ordering were ascending, the oldest release comes first,
never exceeds the baseline, and the job times out and fails: wrong, but
safely wrong, never a false success.

### The first real deploy caught what testing had not

Staging's deploy failed 2026-08-05 at the baseline check:

```text
ERROR: could not read the current release version.
Refusing to deploy: the check after the push could
not then tell a new release from the live one.
```

**The Heroku API pretty-prints its JSON.** Every response arrives as
`"version": 845`, with a space, not `"version":845`. The pattern
required no space, so it never matched. Worse, `[0-9]*` matches *zero*
digits, so `grep` "succeeded" against `"version":` while capturing
nothing, which is why the failure looked like an empty response rather
than a parse error.

Every local test used compact JSON, because I wrote the fixtures from
the shape I assumed rather than from a real response. The schema
document I had already downloaded was pretty-printed the whole time and
would have shown me, had I looked at it as evidence instead of as a
lookup table.

Three things changed:

* `" *"` in both patterns, and `[0-9][0-9]*` instead of `[0-9]*` so a
  match cannot be empty.
* The fixtures now cover **both** formats, and both are tested.
* On failure the step **prints what it received**, truncated to 200
  bytes with anything resembling an address masked, since release
  objects carry the deploying user. Verified that the real address does
  not appear in the output.

The guard itself behaved correctly: it refused to deploy rather than
guessing, and left maintenance mode on. That is the design working. It
simply could not say *why*, which is now fixed.

A separate cosmetic fix: the CLI's own update check spawns `heroku`
from `PATH`, so invoking it by absolute path logged
`[ENOENT] Error: spawn heroku ENOENT`. Harmless, but it reads as a real
failure in a deploy log. The step now puts the CLI on `PATH` for itself,
not only for later steps.

Tested with canned API responses, eight paths:

```text
normal deploy             -> exit 0
migration fails           -> exit 1
release expires           -> exit 1
new release never appears -> exit 1   (the first bug)
unparsable body          -> retries, then exit 0   (the second)
API errors                -> retries, then exit 0
missing baseline          -> exit 1   (the third)
two releases in one body  -> exit 0   (the fourth)
Range ignored, ascending  -> exit 1   (safely wrong)
```

### What deliberately did not change

The unreachable recalculation branch is still there, still calling
`heroku run`. It cannot fire: `.recalculate` is matched by
`.gitignore` line 70 (`.*`) and has never been committed, so `checkout`
never produces it. Removing it, and removing the CLI it keeps alive, is
a separate change; this one is only the release phase.

Maintenance mode is also left ON when a release fails, deliberately, so
that a failure is looked at rather than cleared automatically.

## Keeping pins current

The organising principle, decided 2026-08-04: **the pull request list is
the set of decisions waiting for a human.** Nothing should require
anyone to remember to check whether an upgrade is available. Look at the
open pull requests, accept one, and it takes effect. That is the whole
interface.

It follows that a proposal must always be one we could actually accept.
A pull request that cannot be merged is not a decision waiting for a
human, it is a chore, and chores are what we are removing.

Three tools, distinct ground:

| Tool | Covers |
| ---- | ------ |
| Dependabot | `Gemfile`, npm, GitHub Actions workflows |
| Renovate | `.circleci/config.yml` images and orbs |
| `propose_ruby_upgrade` | `.ruby-version`, from what Heroku has |

Renovate does **not** manage `.ruby-version`, though it can; see
[Proposing Ruby upgrades](#proposing-ruby-upgrades-heroku-can-build)
for why we took that job away from it.

**Dependabot cannot read `.circleci/config.yml`.** It has no CircleCI
support: `dependabot/dependabot-core` carries one directory per
ecosystem, 43 of them including `bundler`, `docker`, `github_actions`
and `npm_and_yarn`, and there is no `circleci` directory. Its `docker`
ecosystem reads Dockerfiles, not CI configurations.

**Nor does it update Ruby.** Not for want of Ruby knowledge: it reads
our Ruby version already, because it must, to pick gem versions that
will run. It just does not propose upgrades to it. Issue 2254, "Update
ruby version in Gemfile", asks for exactly `Gemfile`, `Gemfile.lock` and
`.ruby-version`; opened 2018-06-28, still open.

**Renovate does both.** Its `circleci` manager supports the `docker` and
`orb` datasources. Its `ruby-version` manager declares
`displayName = '.ruby-version'`, a file pattern of
`/(^|/)\.ruby-version$/`, and the Ruby version datasource, reading the
trimmed file contents as the current version. We use the first and not
the second.

Run Renovate with `enabledManagers` limited to `circleci`. At its
defaults it also reads the Gemfile, `.ruby-version` and Dockerfiles, and
competes with Dependabot and with `propose_ruby_upgrade`.

### Prerequisite: a pin must carry its own tag

**Done 2026-08-05** for all three images in `.circleci/config.yml`, and
it had to be, or Renovate would have proposed the wrong thing quietly.
Found by reading Renovate's source.

We used to write pins with the tag in a comment:

```yaml
- image: cimg/postgres@sha256:2e4f1a96… # pin :16.4
```

`splitImageParts` in Renovate's Dockerfile manager, which its `circleci`
manager calls for every image, splits on `@` and then on `:`. With no
tag in the reference itself, `depTagSplit.length === 1`, so it records a
`depName` and leaves **`currentValue` undefined**. The comment is
invisible to it. A dependency with a digest and no tag then resolves
against `latest`:

```ts
const newTag = isNonEmptyString(newValue) ? newValue : 'latest';
const newTag = newValue ?? 'latest';
```

For `cimg/postgres` that means silently crossing PostgreSQL major
versions; for our own test image it would be simply wrong.

Write the tag where a machine can read it:

```yaml
- image: cimg/postgres:16.4@sha256:2e4f1a96…
```

Renovate then updates tag and digest together, and the tag stops being
an unverifiable comment that a human has to keep in step with the digest
by hand. That is the `AGENTS.md` rule about preferring automated
prevention to documentation, applied to a comment that had been the sole
record of what a digest means.

**The pair is self-checking, which is the part worth knowing.** Verified
2026-08-05: `docker manifest inspect` on an existing tag paired with
another tag's digest fails with `manifest verification failed`, while
each correct pair resolves. So a tag and digest that drift apart become
an error rather than a silent disagreement, which the old comment form
could never manage.

Before converting, each comment was checked against the registry rather
than trusted: all three tags resolved to exactly the digest already
pinned beside them, so nothing was encoded that was not already true.

**Scope, deliberately.** Only `.circleci/config.yml`, because that is
what Renovate's `circleci` manager reads. GitHub Actions workflows keep
`uses: owner/repo@sha  # vX.Y.Z`, which is that ecosystem's own
convention and which Dependabot parses, comment and all. Do not
"harmonise" them.

`dockerfiles/how-to-create-image.md` was updated at the same time, since
otherwise following it would reintroduce exactly the format just
removed. That file is slated for deletion at step 5 regardless.

This is worth doing on its own, ahead of everything else here, and it
covers `cimg/postgres`, `cimg/node`, the Selenium image and the new test
image.
Renovate's `custom` manager, a regular expression matcher, covers
anything version-like we later pin in a file no built-in manager knows.

A worry raised and settled: our `Gemfile` says
`ruby File.read('.ruby-version').strip`, which Bundler evaluates but a
static parser might not, and Dependabot issue 14617 concerns exactly
that. It is not biting. Dependabot will not propose a version whose Ruby
requirement it thinks we cannot meet, and it offered `bootstrap_form`
5.6.1 and merged a `simplecov` bump, both requiring `ruby >= 3.2`. What
that cannot show is whether it resolves exactly 3.4.1 or merely
"at least 3.2", since nothing in our tree requires 3.3 or 3.4. Read
Dependabot's job logs only if an update ever looks unexpectedly held
back.

### Due diligence on Renovate

`renovatebot/renovate`, started 2016-12-17, **AGPL-3.0-only**, backed by
Mend.io; the `renovatebot` GitHub organisation gives its location as
Israel and its contact as `renovate@mend.io`. It exists as a hosted
GitHub App and as the same open source program run yourself, via npm, a
container image, or `renovatebot/github-action`. **Self-host it.**
Updating our own CI configuration is no reason to give a third party
access to this repository.

Evidence, 2026-08-04: OpenSSF Scorecard **6.7**, scoring 10 on
Contributors, CI-Tests, License, SAST, Binary-Artifacts,
Security-Policy, Maintained, Dangerous-Workflow, Dependency-Update-Tool
and Code-Review, and 8 on Branch-Protection; npm releases carry **SLSA
provenance v1** attestations; last commit and latest npm release both
that day; 22,171 stars and about 350,000 npm downloads a week.

Weaknesses, because a one-sided assessment is not an assessment:
Token-Permissions 0, Signed-Releases 0, Fuzzing 0, and Vulnerabilities
0, the last meaning known unfixed vulnerabilities were found, which for
a large Node project usually means transitive advisories. We have not
checked which. Its score on our own badge is 2.

**The threat model is smaller than it looks.** Renovate would have no
ability to change or deploy code. It proposes; a human reviews and
merges. That is the same power any stranger has, since anyone may fork
and open a pull request, and we already rely on review plus CI for that.
A bot doing it on a schedule is not a new category of trust, only a more
punctual contributor.

That holds only while its proposals get the same scrutiny as anyone
else's, so:

* Grant `contents: write` and `pull-requests: write`, nothing else.
* **Not** `workflows: write`. Scoped to `circleci` and `ruby-version` it
  has no business under `.github/workflows/`, and withholding it means
  it cannot alter our GitHub Actions.
* Keep branch protection on `staging` and `production`. Those are the
  branches the deploy job runs from, so protecting them is what makes
  "it cannot deploy" true rather than intended.
* **Do not use the default `GITHUB_TOKEN`.** GitHub does not start
  workflow runs for events raised by that token. Our `brakeman`,
  `codeql`, `codespell` and `main` workflows all trigger on
  `pull_request`, so a Renovate pull request opened with it would skip
  all four and be checked *less* than a stranger's. Use a dedicated
  GitHub App installation token or a fine-grained personal access token
  with the two permissions above. CircleCI is unaffected either way,
  since it triggers from its own integration.

## Proposing Ruby upgrades Heroku can build

Decided 2026-08-04, after finding that Renovate cannot be made safe for
this job.

**The problem.** Renovate's Ruby datasource is ruby-lang.org, which
announces a release the day it happens. Heroku builds its own binary
some unknown time later. So Renovate would open a pull request we cannot
merge, the deployability guard below would correctly turn it red, and it
would sit there. Red pull requests that are merely early are worse than
useless: they teach people to disregard red, and they turn the pull
request list into a to-do list of things to keep re-checking, which is
exactly the habit we are trying to retire.

**No list exists, and this is not an oversight.** Checked by reading
Heroku's own buildpack, 2026-08-04.
`lib/language_pack/helpers/download_presence.rb` and
`outdated_ruby_version.rb` discover what exists by **issuing `HEAD`
requests against S3 for versions they guess**. `OutdatedRubyVersion`
carries `DEFAULT_RANGE = 1..5`: from the current version it probes the
next five patch releases in parallel, and if the last of them exists it
enqueues a further range and keeps going. It probes upward across minor
lines the same way. That is how our staging deploy knew to suggest
3.4.10.

`DownloadPresence` declares
`STACKS = ["heroku-22", "heroku-24", "heroku-26"]` above the comment
that those three "have identical ruby versions supported", which is
useful: our stack upgrade will not narrow what Ruby we may run.

The devcenter reference page lists supported versions in prose, 3.3.12,
3.4.10 and 4.0.6 as of 2026-08-04, but not per stack and not
machine-readably. So probing is not a workaround for a missing API; it
is the only method available, and it is what the vendor does.

**The design: propose only what exists.** A scheduled job,
`propose_ruby_upgrade`, probes forward exactly as Heroku does, and opens
a pull request bumping `.ruby-version` to what it finds. It cannot
propose an undeployable version, so there is nothing to retry, and the
schedule *is* the retry: a Heroku lag means "no pull request this week,
a pull request next week", silently and with nothing red.

* **Probe every line above ours, not just our own patch line.** A move
  from 3.4 to 3.5, or to 4.0, is a decision we want *offered*. Offering
  it is not committing to it. The point of the pull request list is that
  choices arrive on their own and wait to be judged.
* **One pull request per line**, so accepting the routine patch bump
  does not require an opinion about the major upgrade sitting beside it.
* **Share the probe with the guard test below.** One piece of code that
  answers "does Heroku have this Ruby for this stack", two callers.
* A dead cron here leaves us stale, not wrong, and the guard rather
  than the cron is what keeps an undeployable pin out.
* **It opens pull requests, so the token analysis written for Renovate
  applies to it unchanged**: `contents: write` and
  `pull-requests: write`, never `workflows: write`, and **not** the
  default `GITHUB_TOKEN`, or its pull requests would start none of our
  `pull_request` workflows and be checked less than a stranger's.
* Being `lib/` code, it falls under the 100% coverage rule. Unit-test
  the probe with stubbed HTTP; see the guard below, which shares it.

## Guard: Ruby pins must stay deployable

Only Ruby versions Heroku offers for our stack will deploy, so a pull
request proposing a newer one, from `propose_ruby_upgrade` or from a
human editing the file by hand, could pass CI and fail at deploy. Guard
it in CI.

The check reads `.ruby-version`, issues one `HEAD` for the corresponding
tarball, and fails unless the answer is **200**.

**It must not be a Minitest test.** `test/test_helper.rb:58` calls
`WebMock.disable_net_connect!(allow_localhost: true, allow: driver_urls)`,
so the suite is hermetic on purpose and a real request to S3 would be
refused. Worse, that refusal is not a network error, so any
"skip when the network is unavailable" logic would read it as an offline
developer, skip silently, and go on skipping forever. A guard that never
guards is more dangerous than no guard, because it is also reassuring.

So make it a **rake task that CI runs**, one that needs no Rails and
therefore lives in `lib/tasks/standalone/`; see [Deploying without a
development environment](#deploying-without-a-development-environment).
There the skip is honest, because a real connection failure is a real
connection failure. Skip when offline so local work is unaffected; CI
has a network, and CI is where it matters.

* **Compare the exact version.** It answers precisely the question we
  care about, with no version arithmetic. Looser schemes, such as
  accepting any patch within our X.Y series, need the bucket listed
  rather than probed, which is not permitted, and answer a weaker
  question.
* **Read the stack name from the same constant the image build uses**,
  so a stack upgrade cannot change one and forget the other.
* **Assert "must be 200"**, never "must not be 404", for the S3 reason
  above.
* **The probe itself is ordinary `lib/` code** shared with
  `propose_ruby_upgrade`, so it falls under the 100% coverage rule.
  Unit-test it with stubbed HTTP covering 200, 403 and a connection
  failure. The rake task is the thin part that CI runs live.

A pull request bumping `.ruby-version` needs no other change: the
`build` job reads that file and downloads the matching interpreter, so
the tests genuinely run on the Ruby being proposed.

## Deploying without a development environment

Investigated 2026-08-04. `rake deploy_staging` and `rake deploy_production`
currently require a working development environment. Nothing they do
needs one; the requirement is an accident of how Rake starts.

### Every rake task boots the whole application

`Rakefile:7` reads:

```ruby
require File.expand_path('config/application', __dir__)
```

`config/application.rb` then does `require 'rails/all'` and
`Bundler.require(*Rails.groups)`, so **every** invocation of `rake`, for
any task, loads every gem in the `Gemfile` including the test-only ones.
Measured: `rake -T` takes **4.7 seconds**, and it cannot run at all
unless the full bundle is installed at the right Ruby. That, and not
anything about deploying, is why deploying needs a development
environment.

It is not that the tasks need the application. `deploy_production` is
pure git, with no Heroku credential of any kind:

```text
git checkout production && git pull &&
  git merge --ff-only origin/staging && git push && git checkout main
```

`deploy_staging` is the same fast-forward from `origin/main`, preceded
by `production_to_staging`, which is two `heroku` CLI calls.

### The fix: boot only when the requested task needs it

Rake sets `Rake.application.top_level_tasks` from the command line
*before* it loads the `Rakefile`, so the `Rakefile` can see what was
asked for and decide. Put the tasks that need no application in
`lib/tasks/standalone/`, load those first, and boot only if something
unrecognised was requested:

```ruby
Dir.glob(File.expand_path('lib/tasks/standalone/*.rake', __dir__))
   .sort.each { |f| load f }

wanted = Rake.application.top_level_tasks.map { |t| t.split('[').first }
unless wanted.all? { |t| Rake::Task.task_defined?(t) }
  require File.expand_path('config/application', __dir__)
  Rails.application.load_tasks
end
```

Verified as a working prototype 2026-08-04, including the cases that
matter: `rake deploy_production` skips the boot; `rake` with no
arguments, `rake -T` and any unknown task still boot, because Rake
substitutes `default` when no task is named, and `default` is not a
standalone task. `rake foo[bar]` is why the name is split on `[`.

**Use `lib/tasks/standalone/`, not `rakelib/`.** Rake auto-imports
`rakelib/*.rake`, but *after* the `Rakefile`, so the names are not
defined in time to test. Loading them explicitly as well defines every
task twice, and a task defined twice runs both bodies. The first
prototype did exactly that and deployed twice in one command.

The set of tasks that skip the boot is then expressed by which directory
a file sits in, with no list to maintain. Add a test asserting that no
standalone task shares a name with a task from the full set, so a
shadowed name cannot silently skip the application it needed.

### Move the database refresh into the deploy job

Decided 2026-08-05, and it does more than tidy up.

`production_to_staging` exists in the `Rakefile` only because that is
where someone happened to put it. It is work done *to* staging as part
of deploying to staging, and the job that deploys to staging already
holds the credential to do it. Move it there, gated on the branch:

```text
maintenance:on
  restore production's latest backup over staging   <- staging only
  git push heroku staging:master
  heroku run -- rails db:migrate
maintenance:off
```

**Restore before the code push, and migrate after.** Then the one
migration that runs is the new code's migrations against production's
schema, which is what staging is *for*. Today's order runs migrations
twice: once from `production_to_staging` against the code staging is
still running, which achieves nothing, and once from CircleCI after the
push, which is the one that matters.

What this removes, which is the point:

* **`HEROKU_API_KEY` never has to reach GitHub.** The staging button and
  the production button become the same operation, advancing a branch,
  and neither touches Heroku. The credential stays in the one place it
  already lives, held by the one job that already has it.
* **`production_to_staging` leaves the `Rakefile`.** `deploy_staging`
  and `deploy_production` are then the same five git commands differing
  only in the source branch, so they collapse into one parameterised
  task.
* **The deploy tasks stop needing the `heroku` CLI at all.** The local
  path needs only `git`, which is a stronger result than this section
  set out to get.
* **The fire-and-forget migration goes away**, because the surviving
  migration is CircleCI's existing blocking `heroku run`. That was the
  first of the four cautions below and it no longer applies.
* **The restore stops running against a live site.** Today it happens
  before anything enters maintenance mode. In the deploy job it lands
  after `maintenance:on`, which is strictly better.

Three consequences to accept deliberately, none of them objections:

1. **Every push to `staging` now refreshes the database**, not only the
   ones made through the task. That is what staging is for, but it does
   mean you can no longer test a migration against staging's accumulated
   state without doing the restore by hand.
2. **Re-running the staging deploy job becomes destructive.** Today
   re-running it is safe; afterwards it wipes staging and restores
   production. Reasonable for staging, but it changes what a familiar
   button does, so say so where people will read it.
3. **Verify that `pg:backups:restore` survives the running dyno.**
   Maintenance mode stops web traffic but the dyno keeps running, and
   solid_queue runs inside Puma, so connections stay open. Check whether
   the restore terminates them or fails; do not preemptively add a
   `ps:scale web=0` that may not be needed.

**Hardcode both application names in the restore step.** The
surrounding job derives `HEROKU_APP` from `$CIRCLE_BRANCH`, but the
restore's source and target are constants, production to staging. Write
them as constants, so that no branch name can ever redirect a restore,
and let the existing branch allowlist be the second lock rather than the
only one.

Checked, not assumed: `heroku pg:backups` runs with no plugins
installed on CLI 11.8.1, the version the `deploy` job pins, so the
`deploy-only` executor needs nothing added.

### Then the deploy can be a button

With the tasks free of Rails, and free of Heroku, a `workflow_dispatch`
GitHub Actions workflow with a `target` input can call exactly the same
code, so there is one implementation and two ways to run it, and the
local path still works when GitHub does not.

Both buttons now need **no Heroku credential at all**. What they need is
the right to push to the protected `staging` and `production` branches:
a GitHub App token listed as a bypass actor on exactly those two
branches, not a broadly privileged `GITHUB_TOKEN`. Authorisation is
GitHub Environments with required reviewers, one per target, which now
guard an action rather than a secret. That the push starts no
GitHub-side workflow does not matter here, because CircleCI triggers
from its own integration.

The remaining cautions, reduced from four to two by the move above:

1. **`--confirm staging-bestpractices` stops being a safety check** once
   it is a constant in a job rather than something a human types. The
   protection moves to the branch allowlist in the deploy job and to who
   may push to `staging`, which is enforced where the key actually is.
2. **The restore uses production's latest *existing* backup**, which is
   deliberate, so as not to disturb production, and means staging can
   come up with data up to a day old. The button should say so.

## Pinning Node for the production build

The fix for finding 5, in two halves. Checked 2026-08-04.

**The repository half, done.** A root `package.json` whose only
substantive content is `engines.node`, pinned to an exact **24.19.0**.
That is the newest release of the 24 line, which is the current LTS, and
it is the version the `deploy` job's `cimg/node` image already carries,
so the Node that minifies our JavaScript and the Node that runs the
Heroku CLI are now the same. Heroku publishes it: the buildpack's
`inventory/node.toml` at release `v361`, published 2026-08-03, lists
24.19.0 with a SHA-256 and fetches it from `nodejs.org`.

We pin the exact version rather than the `24.x` range Heroku's README
suggests. A range is the problem restated: the build changes and nobody
decided it should.

There is no `package-lock.json`, because there is nothing to lock. The
buildpack reads `package-lock.json` only to choose between `npm ci` and
`npm install`, and takes the latter without complaint.

**The application half, done 2026-08-05** on staging and then
production. `heroku/nodejs` must sit between the mimalloc buildpack and
`heroku/ruby`:

```text
heroku buildpacks:add --index 2 heroku/nodejs --app staging-bestpractices
```

Check before adding, since the command is easy to run twice:

```text
heroku buildpacks --app production-bestpractices
```

Without that buildpack the pin does nothing. `heroku/ruby` does not read
`engines.node`; it installs a Node of its own whenever it sees `execjs`
in `Gemfile.lock`, which it does.

**Order matters, and getting it wrong rejects a deploy.**
`heroku/nodejs` `bin/detect` *requires* `package.json` in the root, and a
classic buildpack whose detect fails fails the whole build. So the
`package.json` must reach the application first, and only then may the
buildpack be added. Deploy, add, deploy again, and read the second
build's log to confirm it reports 24.19.0.

**Consequence for the new test image.** `license_finder` activates its
NPM scanner on the presence of `package.json`, so it now shells out to
`npm`. It passes here, having nothing to find, but the new test image
must carry Node and npm or that check breaks. It should carry *this*
Node; see [The image](#the-image).

## The plan

1. **DONE 2026-08-05: pin Node for the production build** (finding 5).
   `package.json` pins the version, and `heroku/nodejs` sits ahead of
   `heroku/ruby` on both applications. See
   [Pinning Node](#pinning-node-for-the-production-build). The last
   confirmation is a production deploy log reporting 24.19.0.
2. **DONE 2026-08-05: checked `heroku/heroku:24-build`** for `libpq`,
   its headers and a C toolchain. All present; see [The image](#the-image).
3. **DONE 2026-08-05: run the `build` job on `heroku/heroku:24-build`
   directly**, installing Ruby and Node into `$HOME`. No image, no
   registry, no credential. See
   [Steps 3 to 5](#steps-3-to-5-and-why-they-turned-into-a-deletion).
4. **Delete `dockerfiles/3.4.1-browsers/`, `dockerfiles/3.3.6-browsers/`
   and `how-to-create-image.md`** once nothing references them. Leave
   the DockerHub image itself in place for a while: branches and open
   pull requests older than step 3 still pin it by digest, and deleting
   it breaks their pipelines for no gain.
5. **Retire the DockerHub image** once no live branch pins it.
6. **Add the Heroku-availability probe and the guard** that uses it, so
   step 7 cannot silently regress.
7. **Take Ruby to 3.4.10** (finding 3), which under this design is a
   one-line change to `.ruby-version` and nothing else.
8. **Add `propose_ruby_upgrade`**, sharing the probe from step 6, so
   nobody has to remember to look.
9. **Add Renovate**, self-hosted, scoped to `circleci` and permissioned
   as above.
10. **Then upgrade production to Heroku-26**, test environment first, so
    the stack move is exercised somewhere before it reaches production.

Independent of the above, and in no particular order with it:

11. **Move the staging database refresh into the CircleCI deploy job**,
    which takes Heroku out of the deploy tasks altogether.
12. **Break a migration on staging on purpose**, and confirm the
    release is blocked and CI goes red. Deliberately later: it should
    test the deploy job's *final* shape, so it belongs after step 11
    rather than before, and there is no sense proving a mechanism twice
    while it is still moving.

    The happy path is proven; release v845 went out through the release
    phase and maintenance mode cleared itself. What is unproven is the
    claim the whole design rests on: that a failed migration stops the
    release rather than shipping code against an unmigrated database.
    It is documented by Heroku and simulated here, and the guard has
    refused a real deploy for a real reason, but nobody has watched
    this particular failure happen.

    What to expect: the release reaches `failed`, the previous release
    keeps serving, the deploy job exits 1, and **maintenance mode stays
    on deliberately**, so clearing it is part of cleaning up. A migration
    that raises on purpose is enough; revert it once the behaviour is
    confirmed.
13. **Stop booting Rails for every rake task**, then make the deploys a
    `workflow_dispatch` button. See [Deploying without a development
    environment](#deploying-without-a-development-environment).

Prerequisite: [a pin must carry its own
tag](#prerequisite-a-pin-must-carry-its-own-tag) is done, ahead of
the rest, because Renovate proposes the wrong upgrades without it.

[Chrome: a second container](#chrome-a-second-container) is done,
ahead of step 3, against the old image as a known-good baseline.

Findings 1, 2 and 4 have no separate step: steps 2 to 5 remove their
cause.

## Facts worth not re-deriving

* Production stack: **Heroku-24** (Ubuntu 24.04); Heroku-26 available.
* Production Ruby: from `.ruby-version`, currently **3.4.1**; Heroku
  reports 3.4.10 available.
* Deploy is `git push heroku`, no `heroku.yml` or `app.json`, so Heroku
  builds the slug; our images never run in production.
* Migrations are not automatic on deploy: the CircleCI `deploy` job runs
  `heroku run -- bundle exec rails db:migrate`.
* `cimg/ruby` 3.4 is Ubuntu 22.04; 4.0 is 24.04.
* `heroku/heroku:24`, `:26`, `:24-build`, `:26-build` all exist and are
  rebuilt regularly.
* Heroku Ruby tarballs: `heroku-24/amd64/ruby-X.Y.Z.tgz`,
  `heroku-22/ruby-X.Y.Z.tgz`, under the S3 host named above.
* There is **no list** of the Ruby versions Heroku has, for anyone.
  Heroku's own buildpack probes with `HEAD` requests, guessing versions.
  heroku-22, heroku-24 and heroku-26 support the same set, per the
  comment on `DownloadPresence::STACKS`.
* Buildpacks on both applications, in order:
  `deadmanssnitch/buildpack-mimalloc`, then `heroku/ruby`. `heroku/ruby`
  installs a Node of its own because `execjs` is in `Gemfile.lock`.
* `Rakefile:7` requires `config/application`, so *every* rake task loads
  every gem. `rake -T` costs 4.7 seconds and needs the full bundle.
* `deploy_production` uses no Heroku credential; it is git only.
  `deploy_staging` also runs `production_to_staging`, which restores
  production's latest *existing* backup over staging. That restore is
  moving into the CircleCI deploy job, after which neither task touches
  Heroku.
* `heroku pg:backups` and `pg:backups:restore` are core CLI commands,
  needing no plugin install, on CLI 11.8.1.
* A CircleCI job's executor image must come from a registry. Its cache
  cannot supply one, because `restore_cache` is a step and steps run
  inside the executor that is already running.
* `test/test_helper.rb:58` calls `WebMock.disable_net_connect!`, so no
  Minitest test may reach the network. Live checks belong in rake tasks.
* There is no test image. The `build` job runs on Heroku's stack image
  and installs Ruby and Node into `$HOME` in about fourteen seconds.
* DockerHub pulls through CircleCI are not rate limited, by arrangement
  with Docker since 2020-11-01, per CircleCI's own documentation.
* CircleCI docs are rendered client-side, so plain `curl` returns
  navigation rather than content. Two things were therefore *not*
  verified and should be before use: how parameterized executors behave
  in this situation, and what Docker layer caching costs on our plan.
