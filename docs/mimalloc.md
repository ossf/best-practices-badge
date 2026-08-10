# Mimalloc

This document analyzes and justifies how we use mimalloc
(Microsoft malloc) in production.

## The problem: Unbounded memory growth

Our production system had a serious problem with unbounded memory growth
once we started getting a massive number of requests.

## Solution: mimalloc

The jemalloc allocator is often recommended for Rails applications.
However, the jemalloc allocator has been archived on GitHub, and it appears
all jemalloc work has ceased. They mentioned mimalloc as an alternative.

So, I investigated mimalloc.
Tests show that mimalloc significantly reduces the memory growth
in operation. See [memory-growth](memory-growth.md).

A malloc replacement is highly sensitive, since it has direct access
to all memory. So I did some sanity checks to see if it might become
a problem.

I determined that the risk appeared to be quite low.

Fist, there's good reason to believe **mimalloc**
(as released as a system package) is fine.
This library is:

- Actively maintained on https://github.com/microsoft/mimalloc - there
  were many recent commits
- It's released by Microsoft, who will want it to be good and
  are highly unlikely to insert malicious code into it.
- Available on Debian and Ubuntu 24 as
  a standard system package as `libmimalloc2.0`.
  Its availability as a standard system package greatly reduces the
  likelihood of its being a malicious package even further.
  Note: On newer versions of Debian,
  [newer versions of mimalloc (3.0)](https://packages.debian.org/search?keywords=mimalloc)
  are also available.
- Designed for better performance and reduced fragmentation, especially
  for systems that use reference counting (like Lean, Python, and Ruby).
- Drop-in replacement via `LD_PRELOAD`

## Running mimalloc on Ubuntu

In development environments running Ubuntu, simply install mimalloc with:

~~~~sh
sudo apt install libmimalloc2.0
~~~~

To use mimalloc when running `some_command` (like `rails s`), use:

~~~~sh
LD_LIBRARY=/usr/lib/x86_64-linux-gnu/libmimalloc.so.2.1 some_command
~~~~

## mimalloc buildpack for Heroku

We deploy on Heroku. We *could* create our own container image and run it,
but currently we use the default container images (to try to reduce
maintenance burden). That image doesn't include mimalloc.
The standard Heroku solution is to add a "buildpack".

The [company Dead Man's Snitch](https://deadmanssnitch.com/)
has a GitHub repo for its
[mimalloc buildpack](https://github.com/deadmanssnitch/buildpack-mimalloc).
I reviewed
its [source code](https://github.com/deadmanssnitch/buildpack-mimalloc/tree/main/bin); it downloads and recompiles the library, which isn't
*necessary* strictly speaking but is a fine way to do it.

Its
[commit 29cd337 on Jun 16, 2025](https://github.com/deadmanssnitch/buildpack-mimalloc/commit/29cd337359c1b1296041b15940add8b8b442a741),
"Initial version of the buildpack for testing", makes it clear it's
based on their previous jemalloc work. It says:
"This is based on the jemalloc buildpack but modified to install mimalloc
instead. In the near term jemalloc should continue to work well but the
long term future is uncertain[1]. Given that is seems worthwhile to
consider other options and I've read good things about mimalloc and it
recently became an option for python."
Their jemalloc work was the typical recommendation for using jemalloc
on Heroku, so this is plausible.

The primary developer of the source code is
[Chris Gaffney (gaffneyc)](https://github.com/gaffneyc),
who has also contributed to `rails/propshaft`
and heroku-buildpack-jemalloc.
He has contributed to projects by Dead Man's Switch and Collective Idea.
He reports his location as Holland, MI.
I see no indication of concerns; this developer seems to be a capable
developer and there are no indications of malicious intent.

Collective Idea acquired Dead Man's Snitch in 2013 as confirmed both directions:
[Collective Idea's statement](https://collectiveidea.com/blog/archives/2013/07/30/collective-idea-acquires-dead-mans-snitch/) and
[Dead Man's Switch FAQ](https://deadmanssnitch.com/docs/faq)
("Dead Man's Snitch is a product of Collective Idea, a software
development & consulting company based in Holland, Michigan.").
When I looked at the [Collective Idea blog](https://collectiveidea.com/blog/),
I discovered I'd read some of their reports already!
They have a good reputation for being knowledgeable.

## Gemini analysis

I asked Google Gemini to also analyze the supply chain risk.

> To estimate the risk of a supply chain attack using the deadmanssnitch/buildpack-mimalloc Heroku buildpack, we need to look at three areas: the entity behind it, the technical implementation of the buildpack, and the verifiability of its binaries.
>
> 1. The Entity: Who is "Dead Man's Snitch"?
>
> Ownership History:
>
> Original Creator: Dead Man's Snitch was originally a product created by Collective Idea, a reputable software consultancy based in Holland, Michigan, USA. They have a long history in the Ruby on Rails and Heroku communities.
>
> Current Owner: In March 2023, Dead Man's Snitch was acquired by AppSignal, a monitoring company based in Amsterdam, Netherlands.
>
> Reputation: Both Collective Idea and AppSignal are well-established "known quantities" in the developer ecosystem. AppSignal, in particular, handles sensitive monitoring data for thousands of companies and is subject to EU privacy and security regulations (GDPR).
>
> Risk Factor: Low. This is not a "ghost" project managed by an anonymous individual. It is an open-source tool maintained by a legitimate, revenue-generating SaaS company with a physical presence and a reputation to maintain.
>
> 2. Technical Analysis: How the Buildpack Works
>
> A supply chain attack in a buildpack usually happens in the bin/compile script. I have analyzed the standard behavior of this specific repository:
>
> What it does: The buildpack installs mimalloc, a memory allocator developed by Microsoft that often performs better than the default malloc in containerized environments (like Heroku).
>
> The Binary Source: If you look at the bin/compile script in the repository, it identifies the Heroku "Stack" (e.g., cedar-24, heroku-22) and downloads a pre-compiled version of mimalloc.
>
> Download Location: It downloads the binaries directly from the GitHub Releases page of the same repository (https://github.com/deadmanssnitch/buildpack-mimalloc/releases).
>
> Risk Factor: Medium-Low. The risk here is that the GitHub account itself is compromised, or the CI/CD pipeline used to upload those releases is subverted. Because the binaries are hosted on GitHub, you are trusting the security of the AppSignal/Dead Man's Snitch GitHub organization.
>
> 3. The "Usual" Binary and Verification
> The "usual" binary is a shared object file (libmimalloc.so) compiled for the specific version of Ubuntu that the Heroku stack is based on (e.g., Heroku-22 is based on Ubuntu 22.04).
>
> How to verify it:
> This is the most difficult part of supply chain security. To verify that the binary in the releases matches the source code:
>
> Check for Checksums: Currently, this specific buildpack does not appear to hardcode SHA-256 checksums in the bin/compile script. This is a weakness. A common security best practice is for the script to verify the hash of the download before installing it.
>
> Manual Comparison:
>
> Clone the official Microsoft mimalloc repository.
>
> Fire up a Docker container running the same image as your Heroku stack (e.g., heroku/heroku:22).
>
> Compile mimalloc manually inside that container.
>
> Download the binary from the Dead Man's Snitch GitHub release.
>
> Compare the two files. Note: They likely won't have identical hashes due to compilation timestamps (non-deterministic builds), but you can use tools like diffoscope to see if the actual logic differs.

The statement from Gemini is misleading though the thrust is correct.
The [compile script](https://github.com/deadmanssnitch/buildpack-mimalloc/blob/main/bin/compile) downloads *source* code from the mimalloc project,
and then *compiles* it running the scripts in the buildpack-mimalloc repo.
It doesn't just download compiled versions.
However, it's true that *users* of the *resulting* buildpack download source
code and scripts, run them, and install the resulting executable library.
There *are* arguments for doing things this way: if there's an update,
then the next time the buildpack is built, we get the update.

The organizations here are reputable, and the people involved
appear knowledgeable and reputable.
This seems like a relatively low risk.

## mimalloc buildpack installation and configuration

To set this up Heroku you simply add a buildpack.
Per their README:

~~~~
heroku buildpacks:add --index 1 https://github.com/gaffneyc/buildpack-mimalloc.git
~~~~

After that, you push it (e.g., `git push heroku master`).

The recommended configuration simply runs all commands
with mimalloc (which makes things simple) by running:

~~~~sh
heroku config:set MIMALLOC_ENABLED=true
~~~~
