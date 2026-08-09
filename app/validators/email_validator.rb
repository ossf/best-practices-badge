# frozen_string_literal: true

# Copyright 2015-2017, the Linux Foundation, IDA, and the
# OpenSSF Best Practices badge contributors
# SPDX-License-Identifier: MIT

class EmailValidator < ActiveModel::EachValidator
  EMAIL_RE = /\A([^@\s]+)@((?:[-a-z0-9]+\.)+[a-z]{2,})\z/i

  def validate_each(record, attribute, value)
    return if value.match?(EMAIL_RE)

    record.errors.add attribute, (options[:message] ||
      I18n.t('error_messages.not_an_email'))
  end
end
