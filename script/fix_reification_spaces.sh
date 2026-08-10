#!/usr/bin/env bash

# Copyright the Linux Foundation and the
# OpenSSF Best Practices badge contributors
# SPDX-License-Identifier: MIT

# Convert ASCII space inside Mermaid reification dots ((" ")) to hair space
# U+200A, keeping the dot visually compact. Portable to macOS and Linux
# (avoids sed -i whose -i option differs between BSD and GNU sed).
#
# Usage: script/fix_reification_spaces.sh [file ...]
# Default file: docs/sacm-mermaid.md

set -eu

HAIR=$'\xe2\x80\x8a'   # U+200A HAIR SPACE (UTF-8 bytes: e2 80 8a)

if [ $# -eq 0 ]; then
    set -- docs/sacm-mermaid.md
fi

for f in "$@"; do
    tmp=$(mktemp)
    sed "s/((\".\"))/((\"${HAIR}\"))/g" "$f" > "$tmp"
    if cmp -s "$f" "$tmp"; then
        # No change, remove result and don't change original timestamp
        rm -- "$tmp"
    else
        mv -- "$tmp" "$f"
    fi
done
