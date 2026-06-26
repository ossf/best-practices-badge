#!/usr/bin/env bash

# Copyright the Linux Foundation and the
# OpenSSF Best Practices badge contributors
# SPDX-License-Identifier: MIT

# Verify CDN (Fastly) caching of anonymous "project show" pages, per
# docs/cdn-cache-not-logged-in.md Section 8. Runs items 1-4 of the staging
# verification plan:
#
#   1. An anonymous request is cacheable and served from cache (HIT), and
#      sets no _BadgeApp_session cookie.
#   2. A request carrying _BadgeApp_session bypasses the cache (never HIT),
#      even when a cached anonymous object exists.
#   3. A request carrying the remember-me cookie bypasses the cache likewise.
#   4. JSON still caches regardless of cookies (no regression).
#
# Items 2 and 3 exercise the Fastly bypass rule (Change 3), which lives in
# the Fastly config, NOT in this repo. If that rule is not yet deployed to
# the target, those checks will fail -- that is a real signal, not a bug in
# this script. Note: until cacheable HTML actually ships, items 2 and 3 pass
# trivially (nothing is cached, so nothing can be a HIT); they only become
# meaningful once item 1 passes.
#
# This is also suitable as a periodic synthetic monitor (Section 9.4): a
# session-cookie or remember-me request returning HIT is a security
# regression in the bypass rule.
#
# Usage: script/verify_cdn_caching.sh [-v|--verbose] [BASE_URL] [PROJECT_ID]
#   -v, --verbose  Print the full response header block for every request
#                  (useful for inspecting the existing JSON/badge VCL while
#                  hunting for the rule to copy, and confirming the CDN
#                  strips Surrogate-Control before the browser).
#   BASE_URL       default: https://staging.bestpractices.dev
#   PROJECT_ID     default: 1
#
# Exit status is 0 only if every check passes.

set -u

usage() {
  cat <<'EOF'
Usage: script/verify_cdn_caching.sh [-v|--verbose] [BASE_URL] [PROJECT_ID]
  -v, --verbose  Print the full response header block for every request.
  BASE_URL       default: https://staging.bestpractices.dev
  PROJECT_ID     default: 1
EOF
}

VERBOSE=''
positional=()
for arg in "$@"; do
  case "$arg" in
    -v|--verbose) VERBOSE=1 ;;
    -h|--help) usage; exit 0 ;;
    -*) printf 'Unknown option: %s\n' "$arg" >&2; usage >&2; exit 2 ;;
    *) positional+=("$arg") ;;
  esac
done

BASE="${positional[0]:-https://staging.bestpractices.dev}"
PROJECT_ID="${positional[1]:-1}"
BASE="${BASE%/}" # strip any trailing slash

SHOW_URL="$BASE/en/projects/$PROJECT_ID/passing"
JSON_URL="$BASE/projects/$PROJECT_ID.json"

# Colorize only when stdout is a terminal.
if [ -t 1 ]; then
  RED=$(printf '\033[31m'); GREEN=$(printf '\033[32m')
  YELLOW=$(printf '\033[33m'); CYAN=$(printf '\033[36m')
  BOLD=$(printf '\033[1m'); RESET=$(printf '\033[0m')
else
  RED=''; GREEN=''; YELLOW=''; CYAN=''; BOLD=''; RESET=''
fi

passes=0
failures=0

# Fetch a URL with Fastly debugging on, discarding the body and printing
# only the response headers (no "< " prefix, unlike curl -v). Extra args
# (e.g. -H "Cookie: ...") are passed through.
fetch_headers() {
  curl -sS -o /dev/null -D - -H 'Fastly-Debug: 1' "$@"
}

# In --verbose mode, print a labeled, indented dump of a header block (with
# CR characters stripped so it reads cleanly). No-op otherwise.
# Usage: vlog "label" "$headers"
vlog() {
  [ -n "$VERBOSE" ] || return 0
  printf '%s    --- %s ---%s\n' "$CYAN" "$1" "$RESET"
  printf '%s\n' "$2" | tr -d '\r' | sed '/^$/d; s/^/      /'
}

# Fetch + (optionally) dump in one step, returning the headers on stdout.
# The dump goes to stderr so it never pollutes the captured value.
# Usage: headers=$(fetch_and_log "label" [curl args...] URL)
fetch_and_log() {
  local label="$1"; shift
  local headers
  headers=$(fetch_headers "$@")
  vlog "$label" "$headers" >&2
  printf '%s' "$headers"
}

# Extract the last value of a (case-insensitive) header from header text.
# Usage: header_value "X-Cache" "$headers"
header_value() {
  printf '%s\n' "$2" | grep -i "^$1:" | tail -1 |
    sed 's/^[^:]*:[[:space:]]*//' | tr -d '\r'
}

# Does the response indicate a Fastly cache HIT? Fastly may chain nodes
# (e.g. "X-Cache: MISS, HIT"), so we look for HIT anywhere in the value.
is_hit() {
  printf '%s\n' "$1" | grep -iq '^X-Cache:.*HIT'
}

report() { # status_bool description detail
  if [ "$1" = 'true' ]; then
    passes=$((passes + 1))
    printf '  %sPASS%s %s\n' "$GREEN" "$RESET" "$2"
  else
    failures=$((failures + 1))
    printf '  %sFAIL%s %s\n' "$RED" "$RESET" "$2"
  fi
  [ -n "${3:-}" ] && printf '       %s%s%s\n' "$YELLOW" "$3" "$RESET"
  return 0
}

printf '%sVerifying CDN caching%s\n' "$BOLD" "$RESET"
printf '  Base URL:   %s\n' "$BASE"
printf '  Show page:  %s\n' "$SHOW_URL"
printf '  JSON:       %s\n' "$JSON_URL"
[ -n "$VERBOSE" ] && printf '  Verbose:    on\n'
printf '\n'

# --- Item 1: anonymous request is cacheable and served from cache ----------
printf '%s1. Anonymous show page is cacheable (MISS then HIT), no cookie%s\n' \
  "$BOLD" "$RESET"
h1=$(fetch_and_log 'anon request 1 (warm)' "$SHOW_URL")
h2=$(fetch_and_log 'anon request 2 (expect HIT)' "$SHOW_URL")
xc1=$(header_value 'X-Cache' "$h1")
xc2=$(header_value 'X-Cache' "$h2")
surrogate=$(header_value 'Surrogate-Control' "$h1")
setcookie=$(printf '%s\n' "$h1" "$h2" | grep -i '^Set-Cookie:.*_BadgeApp_session')

if [ -n "$surrogate" ]; then
  report true "advertises Surrogate-Control to the CDN" "Surrogate-Control: $surrogate"
else
  report false "advertises Surrogate-Control to the CDN" \
    'missing Surrogate-Control: Rails is not marking this page cacheable'
fi

if [ -z "$setcookie" ]; then
  report true 'sets no _BadgeApp_session cookie'
else
  report false 'sets no _BadgeApp_session cookie' "$setcookie"
fi

if is_hit "$h2"; then
  report true 'second request is a Fastly HIT' "X-Cache: $xc1 -> $xc2"
else
  report false 'second request is a Fastly HIT' \
    "X-Cache: $xc1 -> $xc2 (Fastly bypass rule may be passing all HTML, or caching not yet enabled)"
fi

# --- Item 2: session cookie bypasses the cache -----------------------------
printf '\n%s2. _BadgeApp_session request bypasses the cache (never HIT)%s\n' \
  "$BOLD" "$RESET"
fetch_and_log 'anon warm 1' "$SHOW_URL" >/dev/null # ensure a cached object exists
fetch_and_log 'anon warm 2' "$SHOW_URL" >/dev/null
hs=$(fetch_and_log 'with _BadgeApp_session cookie' \
  -H 'Cookie: _BadgeApp_session=anything' "$SHOW_URL")
xcs=$(header_value 'X-Cache' "$hs")
if is_hit "$hs"; then
  report false 'session-cookie request is not served from cache' \
    "X-Cache: $xcs (SECURITY: a personalized request got a cached anonymous page -- check the Fastly bypass rule)"
else
  report true 'session-cookie request is not served from cache' "X-Cache: $xcs"
fi

# --- Item 3: remember-me cookie bypasses the cache -------------------------
printf '\n%s3. remember_token request bypasses the cache (never HIT)%s\n' \
  "$BOLD" "$RESET"
hr=$(fetch_and_log 'with remember_token cookie' \
  -H 'Cookie: remember_token=anything' "$SHOW_URL")
xcr=$(header_value 'X-Cache' "$hr")
if is_hit "$hr"; then
  report false 'remember-me request is not served from cache' \
    "X-Cache: $xcr (SECURITY: check the Fastly bypass rule)"
else
  report true 'remember-me request is not served from cache' "X-Cache: $xcr"
fi

# --- Item 4: JSON still caches regardless of cookies (no regression) -------
printf '\n%s4. JSON still caches despite a session cookie (no regression)%s\n' \
  "$BOLD" "$RESET"
fetch_and_log 'json warm (with cookie)' \
  -H 'Cookie: _BadgeApp_session=anything' "$JSON_URL" >/dev/null
hj=$(fetch_and_log 'json with cookie (expect HIT)' \
  -H 'Cookie: _BadgeApp_session=anything' "$JSON_URL")
xcj=$(header_value 'X-Cache' "$hj")
if is_hit "$hj"; then
  report true 'JSON is served from cache even with a cookie' "X-Cache: $xcj"
else
  report false 'JSON is served from cache even with a cookie' \
    "X-Cache: $xcj (JSON is meant to cache regardless of cookies)"
fi

# --- Summary ---------------------------------------------------------------
printf '\n%sSummary:%s %s%d passed%s, %s%d failed%s\n' \
  "$BOLD" "$RESET" "$GREEN" "$passes" "$RESET" "$RED" "$failures" "$RESET"

[ "$failures" -eq 0 ]
