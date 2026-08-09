# How to Create a New CircleCI Docker Image

This guide explains how to create and deploy a new Docker image for
CircleCI when upgrading Ruby or other dependencies.

## Prerequisites

You need:

- Docker installed locally
  ([install instructions](https://docs.docker.com/engine/install/))
- A DockerHub account with push access to the repository
- Access to update `.circleci/config.yml` in this repository

## Step 1: Get the Base Image SHA256

Pull the CircleCI base image and note its SHA256 hash.
For example, to use Ruby 3.4.1 with browsers:

```bash
docker pull cimg/ruby:3.4.1-browsers
```

The output will show:

```text
Digest: sha256:a0b57bca5e631081ac79c5b316a480f282da03e71b164e0ad40426766e0ebac7
```

Copy the SHA256 hash from the "Digest:" line.

## Step 2: Create the Dockerfile

Create a new directory named after the Ruby version
(e.g., `dockerfiles/3.4.1-browsers/`).
Create a `Dockerfile` in that directory:

```dockerfile
# pin :3.4.1-browsers
FROM cimg/ruby@sha256:a0b57bca5e631081ac79c5b316a480f282da03e71b164e0ad40426766e0ebac7
# We need "cmake" to build the C code required by some gems.
# We need "shared-mime-info" for gem mimemagic.
RUN sudo apt-get update && sudo apt-get install -y cmake shared-mime-info

# Install Bundler compatible with the Ruby version
# Adjust the constraint as needed (e.g., '~> 2.7.0' for Ruby 3.4+)
RUN gem install bundler -v '~> 2.7.0' --no-document

USER circleci
```

Replace the SHA256 hash with the one from step 1.
The Bundler version should be compatible with your Ruby version.

Why we do this:

- Pinning the base image SHA256 prevents malicious updates
  (required by OpenSSF Scorecard)
- Installing dependencies in the image makes CI builds faster
- Installing Bundler ensures compatibility with the Ruby version

## Step 3: Build the Image

```bash
cd dockerfiles/3.4.1-browsers
docker build -t drdavidawheeler/cii-bestpractices:3.4.1-browsers .
```

Replace `3.4.1-browsers` with your version tag. This takes a few minutes.

## Step 4: Test the Image

Before pushing, verify the image works:

```bash
docker run -it drdavidawheeler/cii-bestpractices:3.4.1-browsers /bin/bash
```

Inside the container:

```bash
ruby --version    # Verify Ruby version
bundler --version # Verify Bundler version
gem --version     # Verify RubyGems version
exit
```

Note: You may see an X11 warning (`XSERVTransmkdir: ERROR`) when the
container starts. This is harmless - the `-browsers` image includes Chrome
for testing, which checks for a display. The container works fine despite
this warning.

## Step 5: Push to DockerHub

```bash
docker login -u drdavidawheeler
docker push drdavidawheeler/cii-bestpractices:3.4.1-browsers
```

The output will show:

```text
3.4.1-browsers: digest: sha256:97770a22ec2c88bf9fa028cc136446129f33e15df62bb4c0dc65f2c25d22ffe7
```

Copy this SHA256 hash - you'll need it for the CircleCI configuration.

## Step 6: Update CircleCI Configuration

Edit `.circleci/config.yml`. The file uses reusable executors
to define images once.

Find the `executors:` section near the top and update the SHA256 hashes:

```yaml
executors:
  ruby-postgres:
    docker:
      - image: drdavidawheeler/cii-bestpractices:3.4.1-browsers@sha256:YOUR_SHA256_FROM_STEP_5
        environment: ...

  ruby-only:
    docker:
      - image: drdavidawheeler/cii-bestpractices:3.4.1-browsers@sha256:YOUR_SHA256_FROM_STEP_5
        environment: ...
```

Replace `YOUR_SHA256_FROM_STEP_5` with the digest hash from step 5.
Update the comment to match your version.

If you updated Ruby's major or minor version, also update the cache version.
Search for `v8-dep-` and replace with `v9-dep-` (appears in 2 places).
This forces a cache rebuild to prevent issues with gems cached using
the old Ruby/Bundler.

## Step 7: Commit and Test

```bash
git add dockerfiles/3.4.1-browsers/Dockerfile .circleci/config.yml
git commit -s -m "Update CircleCI image to Ruby 3.4.1"
git push
```

Monitor the CircleCI build to ensure it passes with the new image.

## Notes

- The Dockerfile pins dependencies by SHA256 hash to prevent supply chain
  attacks, as required by OpenSSF Scorecard.
- The CircleCI configuration includes a step that updates Bundler to match
  `Gemfile.lock`, ensuring version consistency even if the Docker image ages.
- When updating Ruby, also update your local `.ruby-version` file and run
  `bundle install` to update `Gemfile.lock`.
- The `-browsers` image variant includes Chrome and X11 libraries needed for
  system tests. Use this unless you're certain you don't need browser testing.
