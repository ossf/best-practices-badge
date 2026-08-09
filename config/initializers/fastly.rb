# frozen_string_literal: true

# Copyright 2015-2017, the Linux Foundation, IDA, and the
# OpenSSF Best Practices badge contributors
# SPDX-License-Identifier: MIT

# See https://github.com/fastly/fastly-rails

require 'net/https'
require 'json'
require 'ipaddr'
require 'security_utils'

# Download list of valid IP addresses from this (be SURE this is https!):
# iplist_uri = 'https://api.fastly.com/public-ip-list'

# Ensure that there's *a* value for valid_client_ips (nil=all allowed)
Rails.configuration.valid_client_ips = nil

# Configure Rails trusted proxies using dynamic and static sources.
# The trusted proxies' IP addresses are *not* being used for user
# authentication; they're being used to counter CDN piercing and to
# ensure that our rate limits apply to the correct IP addresses.
edge_proxies =
  SecurityUtils.load_trusted_proxies(
    url: ENV.fetch('TRUSTED_PROXIES_URL', nil),
    static: ENV.fetch('TRUSTED_PROXIES', nil),
    fail_fast: Rails.env.production?,
    disabled: ENV['TRUSTED_PROXIES_DISABLED'] == 'true'
  )

# Store the edge-only list for fast Origin Shielding checks
SecurityUtils.edge_proxies = edge_proxies

# Merge with Rails defaults and freeze
Rails.application.config.action_dispatch.trusted_proxies =
  (ActionDispatch::RemoteIp::TRUSTED_PROXIES + edge_proxies).freeze

if !Rails.env.test?
  Rails.logger.warn 'FASTLY_API_KEY not set.' unless ENV['FASTLY_API_KEY']
  Rails.logger.warn 'FASTLY_SERVICE_ID not set.' unless ENV['FASTLY_SERVICE_ID']
end

# Verify Fastly credentials are valid at boot time so misconfiguration is
# caught immediately on deploy rather than silently corrupting CDN state.
# A wrong FASTLY_SERVICE_ID or FASTLY_API_KEY causes purge calls to
# succeed at the HTTP level while targeting the wrong service, making the
# failure invisible to the StandardError rescue in fastly_rails.rb.
# Non-fatal: a transient Fastly outage at boot must not prevent startup.
#
# We read ENV directly here rather than reusing FastlyRails::FASTLY_API_KEY
# and FastlyRails::FASTLY_SERVICE_ID because Rails discourages referencing
# Zeitwerk-autoloaded constants (app/lib/) inside initializers: in development
# mode constants can be reloaded but initializers only run once at boot.
fastly_api_key = ENV.fetch('FASTLY_API_KEY', nil)
fastly_service_id = ENV.fetch('FASTLY_SERVICE_ID', nil)

# We *must* do this in after_initialize, not directly in this initializer.
# Zeitwerk's main autoloader is set up in Rails' Finisher, which runs
# *after* config/initializers, so constants autoloaded from app/ (such as
# FastlyRails) cannot be resolved here.  This code used to call
# FastlyRails directly, so it raised NameError on every boot.  NameError
# is a StandardError, so the rescue below caught it and logged it as a
# possible network problem.  In other words, this check never checked
# anything, and the log gave a misleading reason.  See
# docs/warning_failures.md.  In after_initialize the autoloader is ready,
# and we still run before the web server accepts any requests.
if !Rails.env.test? && fastly_api_key.present? && fastly_service_id.present?
  Rails.application.config.after_initialize do
    response = HTTParty.get(
      "https://api.fastly.com/service/#{fastly_service_id}",
      headers: { 'Fastly-Key': fastly_api_key, 'User-Agent': USER_AGENT },
      timeout: 5
    )
    if response.success?
      FastlyRails.log_service_name(
        response['name'],
        ENV.fetch('FASTLY_SERVICE_NAME_EXPECTED', nil),
        fastly_service_id
      )
    else
      Rails.logger.error(
        "FASTLY CONFIG ERROR: Cannot access service #{fastly_service_id} " \
        "(HTTP #{response.code}: #{response.body}). " \
        'Check FASTLY_SERVICE_ID and FASTLY_API_KEY — ' \
        'CDN purges will fail silently until this is resolved.'
      )
    end
  # Only claim a network problem when we really had one.  We list the
  # network exception classes on purpose; the old blanket rescue is what
  # let a bug in our own code look like a Fastly outage.
  rescue HTTParty::Error, SocketError, OpenSSL::SSL::SSLError,
         Net::OpenTimeout, Net::ReadTimeout, Errno::ECONNREFUSED,
         Errno::ECONNRESET, EOFError => e
    Rails.logger.warn(
      'FASTLY WARNING: Cannot reach Fastly API at startup ' \
      "(#{e.class}: #{e}). This may be a transient network issue; " \
      'CDN purge ability is unconfirmed.'
    )
  # Anything else is a bug in this check itself, not a problem at Fastly,
  # so say that instead.  This is still non-fatal; if we can't verify the
  # CDN that's no reason to refuse to start.
  rescue StandardError => e
    Rails.logger.error(
      'FASTLY CHECK BUG: the startup credential check itself failed ' \
      "(#{e.class}: #{e}). This is our bug, not a Fastly outage. " \
      'CDN purge ability is unconfirmed.'
    )
  end
end

# FastlyRails.configure do |c|
#   c.api_key = ENV['FASTLY_API_KEY'] # Fastly api key, required for it to work
#   c.max_age = 86_400 # time in seconds, optional, default 2592000 (30 days)
#   c.service_id = ENV['FASTLY_SERVICE_ID'] # The Fastly service, required
#   c.purging_enabled = !Rails.env.development? && !Rails.env.test? &&
#                       ENV['FASTLY_API_KEY']
# end
#
# if ENV['FASTLY_CLIENT_IP_REQUIRED']
#   # Set up list of valid IP addresses, assumes iplist_uri is accessible.
#   # Note: Ruby's HTTP.get *does* check for invalid certs, e.g., it
#   # will error out if given 'https://wrong.host.badssl.com/' (*yay*).
#   # Don't call log, may not be ready yet
#   # Rails.logger.info 'Getting Fastly public IPs'
#   iplist_text = Net::HTTP.get(URI(iplist_uri))
#   iplist_json = JSON.parse(iplist_text)
#   iplist_ips = iplist_json['addresses'].map { |i| IPAddr.new(i) }
#   Rails.configuration.valid_client_ips = iplist_ips
# end
