# frozen_string_literal: true

# Copyright 2015-2017, the Linux Foundation, IDA, and the
# OpenSSF Best Practices badge contributors
# SPDX-License-Identifier: MIT

# rubocop:disable Metrics/BlockLength
SecureHeaders::Configuration.default do |config|
  normal_src = ["'self'"]
  normal_src += ['https://' + ENV['PUBLIC_HOSTNAME'] + '.global.ssl.fastly.net'] if ENV['PUBLIC_HOSTNAME']
  normal_src += ['https://' + ENV['PUBLIC_HOSTNAME_ALT'] + '.global.ssl.fastly.net'] if ENV['PUBLIC_HOSTNAME_ALT']
  normal_src += ['https://' + ENV['PUBLIC_HOSTNAME_ALT']] if ENV['PUBLIC_HOSTNAME_ALT']
  normal_src += ['https://' + ENV['PUBLIC_HOSTNAME_ALT2']] if ENV['PUBLIC_HOSTNAME_ALT2']
  config.hsts = "max-age=#{20.years.to_i}; includeSubDomains; preload"
  config.x_frame_options = 'DENY'
  config.x_content_type_options = 'nosniff'
  config.x_xss_protection = '1; mode=block'
  config.x_download_options = 'noopen'
  config.x_permitted_cross_domain_policies = 'none'
  # The login page overrides this to same-origin via <meta name="referrer">
  # (app/views/sessions/new.html.erb) so that return_to values are not sent
  # to GitHub in the Referer header.  Do not weaken that override to
  # no-referrer — it causes browsers to send "Origin: null" on the OAuth POST,
  # which breaks Rails CSRF protection and makes GitHub login fail entirely.
  config.referrer_policy = 'no-referrer-when-downgrade'
  # Configure CSP
  config.csp = {
    # Control information sources
    default_src: normal_src,
    img_src: normal_src + [
      'secure.gravatar.com', 'avatars.githubusercontent.com'
    ],
    object_src: ["'none'"],
    script_src: normal_src,
    style_src: normal_src,
    # Harden CSP against attacks in other ways
    base_uri: ["'self'"],
    # This option is deprecated and marked obsolete in its specification,
    # so we no longer include it:
    # block_all_mixed_content: true, # see http://www.w3.org/TR/mixed-content/
    frame_ancestors: ["'none'"],
    form_action: normal_src # This counters some XSS busters
  }
  config.cookies = {
    secure: true, # mark all cookies as Secure
    # NOTE: The following marks all cookies as HttpOnly.  This will need
    # need to change if there's more JavaScript-based interaction.
    httponly: true,
    # Use SameSite to counter CSRF attacks when browser supports it
    # https://www.sjoerdlangkemper.nl/2016/04/14/
    # preventing-csrf-with-samesite-cookie-attribute/
    samesite: {
      strict: false # mark all cookies as SameSite=Lax (not Strict)
    }
  }
  # Not using Public Key Pinning Extension for HTTP (HPKP).
  # Yes, it can counter some attacks, but it can also cause a lot of problems;
  # one wrong move can render the site useless, and it makes it hard to
  # switch CAs if the CA behaves badly.
end
# rubocop:enable Metrics/BlockLength

# override default configuration
SecureHeaders::Configuration.override(:allow_github_form_action) do |config|
  config.csp[:form_action] += ['github.com']
end
