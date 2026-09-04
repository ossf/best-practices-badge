# frozen_string_literal: true

# Copyright the Linux Foundation and the
# OpenSSF Best Practices badge contributors
# SPDX-License-Identifier: MIT

require 'test_helper'

class BadgeStaticControllerTest < ActionDispatch::IntegrationTest
  test 'get badge static image for 0' do
    get '/badge_static/0'
    assert_response :success
    assert_includes @response.body, '<svg xmlns='
    assert_includes @response.body, 'in progress 0%'
    assert_not_includes @response.body, 'gold'
    # Metal values (percentages and level names) carry the metal series key.
    assert_equal "/badge_percent/0 #{ApplicationController::METAL_BADGES_SURROGATE_KEY}",
                 @response.headers['Surrogate-Key']
  end

  test 'get badge static image for 99' do
    get '/badge_static/99'
    assert_response :success
    assert_includes @response.body, '<svg xmlns='
    assert_includes @response.body, 'in progress 99%'
    assert_not_includes @response.body, 'gold'
  end

  test 'get badge static image for passing' do
    get '/badge_static/passing'
    assert_response :success
    assert_includes @response.body, '<svg xmlns='
    assert_includes @response.body, 'passing'
    assert_not_includes @response.body, 'gold'
  end

  test 'get badge static image for silver' do
    get '/badge_static/silver'
    assert_response :success
    assert_includes @response.body, '<svg xmlns='
    assert_includes @response.body, 'silver'
    assert_not_includes @response.body, 'gold'
  end

  test 'get badge static image for gold' do
    get '/badge_static/gold'
    assert_response :success
    assert_includes @response.body, '<svg xmlns='
    assert_includes @response.body, 'gold'
    assert_not_includes @response.body, 'silver'
    assert_not_includes @response.body, 'passing'
  end

  test 'get badge static image for baseline-1' do
    get '/badge_static/baseline-1'
    assert_response :success
    assert_includes @response.body, '<svg xmlns='
    # Baseline values carry the baseline series key, not the metal one --
    # this is the same badge_baseline_1.svg a baseline version bump
    # regenerates, so it must be purgeable by BASELINE_BADGES_SURROGATE_KEY.
    assert_equal "/badge_percent/baseline-1 #{ApplicationController::BASELINE_BADGES_SURROGATE_KEY}",
                 @response.headers['Surrogate-Key']
  end

  test 'get badge static image for baseline-pct-50' do
    get '/badge_static/baseline-pct-50'
    assert_response :success
    assert_includes @response.body, '<svg xmlns='
    assert_equal "/badge_percent/baseline-pct-50 #{ApplicationController::BASELINE_BADGES_SURROGATE_KEY}",
                 @response.headers['Surrogate-Key']
  end

  test 'cannot get badge static image for bad value' do
    get '/badge_static/0q'
    assert_response :not_found
    assert_includes @response.body, 'Sorry, '
    assert_not_includes @response.body, '0q'
  end
end
