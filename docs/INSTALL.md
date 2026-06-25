# Installation and quick start instructions

<!-- SPDX-License-Identifier: (MIT OR CC-BY-3.0+) -->

Here is how to install the "BadgeApp" web application, for either a development
environment or for deployment.
On most systems this is a fairly quick and painless process.
We also provide information on how to quickly get started so you
can *do* something.

We provide a simple script that does the work, and we emphasize using
widely-used tools designed for the purpose.
Our installation approach installs a specific version of Ruby and specific
versions of the Ruby gems that BadgeApp uses (including the ones in Rails).
The web application is implemented with Ruby on Rails.
In development we store data in SQLite;
the production system stores the data in Postgres.

## Development environment prerequisites

You need a working Internet connection to download everything to install.

You need a Unix-like system.
This includes a general-purpose Linux distribution
(e.g., Ubuntu, Fedora, Debian, Red Hat Enterprise Linux, or SuSE) or MacOS.
If you're using Windows, install virtual machine software (such as VirtualBox)
and install Linux on a virtual machine.
We do not expect Windows to work directly.

Make sure your system has up-to-date packages.
For example, on Ubuntu and Debian, run this:

~~~~
sudo apt-get update && sudo apt-get upgrade
~~~~

If you use a virtual machine for development, maximize its memory.
It will run in less memory, and in particular the production version uses less.
However, we enable many monitoring tools during development and they consume a
lot of memory.

Some organizations use an SSL/TLS interception proxy, which intercepts all
SSL/TLS traffic.
If you must work with those, and you are willing to completely trust that proxy,
then you need to download and install that proxy's certificates.
E.G., to install them on Ubuntu, when your current directory has the
certificates as .crt files, run this:

~~~~sh
# ONLY do this if you have an SSL/TLS interception proxy and are using Ubuntu
sudo bash
ca=/usr/share/ca-certificates
tip=tls-interception-proxy
mkdir -p $ca/$tip
cp *.crt $ca/$tip
cd $ca
ls $tip/* >> /etc/ca-certificates.conf
update-ca-certificates
exit # End "sudo bash"
~~~~

If you're using MacOS, you need to install Homebrew
(it provides the package manager command <tt>brew</tt>).
See <http://brew.sh/> for installation instructions. As reported by
<tt>brew doctor</tt>, you should also do the following
(if it isn't already there) so that updated programs from brew take precedence:

~~~~sh
echo "export PATH=/usr/local/bin:$PATH" >> ~/.bash_profile  # MacOS brew
~~~~

You also need a version of git installed.
If you don't already have it set up, install it using your system installation
tools, e.g., at the command line:

* <kbd>sudo apt-get install git</kbd> (Debian, Ubuntu)
* <kbd>yum install git</kbd> (Red Hat Enterprise Linux, CentOS, older Fedora)
* <kbd>dnf install git</kbd> (newer Fedora)
* <kbd>emerge install git</kbd> (Gentoo)
* <kbd>brew install git</kbd> (MacOS)

Also, install Chrome.
It's not needed to *run* the software, but it's used for various headless tests
so you need it to run some automated tests.
The easy way to do this is to download it from
<https://www.google.com/chrome>.
Chromedriver is now managed by selenium.

## Forking the repo

You'll now need to fork the repo on GitHub.
[GitHub's instructions on forking a repo](https://help.github.com/articles/fork-a-repo/)
describe this in general.

In our case, use your web browser to view
<https://github.com/ossf/best-practices-badge>,
log in to your account (or create one), and click on the "Fork" button on the
top right.  On In the right sidebar of your new fork's repository page,
click on the "to clipboard" symbol to copy the clone URL for your fork.

Now go back to your system, type <tt>git clone</tt>, a space, paste the clone
URL for your fork, and press <kbd>Enter</kbd> to download the fork.
Once it's done, change into the newly-created directory:

~~~~sh
cd best-practices-badge
~~~~

## Installing the development environment

We provide a simple shell script that should install all the necessary
tools and libraries.
So at the command line just run:

~~~~sh
./install-badge-dev-env
~~~~

This will automatically create a database and seed it with dummy data
(by running "rake db:setup"). This will set up the test and development
databases with "seeded" data per `db/seeds.rb`.

If that fails, see the section later on "What does install-badge-dev-env do?"
to manually do what it's trying to do.
If it doesn't work, patches welcome.

## Telling git who you are

The installation will ask you for your full name and email address
if git does not already have them set.
This is used to
[set up Git](https://help.github.com/articles/set-up-git/)
so it will correctly record who you are.
Please use your own name and email address.

You can change these later using:

~~~~sh
git config --global user.name "YOUR NAME"
git config --global user.email "YOUR EMAIL ADDRESS"
~~~~

## Starting the server locally

Once your development environment is ready, you can run the application with:

~~~~
rails s
~~~~

This will automatically set up what it needs to, and then run the
web application.  You can press control-C at any time to stop it.

## Accessing the local server

Now start up your local web browser and have it open "http://localhost:3000".
On Linux-like systems, you can do this by running this on a command line:

~~~~
xdg-open http://localhost:3000
~~~~

Within the web browser you can click on "sign in" to create a new account,
and "log in" later after you've created an account.
You can also create your own projects.

## Giving yourself admin privileges

If you're maintaining it locally, you might want to give your account
admin privileges.  First, note the user id of your account
(it's the number after "/users/" in the URL when you display your own profile).
You can do this by running this (replacing YOUR_USER_ID with the number):

~~~~
rails db
UPDATE users SET role = 'admin' where id = YOUR_USER_ID ;
~~~~

Press control-D to exit "rails db".

## Exploring

Users normally interact with the web interface.
In some cases you may find it helpful to
interact directly with the software and examine its state.
There are several easy ways: rails db (SQL), rails console, and "byebug".

For more about how the program is structured, and other hints, see the
[implementation](implementation.md) information.

### Rails db

Use "rails db" to interact directly with the database. E.G.:

~~~~
rails db
SELECT id,name FROM users WHERE id < 5;
SELECT id,name FROM projects WHERE id < 5;
~~~~

The file "db/schema.rb" describes the database schema.

### Rails console

The "rails console" can be a convenient way to access state;
it starts a Ruby environment with Rails loaded.

Here is a sample:

~~~~
rails console

p = Project.new
# Set values for project to evaluate.  We'll examine our own project.
p[:repo_url] = 'https://github.com/ossf/best-practices-badge'
p[:homepage_url] = 'https://github.com/ossf/best-practices-badge'
# Setup chief to analyze things:
new_chief = Chief.new(p, proc { Octokit::Client.new })
# Ask chief to find probable values:
results = new_chief.autofill
results.keys
results[:name]
~~~~

### byebug

You can insert "byebug" anywhere in the code.
When that runs, the program stops and provides an interactive
command environment which lets you execute commands
(such as showing you various states).

## Contributing in general

See [CONTRIBUTING.md](../CONTRIBUTING.md) for information on how to contribute
changes.

## Deployment instructions

This is designed to be easily deployed simply by doing a `git push`
to an appropriate destination.

We currently run a `rake deploy_staging` command that does a `git push`
to deploy to a staging site, and later `rake deploy_production` to push
to the production site.

## See also

See the separate "[background](./background.md)" and "[criteria](./criteria.md)"
pages for more information.

## What does install-badge-dev-env do?

The install-badge-dev-env script tries to install all (missing) tools and
libraries.  You can re-run it again if something got corrupted.

### Installing system tools

First, it tries to automatically detect your system package management tool
(e.g., apt-get, yum, dnf, or brew),
and then tries to install some key tools if they're not already there:

* git, to get some of the programs we use.
  Installing git will also install some libraries such as
  curl, zlib, openssl, expat, and libiconv.
* Ruby (version 1.9.3 or newer), to bootstrap installing the Ruby we'll use
* SQLite3 database system, used in development for data storage
* C compiler and basic libraries for rebuilding ruby.
  Install a sane C compiler such as gcc or clang.

See the [ruby-build suggested build environment](https://github.com/sstephenson/ruby-build/wiki#suggested-build-environment)
for how to do install the other required components.
The script installs gcc.

It then normally installs [rbenv](https://github.com/sstephenson/rbenv).
See the
[rbenv basic github checkout](https://github.com/sstephenson/rbenv#basic-github-checkout)
instructions for one approach for installing rbenv.
The rbenv tool lets you select a specific version of Ruby, and from there,
select specific versions of other libraries.
An alternative way to select specific versions is to use rvm,
but that approach is not documented here.

It also adds an "upstream" remote so that you can easily track it:

~~~~sh
git remote add upstream https://github.com/ossf/best-practices-badge.git
~~~~

<!-- If you have edit rights, do this instead:
git clone <https://github.com/ossf/best-practices-badge.git>
cd best-practices-badge
-->

### Installing the project environment

For development we fix the version of Ruby at the version specified in `.ruby-version`. Please check that file and use that version in the steps below.
We also need to install a number of gems (including the ones in Rails);
we will install the versions specified in Gemfile.lock.
We will do completely separate per-project Gem installs,
to prevent potential interference issues in the development environment.
Here's a way to do that.
We presume that your current directory is the top directory of the project,
aka best-practices-badge.

~~~~
# Force install Ruby 2.3.1 using rbenv:
rbenv install 2.3.1
rbenv local 2.3.1 # In this directory AND BELOW, use Ruby 2.3.1 instead.

# This makes "bundle ..." use rbenv's version of Ruby:
git clone git://github.com/carsomyr/rbenv-bundler.git ~/.rbenv/plugins/bundler

gem sources --add https://rubygems.org  # Ensure you're getting gems here
gem install bundler  # Install the "bundler" gem package manager.
rbenv rehash
bundle install       # Install gems we use in Gemfile.lock, including Rails
rake db:setup        # Setup database and seed it with dummy data
~~~~

### git integrity

Per a recommendation about git integrity by Eric Myhre, we force
git to check the integrity of incoming data using:

~~~~
git config --global transfer.fsckobjects true
git config --global fetch.fsckobjects true
~~~~

### Consequences of our developmental install approach with rbenv

Some documents about Rails will tell you to execute `bundle exec COMMAND`
or perhaps `bin/COMMAND` instead of "COMMAND" for commands like
`rake` or `rails`. These approaches ensure you use the project-specific
set of gems (a "virtual environment").

While "bundle exec..." or perhaps "bin/..." are widely used, they are also
extremely error-prone user interfaces; if you forget to include the prefixes,
then it can *appear* to work yet subtly do the wrong thing.

Using rbenv-bundler (as we do above) eliminates the need for that.
Using rbev-bundler means that the *easy* way is the *correct* way.
A vitally important way to prevent defects is to make the *easy* way
the *correct* way.

Here's how it works: `bundle` supports setting up the correct environment
with `bundle exec`. Of course, typing `bundle exec` in front of every command
is a pain, so the `bin/` directory makes it a *little* easier.
Rails' `rails app:update:bin` and `bundle binstub NAME`
were used to create stubs in `bin/` so that if you
run *those*, they'll run `bundle exec` so the right gems will be used.
The `rbenv-bundler` program then creates global stubs that will invoke the
correct `bin/` program *without* needing to type the prefix at all
(similar to how `rbenv` runs the "correct" ruby without needing to type in
a prefix at all, through special stubs).

There's no free lunch. If you want to add a new command from a gem, you must
run `bundle binstubs GEMNAME` and then `rbenv rehash`. That's a rare
event, so the trade-off seems worth it. Do *NOT* use `bundle binstubs --all`,
that will overwrite the binstubs of rails and friends.

You can use "bundle outdated" to show the gems that are outdated;
be sure to test after updating any gems.

## Testing the installer script

It may be useful to occasionally test that our installer script is working
as expected.  We have a branch set up on GitHub which is configured to do just
that, test-dev-install.  In order to test the install script, you must have
write privileges to the GitHub git repository.  If you do, you can trigger a
test by running

~~~~
    rake test_dev_install
~~~~

This command will merge the current master branch into our test branch while
conserving our custom circle.yml for testing our install script and then push
these changes to GitHub. This will trigger a CircleCI build which will test
the install script.

## Uninstalling the Badge app's development environment

In order to completely remove the Badge app, perform the following steps:

1.  Remove the database entries Badge app.  This can be done by running
    "rake db:drop && RAILS_ENV=test rake db:drop"

2.  Remove the best-practices-badge directory. (WARNING: This will remove
    any and all local branches that have not been pushed to your remote git
    repository.

3.  (Optional) If you do not use rbenv for any other applications and would
    like to remove it, you can co so by first removing the directory:
    `$HOME/.rbenv`.   Finally remove the any lines matching "rbenv" from any
    shell startup files.

You can find lines matching "rbenv" in shell startup files
with the following shell command:

~~~~sh
    grep rbenv ~/.bashrc ~/.bash_profile ~/.zshrc /etc/profile /etc/profile.d/*
~~~~

## Optional: Setting up OpenSSF Scorecard

We work with
[OpenSSF ScoreCard](https://github.com/ossf/scorecard),
so you may want to install to scorecard to analyze this code
for the best practices website.
An easy way to install scorecard on Ubuntu is:

~~~~sh
    # Set up go environment
    echo 'PATH="$PATH:$(go env GOPATH)/bin"' >> "$HOME/.profile"
    source "$HOME/.profile"

    # Install scorecard
    sudo snap install --classic go
    go install github.com/ossf/scorecard/v2@latest
    sudo apt-get install jq # Useful tool

    # Optional: Install node/npm
    snap install --classic npm

    # Run scorecard, showing details
    export GITHUB_TOKEN='...'
    scorecard --repo=github.com/ossf/best-practices-badge \
      --show-details --format=json | jq -C | less -R
~~~~

See [OpenSSF ScoreCard](https://github.com/ossf/scorecard) for more
information.

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
