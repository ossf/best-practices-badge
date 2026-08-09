# Copyright 2026 the Linux Foundation and the
# OpenSSF Best Practices badge contributors
# SPDX-License-Identifier: MIT

# This image is intentionally NOT pinned to a sha256 digest, despite the
# OpenSSF Scorecard Pinned-Dependencies recommendation. Here is why pinning
# would be worse than leaving it unpinned:
#
# 1. OSS-Fuzz controls and regularly updates gcr.io/oss-fuzz-base/ images
#    with toolchain and security fixes. Their infrastructure expects projects
#    to track the latest tag; a stale pinned digest can silently break the
#    fuzz build when OSS-Fuzz updates its toolchain.
#
# 2. The supply-chain risk that pinning mitigates is low here: this registry
#    (gcr.io/oss-fuzz-base/) is operated by Google's OSS-Fuzz team, not an
#    arbitrary third party.
#
# 3. Scorecard offers no inline suppression syntax for Dockerfile FROM lines,
#    so we cannot suppress the finding without either pinning or removing the
#    check entirely. Accepting the finding is preferable to either alternative.
#
# If OSS-Fuzz ever supports a stable, versioned base image URI that we can
# pin without breakage risk, we should revisit this decision.
FROM gcr.io/oss-fuzz-base/base-builder-ruby

# commonmarker ships a pre-built x86_64-linux native gem (backed by Rust/comrak),
# so no Rust toolchain is required in this image.

RUN git clone --depth=1 \
    https://github.com/ossf/best-practices-badge.git \
    "$SRC/best-practices-badge"

COPY build.sh "$SRC/"
