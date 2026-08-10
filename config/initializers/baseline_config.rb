# frozen_string_literal: true

# Copyright the Linux Foundation and the
# OpenSSF Best Practices badge contributors
# SPDX-License-Identifier: MIT

require 'yaml'
require 'erb'

config_file = Rails.root.join('config', 'baseline_config.yml')
BASELINE_CONFIG = YAML.safe_load(
  ERB.new(File.read(config_file)).result,
  aliases: true
).fetch('baseline', {}).with_indifferent_access.freeze
