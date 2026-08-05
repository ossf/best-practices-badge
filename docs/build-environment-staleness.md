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

**Decided, not yet built:** steps 4 to 10, 12, 13 and 15 to 19 of
[The plan](#the-plan).

**Build speed** was taken up 2026-08-05, once the step running the
checks and tests had become most of the build. The time is now measured
rather than guessed, and the order of the remaining work is decided.
The 36-workers-for-two-processors claim from the Chrome work turned out
to be **false**, and correcting it cost a red build; both the
correction and how it was arrived at are recorded. See
[Where the build's time goes](#where-the-builds-time-goes).

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

**So Java was never the problem here.** CircleCI's warning about
`/proc`-reading runtimes is real in general, but the JVM has been
container-aware for years and got this right.

**CORRECTED 2026-08-05: so has Rails, and this section originally said
otherwise.** It claimed that because `test/test_helper.rb` says
`parallelize(workers: :number_of_processors, with: :processes)`, and
because `:number_of_processors` meant `Etc.nprocessors`, CI was forking
36 test workers for an allowance of 2, eighteen times oversubscribed.

That was wrong, and wrong in the way this document keeps warning
about: by reasoning from a plausible mechanism instead of looking.
`ActiveSupport::TestCase.parallelize` in Rails 8.1 resolves
`:number_of_processors` with
`Concurrent.available_processor_count`, **which reads the cgroup
quota**, not the affinity mask. CI has been running 2 workers all
along, which the build log said in plain words the whole time:

```text
Running 1232 tests in parallel using 2 processes
Running 23 tests in a single process (parallelization threshold is 50)
```

The 36 was real, and `nproc` really does report it; it simply was never
the number Rails used. See
[Where the build's time goes](#where-the-builds-time-goes) for what
happened when the correction was tested by setting the count by hand.

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

## Maintenance mode only when it is earned

Done 2026-08-05, after reading a production deploy log and asking why
the site was dark while Heroku compiled assets.

Measured, from production job 9665:

| Step | Time |
| ---- | ---- |
| set up access, `maintenance:on` | 13.2s (10 of it the deliberate production sleep) |
| **push, which blocks through the slug build** | **115.1s** |
| wait for release, `maintenance:off` | 1.1s |

So about 129 seconds of downtime, of which **115 is Heroku building the
slug**: bundle install, `assets:precompile`, the lot. Throughout it the
old release is serving normally and nothing touches the database. That
part of the window protects nobody from anything.

**It cannot be narrowed by phase.** Migrations run in the release
phase, which Heroku starts itself at the end of the build, and there is
no hook between "build finished" and "release command runs". Maintenance
is on for the whole push or not at all.

**So the choice moves from per phase to per deploy.** The job asks the
Platform API which commit is live, reading `description` from the
release list, and compares:

```text
git diff --name-only <live-sha> HEAD -- db/migrate/ db/schema.rb
```

Nothing changed means this deploy migrates nothing, so it takes no
maintenance window at all. Most deploys are that kind; the production
deploy that prompted this had no migration and would have had zero
downtime.

**The answer is written first, then the checks look for reasons to
keep it.** The step's first statement is:

```sh
echo 'yes' > /tmp/needs-maintenance
```

Each check that finds a reason prints it and stops. Only when every one
has had its say, and none objected, does the file become `no`. So a
crash, a timeout, a kill, an unreadable API or a step that never ran all
leave the deploy taking the window.

That ordering is the whole safety argument, and the first version got it
wrong: it wrote the answer at each exit point, so anything that stopped
the step part-way left *no* answer at all. A needless maintenance window
costs a slower deploy; a missing one costs users a half-migrated
database, so the two are not equally bad and the default must not be
decided by where the code happens to stop.

Reasons that keep the window: `staging` always, because the restore
replaces its whole database; the API call failing; no `Deploy` release
in the list; an unparsable description; the live commit missing from a
shallow clone; and any change under `db/migrate/` or `db/schema.rb`.

`db/schema.rb` is checked as well as `db/migrate/`, which is belt and
braces: only a migration can migrate. It errs toward downtime, which is
the safe way to be wrong.

**The `off` is gated too.** Turning maintenance off unconditionally
would clear a window somebody had raised by hand, and report success
for having done so.

Tested by extracting the step from `.circleci/config.yml` and running it
under the deploy job's shell with `curl` stubbed, against real commits
from this repository rather than invented ones. Eleven checks: staging,
a deploy with no migration, a deploy with one, no `Deploy` release in
the list, an empty list, a live commit absent from the clone, and an
API failure; that the log names the live commit and lists the migration
files it found; and, for the ordering above, **that killing the step
part-way through still leaves `yes`**.

### What this does not fix

The 115 seconds is still spent, just not in the dark, and a deploy that
*does* migrate still takes the full window. Removing that needs the slug
to exist before the deploy starts, which is Heroku pipeline promotion:
production would run the artifact staging already built and ran, rather
than rebuilding from source and trusting the build to be deterministic.

Two of the three feasibility questions are answered:

* **Nothing environment-specific is baked into the slug.**
  `config.action_controller.asset_host` reads `ENV['PUBLIC_HOSTNAME']`
  at boot, not at compile time, and the one ERB-compiled asset,
  `app/assets/javascripts/criteria.js.erb`, reads no `ENV` at all.
* **`RAILS_ENV` on staging is `production`**, so staging compiles the
  assets production wants.
* **No Heroku pipeline exists yet**; `heroku pipelines` lists none. So
  promotion needs one created and both applications added.

It would also need a check that staging's current release is the same
commit as the `production` branch's HEAD, since promotion deploys
whatever slug staging holds rather than what the branch says.

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

Decided and **done** 2026-08-05, and it does more than tidy up.

The refresh is its own step in the deploy job, between entering
maintenance mode and pushing, so the deploy job now reads:

```text
set up access, maintenance:on
refresh staging's database      <- staging only
push, capture the release baseline
wait for the release, maintenance:off
```

`rake deploy_staging` is now the same five git commands as
`deploy_production`, needing no Heroku credential and no interactive
login. `production_to_staging` survives for refreshing staging out of
band, and its migration is now blocking: it was detached only because
CI migrated again straight afterwards, and a migration whose outcome
nobody reports is not worth running.

### No signed URL, because there is nothing to leak

Raised 2026-08-05, and it was a real exposure rather than a theoretical
one: **this project's CircleCI logs can be read by anyone**, and
`pg:backups:url` returns a *signed, publicly fetchable* link to
production's dump. Whoever held it could download the production
database until the signature expired. The emails inside are encrypted;
nothing else is.

The first fix redacted the URL from the log. The better one, taken
instead, is Heroku's documented cross-application restore, which takes
an **identifier** so no secret is ever created:

```text
heroku pg:backups:restore production-bestpractices::a3822 \
  DATABASE_URL --app staging-bestpractices --confirm staging-bestpractices
```

The redaction stays anyway, because the CLI may resolve that identifier
to a URL internally and print it. It keeps the host and path, useful
when debugging, and drops the query string, where the signature lives.

**Finding the identifier needed the real output, not a guess.** Two
assumptions would have been wrong:

* Identifiers are not all `b123`. Scheduled backups are lettered `a`
  and manual ones `b`, so the newest was `a3822`, and a pattern of
  `^b[0-9]+$` would have matched nothing.
* The newest backup is not necessarily usable. One still running, or
  one that failed, appears at the top of the list and would have been
  chosen. The parse insists on `Completed`.

### The parse has to be forgiving, and one thing it was not

`heroku pg:backups` has no `--json`, so this is a table parse. Asked how
tolerant it is of formatting, and checking properly turned up a real
defect rather than a style point.

**The command prints three sections, not one.** Backups, then Restores,
then Copies. Copy rows look exactly like backup rows: `c3221` matches
the same identifier shape and carries the same `Completed` status. The
first version simply took the first match in the whole output, which
happened to be right only because Backups is printed first. **An empty
or all-running Backups section would have fallen through and handed a
*copy* identifier to a restore.** Wrong, silently, and precisely the
failure that made a table parse worth worrying about.

The parse now tracks which section it is in and considers nothing
outside Backups.

**Heroku's own documentation disagrees with Heroku's own output.** The
published example shows backups with status `Finished`; the CLI we run
prints `Completed`, which is the word the example reserves for restores.
Both are accepted.

On formatting specifically, it is tolerant by construction. awk's
default field splitting treats any run of spaces or tabs as one
separator, so column widths do not matter, and the status is matched as
a whole word anywhere on the line rather than by column number, so a
change to the "Created at" format cannot shift it out from under us.

Tested against the real listing and seven synthetic ones:

| Listing | Result |
| ------- | ------ |
| the real one, three sections | `a3822` |
| Backups empty, Copies present | **refuses**, does not take `c3221` |
| only a Restores section | refuses |
| documentation style, `Finished`, single spaces | `b011` |
| tab separated | `a899`, skipping a Running row |
| a Running backup on top | skips it, `a3822` |
| a Failed backup on top | skips it, `a3822` |
| an API error instead of a table | refuses, exit 1 |

What it still cannot survive is Heroku renaming the sections or the
status words again. It fails closed when that happens, which is the
most that can be promised of a parse with no machine-readable
alternative.

**Four independent exact-match checks guard the restore**, because it
overwrites a database:

1. The workflow filter admits only the branch names `staging` and
   `production`. CircleCI treats a plain string as a branch name; a
   regular expression would have to be written between slashes and
   match the entire string.
2. The job re-checks that with a `case` allowlist.
3. The step itself tests `CIRCLE_BRANCH` for equality with `staging`.
4. Both application names are literals; nothing is derived from the
   branch, so no branch name can redirect the restore or choose its
   source. The step also refuses if the target is not
   `staging-bestpractices`, which is the check that would matter if
   someone later replaced those literals with variables.

Underneath all four: reaching any of it needs the right to push to this
repository's `staging` branch, which is what branch protection is for.

Tested against the real step code. Only the exact string `staging`
triggers a restore; `staging2`, `my-staging`, `staging/foo`, `Staging`,
`STAGING`, `staging-bestpractices`, leading or trailing spaces, and the
glob patterns `sta*` and `*` all do not.

**A bug caught by that testing, worth recording.** The first attempt
put the restore in the same step as the push, so its early exit on
non-staging branches skipped `git push` entirely: production would have
deployed nothing. Splitting them into separate steps fixed it, and the
test that catches it is simply asserting that `production` still
pushes.

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
3. **`pg:backups:restore` survives the running dyno. Confirmed
   2026-08-05**, on the first real staging deploy through this step.
   The worry was reasonable: maintenance mode stops web traffic but the
   dyno keeps running, and solid_queue runs inside Puma, so connections
   stay open. It restored anyway, reporting `Restoring... done` and
   exiting zero, and the deploy went on to a successful release. So no
   `ps:scale web=0` is needed, which is why it was worth not adding one
   preemptively.

**Hardcode both application names in the restore step.** The
surrounding job derives `HEROKU_APP` from `$CIRCLE_BRANCH`, but the
restore's source and target are constants, production to staging. Write
them as constants, so that no branch name can ever redirect a restore,
and let the existing branch allowlist be the second lock rather than the
only one.

Checked, not assumed: `heroku pg:backups` runs with no plugins
installed on CLI 11.8.1, the version the `deploy` job pins, so the
`deploy-only` executor needs nothing added.

### Newest completed is not the same as recent

Added 2026-08-05, prompted by reading the first real deploy's log. It
said `Using backup a3822` and finished, and nothing in it could tell
you whether that backup was four hours old or four weeks old.

That gap matters because of a choice made deliberately above: we
restore production's latest *existing* backup rather than capturing a
fresh one, so as not to put load on production. If production's
scheduled backups ever stopped, this step would keep succeeding while
restoring older and older data. Nothing would report it. The restore
genuinely succeeds; staging merely looks out of date, which is
indistinguishable from any of the ordinary reasons staging looks out of
date.

So the step now reports the age:

```text
Using backup a3822, created 2026-08-05 09:00:11 +0000 (0 days old)
```

and past two days says so plainly:

```text
WARNING: that backup is 9 days old.
WARNING: check that production still backs up daily:
WARNING:   heroku pg:backups:schedules --app production-bestpractices
```

**It warns rather than refusing**, which is a judgement and not an
oversight. A stale copy of production is still a better staging
database than whatever is on staging already, and the middle of a
deploy is a bad moment to be blocked by a backup problem that is not
this deploy's fault. Two days rather than one, so that ordinary drift
in when the schedule runs is not reported as a fault.

**"Created at" must be read by column, and that is the weak part.** The
status is matched as a whole word anywhere on the line precisely so a
layout change cannot shift it out from under us. A date gets no such
protection, being a date wherever it sits. So its shape is validated
instead, and a row that does not match says what it could not do rather
than printing whatever happened to sit in those fields:

```text
Using backup a3822; could not read its date
  row: a3822 Completed 2026-08-05 09:04:33 +0000  ...
```

The restore then proceeds. A diagnostic that cannot be produced is not
a reason to refuse a deploy.

### The shell you may write here is not the shell you know

Found the hard way 2026-08-05: this change was first written with
bash's here-string, `read backup_id c_date c_time c_zone` fed from the
row, which is tidier than calling `awk` twice. CircleCI rejected the
entire configuration:

```text
Error calling workflow: 'build-deploy'
Error calling job: 'deploy'
Expressions must be less than 2048 characters.
```

**A here-string opens with a doubled less-than sign, and that pair is
how CircleCI opens its own parameter expressions.** It read the pair as
the start of an expression, scanned forward for the closing doubled
greater-than that never came, and gave up after 2048 characters.
Here-documents open the same way and are the same trap.

Three things make this worth recording rather than merely fixing.

* **The error points nowhere near the cause.** It is reported against
  the first line of the step, which was a comment, so the message
  invites you to shorten a long command. Length was never the problem:
  four other commands in the file are longer than 2048 characters and
  always have been, including one of 7585.
* **Comments are not exempt.** The first fix carried a comment
  explaining the trap, spelling the pair out literally, which would
  have reintroduced it. A comment inside a `command:` block is part of
  the string CircleCI parses, not an aside to a human.
* **Nothing local caught it.** `rake yaml_syntax_check` passes, because
  the file is valid YAML; the fault is in CircleCI's own expression
  layer, above YAML. The `circleci` CLI would catch it with
  `circleci config validate`, and is not installed here.

So `rake circleci_config_check` now catches it, in `rake default`
beside the YAML check. It is a grep rather than a second tool to
install and keep current, which for one character pair is the right
size of answer.

**It permits a genuine expression.** `<< parameters.foo >>` and
`<< pipeline.number >>` pass, so the parameterized executor this
document considered and set aside remains available; everything else
fails with the file, the line number, and the line.

Tested by breaking what it guards, which is the only way to know a
guard works:

| Case | Result |
| ---- | ------ |
| the here-string that caused this, restored | caught, exit 1 |
| a here-document, in a comment | caught, exit 1 |
| `<< parameters.image >>`, `<< pipeline.number >>` | passes |

Note the second row. The trap is not "do not use here-strings"; it is
that **CircleCI parses the whole command string**, comments included,
and does not know the shell would have ignored part of it.

### Testing the shipped code, not a copy of it

The eight listings the parse was first tested against were run against
a *copy* of the step's shell. This change was tested differently: a
harness extracts the step's `command` from `.circleci/config.yml` with
Psych and runs **that** under `/bin/bash -eo pipefail`, which is the
shell the deploy job actually gets, with `heroku` stubbed to print a
fixture and to record the arguments it is handed.

The distinction has earned its keep twice already in this document.
The remote browser passed while driving local Chrome, and the release
parse passed against fixtures whose shape had been assumed rather than
observed. Both times the tests were exercising something that was not
the shipped code.

33 checks pass: the original eight listings, behaving exactly as
before; that the restore still receives
`production-bestpractices::a3822` and `--app staging-bestpractices`;
that nine branch names including `staging2`, `Staging`,
`staging-bestpractices` and `"staging "` with a trailing space still
restore nothing; and the new reporting, including the two negative
checks that matter, that a fresh listing emits no warning and that an
unreadable date invents no age. `shellcheck` on the extracted step is
clean, which is the only static analysis this shell can get while it
lives inside YAML.

Fixture timestamps are computed relative to the clock rather than
written down, since the step reads the real clock and a hardcoded date
would quietly change meaning every day.

**The harness is not committed**, because there is nowhere for it to
live yet: `test/` is hermetic Minitest, and this needs a real
`.circleci/config.yml` and a stubbed CLI. Recorded here so that the
next person knows the method rather than rediscovering it. Putting it
in `script/`, and eventually in `rake default`, is the obvious next
step and is not taken here.

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

## Where the build's time goes

Asked 2026-08-05 for easy wins, on the grounds that the step named "Run
comprehensive checks and tests (rake default)" now dominates the build.
Everything below was measured that day on a four-core development
machine, net of the 5.9 seconds every `rake` invocation spends booting
Rails, since that boot is paid once by `rake default` and would
otherwise be counted twelve times.

| Check | Net cost | Kind |
| ----- | -------- | ---- |
| `license_okay` + `license_finder_report.html` | **42.6s** | code-determined |
| `html_from_markdown` | **~21s** | code-determined |
| `report_code_statistics` | 9.6s | code-determined |
| `percent_gems_up_to_date` | 8.5s | **time-varying** |
| `rubocop` | 6.8s | code-determined |
| `markdownlint` | 4.9s | code-determined |
| `bundle_audit` | 3.3s | **time-varying** |
| `whitespace_check` | 2.4s | code-determined |
| `eslint` | 2.0s | code-determined |
| `yaml_syntax_check` | 1.3s | code-determined |
| `rails_best_practices` | 1.1s | code-determined |
| `ruby_syntax` | 0.3s | code-determined |
| **the checks together** | **~105s** | |
| `rails test`, 1232 tests | 50.7s on four cores | |
| `rails test:system`, 22 tests, serial | ~104s, measured in CI | |

On CircleCI's two processors the checks plausibly cost 180 to 210
seconds, which is roughly 40% of the step. That scaling is an estimate;
the local figures are not. **Replace it with real per-step timings
before claiming a saving.**

### Code-determined and time-varying, which is the useful distinction

Ten of those twelve checks give the same answer for the same commit for
ever. Running them again on `staging` re-establishes what `main`
already established, because `staging` is fast-forwarded from `main`
and branch protection is what makes that true rather than merely
customary.

Two are not like that. `bundle_audit` reads an advisory database and
`percent_gems_up_to_date` reads rubygems.org, and both move underneath
an unchanged commit. A gem set that was clean when it merged can be
vulnerable by the time it deploys, and that is exactly the moment we
would want to know.

So the question for each check is not how long it takes but which kind
it is. Code-determined checks belong wherever the commit is first seen;
time-varying checks belong on every build, deploys included.

### The tests, and a wrong premise that cost a red build

The Chrome work recorded that CI forked 36 test workers for an
allowance of 2, and left the right number as a measurement for later.
That measurement was taken, on two processors (`taskset -c 0,1`),
varying only `PARALLEL_WORKERS`:

| Workers | Wall time |
| ------- | --------- |
| 2 | 85.5s |
| **4** | **74.8s** |
| 8 | 89.0s |

All three runs: 1232 tests, 12609 assertions, 0 failures. Read on its
own the table says the optimum is near **twice** the allowance, because
the suite spends much of its time waiting on PostgreSQL rather than
computing.

`PARALLEL_WORKERS: 4` therefore went into the `build` job. **It turned
CI red, and the premise underneath it was false.** Both halves are
worth keeping.

**Rails was never asking for 36.** `parallelize` in Rails 8.1 resolves
`:number_of_processors` with `Concurrent.available_processor_count`,
which reads the **cgroup quota**, not the affinity mask. So CI had been
running 2 workers all along, and the build log had been saying so in
plain words:

```text
Running 1232 tests in parallel using 2 processes
```

Nobody read that line, on either side of the argument. It was there in
every build for months. `nproc` really does report 36 in that
container, and `Etc.nprocessors` really does follow the mask; those
facts were right, and simply were not the ones that governed.

### Setting PARALLEL_WORKERS also switches the threshold off

The build failed with 67 files of untested code, and every test
passing:

```text
1232 tests, 12609 assertions, 0 failures, 0 errors, 0 skips
Intermediate Coverage (Regular Tests): 99.76%
23 tests, 199 assertions, 0 failures, 0 errors, 0 skips
Combined Coverage: 57.51%
```

Coverage was **complete after the unit tests and gone after the system
tests**, which is the shape of a merge problem, not a testing problem.

The cause is one line of Rails,
`ActiveSupport::Testing::ParallelizeExecutor`:

```ruby
def should_parallelize?
  (ENV["PARALLEL_WORKERS"] || tests_count > threshold) && many_workers?
end
```

**Setting the variable does not set the worker count. It also
suppresses the threshold**, and the threshold is the entire reason our
23 system tests run serially. The two runs say it outright:

| Run | Unit tests | System tests |
| --- | ---------- | ------------ |
| `main` | parallel, 2 processes | **single process (threshold is 50)** |
| with `PARALLEL_WORKERS=4` | parallel, 4 processes | **parallel, 4 processes** |

Parallel system tests then destroy the coverage, because SimpleCov
names results after the worker. The system-test workers take the same
names as the unit-test workers, `job-manual (subprocess: N)-W`, and
overwrite them. Read out of a local resultset after such a run:

```text
job-manual (subprocess: 1)-0   covered_lines=2121
job-manual (subprocess: 2)-1   covered_lines=416
job-manual (subprocess: 3)-2   covered_lines=416
job-manual (subprocess: 4)-3   covered_lines=416
job-manual                     covered_lines=249
```

Those 416-line entries had held the unit tests' coverage. Nothing warns:
the merged report lists five command names, exactly as a healthy run
does, and the count of covered lines is the only thing that changed.

**And the system tests should never have been parallel anyway.**
`Capybara.server_port` is fixed at 31337, which is why they are serial.
Run locally with the variable set, they fail: 1 failure and 2 errors,
against 0 on the same commit without it. CI got away with it, probably
because the single Selenium session serialises the browser work, so the
only symptom there was the coverage collapse.

**So the change is reverted**, and `.circleci/config.yml` sets no
worker count. Rails already picks the quota-aware number.

**What survives is the measurement, and it is still worth having.** On
two processors, 4 workers beat 2 by about 13%. Claiming that saving
needs a mechanism that does not switch the threshold off, which means
passing the number to `parallelize(workers:)` in
`test/test_helper.rb` rather than setting the environment variable.
That is a change to how every developer's tests run, so it wants its
own measurement rather than a doubling rule inferred from one
two-processor experiment: 4 cores may not want 8 workers, and 36 cores
certainly do not want 72 databases.

### Three traps worth not stepping in again

* **Do not count workers from the coverage line.** "Coverage report
  generated for job-manual (subprocess: 1)-0, ..." lists every command
  name in the merged resultset, which accumulates across runs, so it
  reported eight workers for a three-worker run. Clear `coverage/`
  first, which is what `test:clear` does inside `test:optimized`.
* **Each worker gets its own database**, `test_0` upward, created on a
  fresh PostgreSQL container every build. The worker count is a
  database-creation cost as well as a CPU one.
* **A green intermediate coverage number does not survive the run.**
  `test:optimized` prints coverage after the unit tests and again after
  the system tests. The gap between those two numbers is where a
  merge fault shows, and it is the first thing to look at when
  well-tested code is reported as untested.

### The alternatives, and what each is worth

| Option | Change | Saves | Effort |
| ------ | ------ | ----- | ------ |
| A | Split `build` into parallel `static` and `test` jobs | wall clock becomes the larger of the two | medium |
| B | Move code-determined checks to GitHub Actions | same, on pull requests | medium |
| C | Skip code-determined checks on `staging` and `production` | ~200s, deploy builds only | small |
| D | Stop scanning licences twice | ~21s, every build | small |
| E | Drop `html_from_markdown` | ~21s | **rejected** |
| F | Parallelize the system tests | up to ~half of 104s | medium |
| G | `resource_class: large` | perhaps 40% of the test half | trivial, costs credits |
| H | `parallelism: N` with timing-based splitting | most of all | large |

**E is rejected, and the reasoning was wrong rather than marginal.** It
was proposed as waste, on the grounds that the generated HTML is
gitignored and discarded when the container exits. But generating it is
the point: converting all 81 files is how markdown problems are
detected, and the output being thrown away does not make the conversion
pointless. It stays, and it belongs in the static job.

**A over B, for now.** They achieve nearly the same thing, and B has
one real attraction, that GitHub Actions minutes are free for public
repositories while CircleCI credits are not. Against that, B puts a
second Ruby toolchain on a second platform, which then drifts from
production, which is the failure this whole document exists to end.
Keeping Ruby in one place wins today. See
[Rebuilding this on GitHub](#rebuilding-this-on-github-later) for what
would make B attractive later.

**F and G are held back deliberately** until the cheap changes have
been measured in CI. Both spend money, and neither should be bought on
an estimate when a real number is a build away.

### The order, and why it is this order

1. ~~`PARALLEL_WORKERS: 4`~~ **Tried and reverted**, because the
   premise was false and the mechanism was worse than the premise. See
   [the threshold](#setting-parallel_workers-also-switches-the-threshold-off).
   Rails already picks the quota-aware number; any future tuning goes
   through `parallelize(workers:)`, not the environment.
2. **DONE: D, stop scanning licences twice.** See
   [One scan, not two](#one-scan-not-two).
3. **DONE: C, the branch conditional.** See
   [What the deploy branches skip](#what-the-deploy-branches-skip).
4. **DONE: A, split the job**, which extends C's benefit to pull
   requests. See [Two jobs, not
   one](#two-jobs-not-one-which-deletes-the-conditional).
5. **Measure again**, and only then consider F, G and H.

Steps 1 to 3 are plausibly 250 to 300 seconds off a deploy build
without spending another credit. Steps 2 and 3 are wanted soon
specifically because a faster build makes every other change in this
document cheaper to test.

### One scan, not two

Done 2026-08-05. `rake default` used to run `license_finder` twice over
the same gems: `license_okay` to decide whether the licences are
acceptable, and `license_finder_report.html` to render the same
information as a browsable page. Between 21 and 38 seconds each,
depending on how the npm scanner feels.

**One command cannot do both**, which was checked rather than assumed.
`action_items` is the gating command and it does accept `--format
html`, which looks like the answer. On success it emits **205 bytes**
saying everything is approved, against the report's 340 KB. It reports
the action items, and when there are none there is nothing to report.

So the report leaves `rake default` and stays a task:
`rake license_finder_report.html`. The **check still runs everywhere**;
what stopped running on every build is the second scan of the same
gems for a copy of an answer we already had.

The CircleCI `store_artifacts` entry for it went too. Worth knowing for
anything similar: **`store_artifacts` does not fail on a path that does
not exist.** Confirmed from a real build, where all seven upload steps
reported success and only six artifact paths existed; `tmp/capybara`
and `/tmp/circleci-artifacts` were both empty and neither complained.

### What the deploy branches skip

Done 2026-08-05, implementing the code-determined and time-varying
distinction rather than merely describing it.

`lib/tasks/default.rake` names the short list, and `rake default`
splices it in, so the two cannot drift. The `build` job chose between
them by exact branch name, any other branch getting everything, so that
the failure mode was a branch checked too much rather than too little.
Tested against ten branch names, including `Staging`, `staging2`,
`my-staging`, `staging-bestpractices`, `production2` and the empty
string.

**That conditional is now gone**, and the task it selected has been
renamed; see [Two jobs, not
one](#two-jobs-not-one-which-deletes-the-conditional). The policy it
implemented survives, expressed somewhere better.

**The tests always run.** That is the point of the split rather than an
exception to it: a green suite is not a property of the commit alone,
it is how flapping is noticed, and it is the last thing standing
between a deploy and production.

Verified by running the whole of `rake default` end to end, 469
seconds on a four-core machine, with every check passing and the test
counts unchanged: 1232 tests and 12609 assertions, then 23 system
tests, still `Running 23 tests in a single process (parallelization
threshold is 50)`.

One false alarm worth recording, because the next person will hit it.
Running `CI=true bundle exec rake` locally fails one system test:

```text
Minitest::Assertion: CI must set SELENIUM_REMOTE_URL
```

That is the guard from the Chrome work working exactly as intended: it
refuses to let CI silently drive a local browser. Locally, either
leave `CI` unset or point `SELENIUM_REMOTE_URL` at a container.

### Two jobs, not one, which deletes the conditional

Done 2026-08-05, and it is option A from the table above. The checks
settled by the commit now run in their own CircleCI job, `static`,
beside `build` rather than in front of it. Neither requires the other,
so CircleCI starts both at once and the wall clock is the longer of the
two instead of their sum.

**Measured in CI**, which is the number that counts, comparing the
first pipeline on the split against `main` immediately before it:

| Pipeline | Job | Time |
| -------- | --- | ---- |
| `main`, everything in one job | `build` | 262.1s |
| split | `build` | 204.9s |
| split | `static` | 90.4s |
| | **wall clock** | **204.9s** |

**57 seconds off the wall clock, about 22%.** And an honest second
number beside it: 204.9 + 90.4 is 295.3, so the *total* compute went
**up** by about 33 seconds. That is the second job paying its own
checkout, Ruby install and bundle, and it is the trade being made
deliberately. Wall clock is what a person waits for; the extra 33
seconds is machine time that was always going to be spent on something.

On a four-core development machine, where the two run in sequence:
`rake static_checks` 50s, `rake dynamic_checks` 199s, `rake default`
249s.

**Three task lists, built from three constants**, so `rake default`
cannot come to mean something different from what CI runs:

```ruby
task(:default).clear.enhance(
  %w[notice whitespace_check] + %w[static_checks dynamic_checks]
)
task(:static_checks).clear.enhance(PREFLIGHT + STATIC_CHECKS)
task(:dynamic_checks).clear.enhance(PREFLIGHT + DYNAMIC_CHECKS)
```

A developer still types `rake` and gets everything, in the order that
fails fastest. `deploy_checks` is renamed `dynamic_checks`, because it
now runs on every branch and a name that says "deploy" would have been
actively misleading. Its partner is `static_checks`, and the pair is
the standard distinction: static analysis against dynamic analysis,
which is what a test suite is.

**The branch conditional is deleted, not moved.** The `build` job runs
`rake dynamic_checks` on every branch, with nothing to decide. What
keeps the checks off the deploy branches is now a workflow filter:

```yaml
- static:
    filters:
      branches:
        ignore: [staging, production]
```

That is better than a `case` inside a step for a reason worth stating.
A filtered-out job is **visible as absent** in the pipeline, where a
step that decided to do nothing is visible only to somebody reading the
log. `ignore` rather than `only`, so a new branch is checked more
rather than less.

`deploy` requires `build` and deliberately not `static`: on those two
branches `static` does not exist, and a job cannot require one the
workflow filtered away.

**Its own executor, `ruby-only`.** Reusing `ruby-postgres` would start
a PostgreSQL container and a 2.12 GB Chrome container for a job that
speaks to neither. That the static checks need no database was checked
rather than assumed: all ten pass with `PGHOST` pointed at a dead port.
The `config/database.yml` copy is kept anyway, because Rails wants the
file to exist at boot and one `cp` is cheaper than establishing whether
it does.

**The setup is shared, not copied.** The eight steps both jobs need,
cache identity through `bundle install`, moved into a `prepare_ruby`
command. Two copies would drift, and the drift would appear as one job
passing and the other failing on the same commit. Verified after the
extraction that all eight steps are byte-identical to what `build` ran
before, and that `build` lost nothing but the old rake step.

They share the cache too, since the keys come from that same command.
Only `build` writes it, so the two never race to save one key.

**One consequence to act on outside this repository:** `static` is a
new status check, `ci/circleci: static`. Branch protection will not
require it until somebody adds it, and a check that is not required is
a check that can go red without stopping a merge.

### Rebuilding this on GitHub, later

The eventual aim is B: the code-determined checks run on GitHub
Actions, in parallel with the tests on CircleCI, triggered by
`pull_request` and pushes to `main`, so that they cannot run on
`staging` or `production` by construction rather than by a conditional.

The way to build it is the way the CircleCI executor was built, and
that is the whole reason to record this now rather than improvise it
later: run on Heroku's own stack image, install the Ruby that
`.ruby-version` names and the Node that `package.json` names, and cache
`~/ruby`. Done that way it is not a second environment to maintain; it
is the same environment expressed twice, and any drift between them is
a bug with an obvious fix. Done any other way, with `setup-ruby` and
whatever Ubuntu the runner happens to be, it reintroduces exactly the
divergence findings 2 and 4 were about.

`.github/workflows/main.yml` currently runs `echo Hello, world!`, so
the slot is already there.

### Recording how current the gems are

`percent_gems_up_to_date` must keep running on every build, deploys
included, because that is a number worth having at the moment of a
deploy. It is time-varying by definition.

Today it only `puts` a line into the build log, which is the weakest
useful form of recording: it cannot be diffed, plotted, or compared
across builds, and CircleCI logs age out. It should write a small JSON
file, with the timestamp, branch, commit and the counts, into
`$CIRCLE_ARTIFACTS`.

**An honest caveat, since it decides the design.** CircleCI artifacts
expire too, after 30 days by default. If "consult it later" means
months, artifacts are not enough, and the answer has to be somewhere
that keeps history: a scheduled job appending to a file in the
repository, or a metrics store. Not decided here, because how far back
one wants to look is the question that settles it.

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

11. **DONE 2026-08-05: move the staging database refresh into the
    CircleCI deploy job**, which takes Heroku out of deploying
    altogether. `rake deploy_staging` is now pure git.
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

Making the build faster, in the order decided under
[Where the build's time goes](#where-the-builds-time-goes):

14. **ABANDONED 2026-08-05: `PARALLEL_WORKERS: 4`.** Tried, turned CI
    red, reverted. Rails already reads the cgroup quota, so the 36
    workers this was meant to fix never existed; and the variable
    switches off the parallelization threshold, which is what keeps the
    system tests serial. Tuning the worker count is still worth about
    13% on two processors, but it has to go through
    `parallelize(workers:)` in `test/test_helper.rb`, and it needs its
    own measurement on more than one machine shape.
15. **DONE 2026-08-05: stopped scanning licences twice.** The report
    left `rake default` and stayed a task; the check still runs
    everywhere. `action_items --format html` cannot replace it: on
    success it emits 205 bytes, not the report. See
    [One scan, not two](#one-scan-not-two).
16. **DONE 2026-08-05: code-determined checks skipped on `staging` and
    `production`.** First as a branch conditional in the `build` job,
    then, in step 17, as a workflow filter that leaves the whole job
    out. See
    [What the deploy branches skip](#what-the-deploy-branches-skip).
17. **DONE 2026-08-05: split into parallel `static` and `build` jobs.**
    The checks settled by the commit run beside the tests rather than
    in front of them, on their own executor with no PostgreSQL and no
    Chrome. The branch conditional from step 16 is deleted in favour of
    a workflow filter. See [Two jobs, not
    one](#two-jobs-not-one-which-deletes-the-conditional).

    Outside this repository: add `ci/circleci: static` to the required
    status checks, or it can go red without stopping a merge.
18. **Measure in CI, then decide** about parallel system tests, a larger
    resource class, and splitting the suite across containers. None of
    those should be bought on an estimate.
19. **Record the gem-currency number as data**, not as a line in a log
    that expires. See [Recording how current the
    gems are](#recording-how-current-the-gems-are); how far back one
    wants to look is the open question.
20. **DONE 2026-08-05: maintenance mode only when a deploy migrates.**
    Most deploys change nothing under `db/migrate`, and those now take
    no downtime at all. See [Maintenance mode only when it is
    earned](#maintenance-mode-only-when-it-is-earned). Still wanted:
    Heroku pipeline promotion, so that a deploy which *does* migrate
    waits seconds rather than two minutes, and production runs the
    artifact staging already ran rather than rebuilding it.

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
* `pg:backups:restore` completes with the dyno still running under
  maintenance mode; no `ps:scale web=0` is needed. Confirmed on staging
  2026-08-05.
* A deploy's maintenance window is ~129s, of which ~115s is Heroku
  building the slug, during which the old release serves and the
  database is untouched. There is **no hook between build and release
  phase**, so the window cannot be narrowed by phase, only skipped per
  deploy.
* Heroku release objects carry `description` like `Deploy 09446ffe`,
  which is how to learn what commit is live. Config-var changes also
  create releases, so ask for several and take the newest `Deploy` one.
* Nothing environment-specific is compiled into our slug: `asset_host`
  comes from `ENV['PUBLIC_HOSTNAME']` at boot, and no asset reads
  `ENV` at compile time. `RAILS_ENV` on staging is `production`. Both
  facts matter only for pipeline promotion, which has no pipeline yet.
* **A doubled less-than sign anywhere in `.circleci/config.yml` breaks
  the whole file**, comments inside a `command:` included, because
  CircleCI reads that pair as the start of a parameter expression. So
  no bash here-strings and no here-documents. The error names an
  expression length limit and points at the top of the step, which is
  not where the character is.
* CircleCI's 2048-character limit applies to *expressions*, not to
  commands. Several commands in that file exceed it, the longest at
  7585 characters, and always have.
* A CircleCI job's executor image must come from a registry. Its cache
  cannot supply one, because `restore_cache` is a step and steps run
  inside the executor that is already running.
* `test/test_helper.rb:58` calls `WebMock.disable_net_connect!`, so no
  Minitest test may reach the network. Live checks belong in rake tasks.
* Rails parallel testing gives **each worker its own database**
  (`test_0`, `test_1`, ...), created on a fresh PostgreSQL container
  every build. The worker count is therefore a database-creation cost
  as well as a CPU one.
* **Rails is container-aware and we are not.** `parallelize(workers:
  :number_of_processors)` uses `Concurrent.available_processor_count`,
  which reads the cgroup quota. `nproc` and `Etc.nprocessors` read the
  affinity mask and report the host's 36. CI runs 2 workers and always
  did; the build log says which, in words, every run.
* **Never set `ENV["PARALLEL_WORKERS"]` here.** It does not merely set
  the count: `should_parallelize?` is
  `(ENV["PARALLEL_WORKERS"] || tests_count > threshold) && many_workers?`,
  so setting it also suppresses the threshold that keeps our 23 system
  tests serial. Parallel system tests then collide on
  `Capybara.server_port` 31337 and overwrite each other's SimpleCov
  results. Tune with `parallelize(workers:)` instead.
* On two processors the test suite is fastest at **about twice** that
  many workers, not at exactly that many, because much of it waits on
  PostgreSQL. Measured: 85.5s at 2, 74.8s at 4, 89.0s at 8.
* `rake default`'s checks cost about 105 seconds on four cores, of
  which `license_finder` was 42.6 (now halved: the report left the
  default chain) and `html_from_markdown` is 21. A whole `rake default`
  including both test suites is 469 seconds there.
* **`store_artifacts` does not fail on a missing path.** Confirmed from
  a real build: seven upload steps all succeeded with six artifact
  paths present. So a check that sometimes produces no artifact needs
  no conditional around the upload.
* `license_finder action_items --format html` gates correctly but emits
  205 bytes on success, not a report, so one invocation cannot both
  gate and produce the browsable page.
* Ten of those checks are settled by the commit; only `bundle_audit`
  and `percent_gems_up_to_date` can change answer without the code
  changing. `rake static_checks` and `rake dynamic_checks` are those
  two halves, and `rake default` is defined as both, so it cannot come
  to mean something different from what CI runs.
* **None of the static checks needs a database.** All ten pass with
  `PGHOST` pointed at a dead port, which is what lets them run on an
  executor with no PostgreSQL and no browser.
* A CircleCI `commands:` block is how two jobs share steps. Job-level
  YAML anchors are not a supported substitute; a command is.
* There is no test image. The `build` job runs on Heroku's stack image
  and installs Ruby and Node into `$HOME` in about fourteen seconds.
* DockerHub pulls through CircleCI are not rate limited, by arrangement
  with Docker since 2020-11-01, per CircleCI's own documentation.
* CircleCI docs are rendered client-side, so plain `curl` returns
  navigation rather than content. Two things were therefore *not*
  verified and should be before use: how parameterized executors behave
  in this situation, and what Docker layer caching costs on our plan.
