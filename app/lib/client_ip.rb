# frozen_string_literal: true

# Copyright 2015-2017, the Linux Foundation, IDA, and the
# OpenSSF Best Practices badge contributors
# SPDX-License-Identifier: MIT

module ClientIp
  # The trusted proxies' IP addresses are *not* being used for user
  # authentication; they're being used to counter CDN piercing and to
  # ensure that our rate limits apply to the correct IP addresses.

  # Compute the correct remote IP address for our environment.
  #
  # In our environment, the immediate connecting IP to our application
  # is always a proxy server managed by our hosting service (Heroku).
  # That proxy server (the "Heroku Router") automatically appends the
  # IP address it received the request from to the end of the
  # comma-space-separated "X-Forwarded-For" (XFF) HTTP header.
  #
  # If a request is legitimate, it passes through our CDN (Fastly)
  # before reaching Heroku. In that case, the last IP in the XFF chain
  # is a Fastly IP, and the IP before that (next-to-last) is the
  # actual client IP.
  #
  # An attacker can provide their own XFF header to try to spoof their
  # IP, but those entries will always appear earlier in the chain.
  #
  # We use Rails' built-in remote_ip, which securely traverses this
  # chain from right-to-left. It identifies the "true" client by
  # stopping at the first IP address that is NOT in our
  # TRUSTED_PROXIES list (which includes both Heroku and Fastly IPs).
  def self.acquire(req)
    req.remote_ip
  end
end
