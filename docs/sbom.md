# Getting a Software Bill of Materials (SBOM)

We generate an Software Bill of Materials (SBOM) in SPDX format.
If you want our SPDX SBOM, here is how to get that information.

## Production and staging SBOMs (per deployment)

Every push to the `production` or `staging` branch automatically generates
an SPDX JSON SBOM using [Syft](https://github.com/anchore/syft) and stores
it as a GitHub Release asset. The **production** SBOMs are the closest
equivalent to release SBOMs, since each production push represents a live
update to the running site.

Release tags use the form `sbom-BRANCH-YYYYMMDD-SHA8`, for example:
`sbom-production-20260402-a1b2c3d4`.

You can
[browse all production SBOM releases on GitHub](https://github.com/ossf/best-practices-badge/releases?q=sbom-production).

If you know the commit SHA, the `script/get-sbom` script looks it up,
displays its deployment date, and downloads the SBOM to your current
directory:

~~~~sh
script/get-sbom a1b2c3d4          # production (default)
script/get-sbom a1b2c3d4 staging  # staging
~~~~

You can pass the full 40-character SHA or any prefix of at least 8 hex digits.
The script is written in Ruby and only uses Ruby's standard library.

## Current main-branch SBOM (GitHub API)

You can also get a Software Bill of Materials (SBOM) in SPDX 2.3 format
of the *current* main branch with the following command:

~~~~sh
curl -L \
  -H "Accept: application/vnd.github+json" \
  -H "X-GitHub-Api-Version: 2026-03-10" \
  https://api.github.com/repos/ossf/best-practices-badge/dependency-graph/sbom
~~~~

You don't need to provide `-H "Authorization: Bearer <YOUR-TOKEN>"`
to this command because the analysis only needs public information.
The result is a "source SBOM" (it's derived entirely from the source code),
not a "build SBOM", for the current ("main") state of the repository.

See
[GitHub for more information](https://docs.github.com/en/rest/dependency-graph/sboms?apiVersion=2026-03-10#export-a-software-bill-of-materials-sbom-for-a-repository).

## Package managers and lock files

We use package managers, primarily bundler, to manage our packages,
and their input data is checked in to the repository.
For bundler we use the `Gemfile.lock` file to determine what to load.

If you want to know the exact SBOM for any specific version, look at
the package management inputs, especially their lock files.
Package manager inputs *are* SBOMs, but they're ecosystem-specific,
which is why it's helpful to have the SPDX format.
The SPDX format *isn't* ecosystem-specific, and thus simplifies sharing
of dependency information.

We don't "release" software intended for wide deployment.
Others are welcome to use the software, and we'll help when someone asks
questions.
However, we primarily focus on developing the software for the single
site we deploy to, so we don't have versioned releases as we would if
many systems were installing and running the software.
We *do* identify every production deployment by its commit ID, and
that's the closest analogy we have to a release.
