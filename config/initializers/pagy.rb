# frozen_string_literal: true

# Pagy initializer file (pagy 43.x)
# See https://ddnexus.github.io/pagy/ and docs/pagy-43.md for the rationale
# behind this configuration and the upgrade from pagy 9.
#
# Pagy 43 is a complete redesign of pagy 9. Notable differences relevant here:
# * Application configuration lives in Pagy::OPTIONS (pagy 9 used
#   Pagy::DEFAULT, which is now an internal frozen base).
# * The Bootstrap, overflow, and trim "extras" no longer exist as separate
#   requires: Bootstrap styling is built in (@pagy.series_nav(:bootstrap)),
#   serving an empty page on overflow is the default, and "trim" was
#   discontinued (we instead emit a rel="canonical" link; see the views).
# * Pagy ships dictionaries for every locale we use and auto-loads them on
#   demand, so there is no locale list to load here. The per-request locale
#   is set by a before_action in ApplicationController.

# Reduced from pagy's history of 30 down to 20 to reduce memory usage,
# especially for deep pagination requests from crawlers that nowadays are
# overwhelming. (Pagy 43's built-in default limit is already 20; we set it
# explicitly to document intent and guard against an upstream change.)
Pagy::OPTIONS[:limit] = 20

# We rely on pagy's default :slots (9), which renders the first and last
# pages with "..." gaps around the current page -- the pagy-43 equivalent of
# our former :size/:ends configuration. Set Pagy::OPTIONS[:slots] only to
# tune how many page links appear.
