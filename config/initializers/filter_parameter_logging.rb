# frozen_string_literal: true

# Copyright 2015-2017, the Linux Foundation, IDA, and the
# OpenSSF Best Practices badge contributors
# SPDX-License-Identifier: MIT

# Be sure to restart your server when you modify this file.

# Configure sensitive parameters which will be filtered from the log file.
# These broader patterns match the Rails 8 defaults and catch variants like
# password_confirmation, current_password, api_key, auth_token, etc.
Rails.application.config.filter_parameters +=
  %i[passw email secret token _key crypt salt certificate otp ssn]
