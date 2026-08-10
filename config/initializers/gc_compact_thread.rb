# frozen_string_literal: true

# Copyright the Linux Foundation and the
# OpenSSF Best Practices badge contributors
# SPDX-License-Identifier: MIT

# Initialize periodic GC compaction in a background thread.
# The module implementation is in lib/gc_compact_thread.rb.

Rails.application.config.after_initialize do
  GcCompactThread.start_background_thread
end
