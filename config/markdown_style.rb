# frozen_string_literal: true

# Copyright 2015-2017, the Linux Foundation, IDA, and the
# OpenSSF Best Practices badge contributors
# SPDX-License-Identifier: MIT

# Configure for markdownlint (mdl), a markdown style checker
# Note: mdl 0.2.0 and 0.2.1 have a serious bug in command line parsing,
# and thus you *have* to use a file to adjust rules.

all
# We *must* permit long lines, because we're using GitHub flavored markdown,
# which inserts <br> on every newline in a normal paragraph.
exclude_tag :line_length

# For the moment we'll disable many rules to make it easier to get started.
# The current plan is to slowly remove many of these over time.

# Rule MD004 requires that unordered lists use a consistent marking, but it
# has no way to enforce the rule "* at the topmost level, - at the next one".
# Having all levels with the same symbol is confusing, so we exclude the rule.
exclude_rule 'MD004'

exclude_rule 'MD007'
exclude_rule 'MD024' # Duplicate headers are okay, e.g., "Added"
exclude_rule 'MD026'
# Exclude MD029 (ordered list item prefix). MD029 forbids number
# continuation with the use of the *real* number identifiers.
# Yet that is absurdly overconstraining. We often use number continuation,
# that is, we often continue a list's numbering across intervening
# text or headings, as having unique number ids is valuable.
# CommonMark (and so GitHub) support number continuation;
# a list starts at its first # item's number, e.g., a list
# beginning "3." renders as <ol start="3">.
exclude_rule 'MD029'
exclude_rule 'MD030'
# We include rule MD032, which requires that
# lists be surrounded by blank lines (MD032).
# This detects a lot of malformed text that should be in a list but is not.
# This is also important for portability: Some markdown formatters
# require blank lines around lists, while others don't.
# To see this portability problem in action, see:
# http://johnmacfarlane.net/babelmark2/?text=Is+this+a+list%3F%0A*+First+bullet%0A*+Second+bullet%0A
exclude_rule 'MD033' # We need embedded HTML in some cases
# We have to exclude MD034, otherwise generated criteria.md doesn't work.
exclude_rule 'MD034' # Just surround bare URLs with <..>
exclude_rule 'MD036'
# exclude_rule 'MD039'
exclude_rule 'MD040'
