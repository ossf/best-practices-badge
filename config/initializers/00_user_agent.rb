# frozen_string_literal: true

# Copyright the Linux Foundation and the
# OpenSSF Best Practices badge contributors
# SPDX-License-Identifier: MIT

# Default User-Agent for outgoing HTTP requests.
# It can be overridden by the environment variable BADGEAPP_USER_AGENT.
# We identify the application and its version/URL so that site owners
# can contact us if there are issues.
USER_AGENT = ENV.fetch(
  'BADGEAPP_USER_AGENT',
  'OpenSSF-Best-Practices-Badge-App/1.1 ' \
  '(+https://www.bestpractices.dev)'
).freeze
