# frozen_string_literal: true

# Copyright 2015- the Linux Foundation and the
# OpenSSF Best Practices badge contributors
# SPDX-License-Identifier: MIT

require 'test_helper'
require 'minitest/mock'

class PurgeCdnProjectJobTest < ActiveJob::TestCase
  setup do
    @project = projects(:one)
  end

  test 'Purging CDN Project data' do
    assert_enqueued_jobs 0
    PurgeCdnProjectJob.set(wait: 24.hours).perform_later(@project.record_key)
    assert_enqueued_jobs 1
    PurgeCdnProjectJob.perform_now(@project.record_key)
  end

  test 'raises PurgeFailedError when purge_by_key returns false' do
    FastlyRails.stub(:purge_by_key, false) do
      # Call perform directly to bypass retry_on, which catches the exception
      # before it propagates to perform_now.
      assert_raises(PurgeCdnProjectJob::PurgeFailedError) do
        PurgeCdnProjectJob.new.perform(@project.record_key)
      end
    end
  end
end
