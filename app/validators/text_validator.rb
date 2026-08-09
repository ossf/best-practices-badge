# frozen_string_literal: true

# Copyright 2015-2017, the Linux Foundation, IDA, and the
# OpenSSF Best Practices badge contributors
# SPDX-License-Identifier: MIT

class TextValidator < ActiveModel::EachValidator
  # Control characters that we never appear in accepted text.
  # We specially filter them out to prevent their presence.
  # We allow only the whitespace controls that legitimately occur in user
  # text: tab (0x09), LF (0x0a), and CR (0x0d). We reject the rest of the
  # C0 range plus DEL (0x7f). NUL (0x00) is included deliberately in
  # the set we do NOT allow: PostgreSQL cannot store it in a text column,
  # so without this it would surface as a 500 at save time.
  # The pattern is intentionally limited to US-ASCII code points
  # so it stays encoding-compatible with any string that passed valid_encoding?
  # below. We don't worry about other ranges like the C1 code points
  # U+0080..U+009F ("C1"); tools generally don't do anything special
  # with them, so we don't see any risk.
  # Also, adding them would make this regexp
  # UTF-8 and could raise Encoding::CompatibilityError on binary input, the
  # opposite of the robustness we want, if we allow other encodings.
  INVALID_CONTROL = /[\x00-\x08\x0b\x0c\x0e-\x1f\x7f]/

  # Accept only well-formed text that is free of disallowed control chars.
  # @param value [String, nil] the text to check (nil is accepted)
  # @return [Boolean] true if the value is acceptable text
  def text_acceptable?(value)
    return true if value.nil?
    # All accepted text must be valid in its declared encoding (UTF-8 for our
    # inputs); reject broken byte sequences before matching.
    return false unless value.valid_encoding?

    # Use match? (not =~): it allocates no MatchData and sets no $~ global,
    # which matters on this hot, per-field validation path under heavy load.
    !value.match?(INVALID_CONTROL)
  end

  def validate_each(record, attribute, value)
    return if text_acceptable?(value)

    record.errors.add attribute, (options[:message] ||
                                  I18n.t('error_messages.valid_text'))
  end
end
