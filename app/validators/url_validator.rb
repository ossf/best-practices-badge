# frozen_string_literal: true

# Copyright 2015-2017, the Linux Foundation, IDA, and the
# OpenSSF Best Practices badge contributors
# SPDX-License-Identifier: MIT

require 'uri'
require 'security_utils'

class UrlValidator < ActiveModel::EachValidator
  # Check URL (invoked in models where "validates ... url: true").
  # These are the rules checked by the *server*.  The client does some
  # quick sanity checks (see app/projects/new.html.erb), which should not
  # forbid anything we'd allow, but we can't trust
  # those checks because an attacker can easily bypass client-side checks.
  # The URL validation rules are somewhat overly strict, but should serve;
  # the idea is to prevent attackers from inserting redirecting URLs
  # that can sometimes be used to attack third-party sites via the BadgeApp.
  # For example, this does *not* include "?...", or ones with <, and the
  # use of %-encoded bytes is restricted.
  # We can gradually loosen this if needed.  Note that this pattern is
  # more restrictive than the ones we allow in markdown justifications,
  # because the BadgeApp doies *not* follow those URLs for further processing.
  # This regex is our creation, because we're trying to prevent certain URLs
  # that by *spec* are legal.  The first part is an expression of the DNS spec,
  # the latter simply limits the character set used in the path.
  URL_REGEX =
    %r{\A(|  # Empty allowed
        https?://
        [A-Za-z0-9][-A-Za-z0-9_.]*  # domain name per DNS spec; includes I18N.
        (/
          ([-A-Za-z0-9_.:/+!,#@~]|    # allow these ASCII chars.
           %(20|[89A-Ea-e][0-9A-Fa-f]|[Ff][0-7]))*  # Allow some %-encoded
        )?)\z}x

  # Unescape but do *not* force an encoding (so we can force it separately
  # and check for validity).
  # This used to be provided by URL.unescape, but that's obsolete and
  # we want this to keep working *even* if URL.unescape is dropped.
  # Based on Ruby's CGI "unescape" in cgi/util.rb
  def unescape_unforced(string)
    str =
      string.tr('+', ' ').b.gsub(/((?:%[0-9a-fA-F]{2})+)/) do |m|
        [m.delete('%')].pack('H*')
      end
    str
  end

  # Return true if URL matches URL_REGEX and its decoding is valid UTF-8,
  # and it's not a dubious URL (e.g. IP address or loopback).
  def url_acceptable?(value)
    if URL_REGEX.match?(value) && !SecurityUtils.dubious_url?(value)
      # The unescapes the *entire* URL, but that's okay because we've
      # already confirmed that the domain name doesn't have "%"
      unescape_unforced(value).force_encoding('UTF-8').valid_encoding?
    else
      false
    end
  end

  def validate_each(record, attribute, value)
    return if url_acceptable?(value)

    record.errors.add attribute, (options[:message] ||
                                  I18n.t('error_messages.url_message'))
  end
end
