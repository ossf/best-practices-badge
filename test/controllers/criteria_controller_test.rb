# frozen_string_literal: true

# Copyright 2020-, the Linux Foundation and the
# OpenSSF Best Practices badge contributors
# SPDX-License-Identifier: MIT

require 'test_helper'

# rubocop:disable-next Metrics/ClassLength
class CriteriaControllerTest < ActionDispatch::IntegrationTest
  # test "the truth" do
  #   assert true
  # end
  test 'Get criteria set in English' do
    get '/en/criteria'
    assert_response :success
    assert_includes @response.body, 'Basics'
    assert_includes @response.body, 'Basic project website content'
    assert_includes @response.body,
                    'MUST succinctly describe what the software does'
    assert_includes @response.body, 'MUST achieve a passing level badge'
    assert_includes @response.body, 'MUST achieve a silver level badge'
    assert_includes @response.body,
                    'MUST document its code review requirements'
    assert_includes @response.body, 'Passing'
    assert_includes @response.body, 'Silver'
    assert_includes @response.body, 'Gold'
    assert_not_includes @response.body, 'Details:'
    assert_not_includes @response.body, 'Rationale:'
    assert_not_includes @response.body, 'Autofill:'
  end

  test 'Get criteria set in English with extra information' do
    get '/en/criteria?details=true&rationale=true&autofill=true'
    assert_response :success
    assert_includes @response.body, 'Basics'
    assert_includes @response.body, 'Basic project website content'
    assert_includes @response.body,
                    'MUST succinctly describe what the software does'
    assert_includes @response.body, 'MUST achieve a passing level badge'
    assert_includes @response.body, 'MUST achieve a silver level badge'
    assert_includes @response.body,
                    'MUST document its code review requirements'
    assert_includes @response.body, 'Passing'
    assert_includes @response.body, 'Silver'
    assert_includes @response.body, 'Gold'
    assert_includes @response.body, 'Details:'
    assert_includes @response.body, 'Rationale:'
    assert_includes @response.body, 'Autofill:'
  end

  test 'Get passing criteria set in English with details and rationale' do
    get '/en/criteria/0?details=true&rationale=true'
    assert_response :success
    assert_includes @response.body, 'Basics'
    assert_includes @response.body, 'Basic project website content'
    assert_includes @response.body,
                    'MUST succinctly describe what the software does'
    assert_includes @response.body, 'Details:'
    assert_includes @response.body, 'Rationale:'
    assert_not_includes @response.body, 'Autofill:'
  end

  test 'Get passing criteria set in English with details and autofill' do
    get '/en/criteria/0?details=true&autofill=true'
    assert_response :success
    assert_includes @response.body, 'Basics'
    assert_includes @response.body, 'Basic project website content'
    assert_includes @response.body,
                    'MUST succinctly describe what the software does'
    assert_includes @response.body, 'Details:'
    assert_not_includes @response.body, 'Rationale:'
    assert_includes @response.body, 'Autofill:'
  end

  test 'Get one criteria set, passing, in English' do
    get '/en/criteria/0'
    assert_response :success
    assert_includes @response.body, 'Basic project website content'
    assert_includes @response.body,
                    'MUST succinctly describe what the software does'
    assert_not_includes @response.body, 'Details:'
    assert_not_includes @response.body, 'Rationale:'
    assert_not_includes @response.body, 'Autofill:'
    assert_not_includes @response.body, 'MUST achieve a passing level badge'
    assert_not_includes @response.body, 'MUST achieve a silver level badge'
  end

  test 'Get baseline criteria honors boolean annotation values' do
    # Regression test for issue #3017: Criteria page renderer logic
    # should reflect the declared boolean status of the markings
    get '/en/criteria/baseline-1'
    assert_response :success
    assert_select "li[id='baseline-1.osps_ac_01_01']", count: 1 do |elements|
      text = elements.first.text
      assert_includes text, '{N/A justification}'
      assert_not_includes text, '{N/A allowed}'
      assert_not_includes text, '{Met justification}'
      assert_not_includes text, '{Met URL}'
    end
  end

  test 'Get passing criteria renders requirement annotations' do
    get '/en/criteria/0'
    assert_response :success

    assert_select "li[id='0.contribution']", count: 1 do |elements|
      text = elements.first.text
      assert_includes text, '{Met URL}'
      assert_not_includes text, '{Met justification}'
    end

    assert_select "li[id='0.vulnerability_report_response']", count: 1 do |elements|
      text = elements.first.text
      assert_includes text, '{N/A allowed}'
      assert_not_includes text, '{N/A justification}'
    end

    assert_select "li[id='0.static_analysis']", count: 1 do |elements|
      text = elements.first.text
      assert_includes text, '{N/A justification}'
      assert_not_includes text, '{N/A allowed}'
      assert_includes text, '{Met justification}'
      assert_not_includes text, '{Met URL}'
    end

    assert_select "li[id='0.description_good']", count: 1 do |elements|
      text = elements.first.text
      assert_not_includes text, '{N/A allowed}'
      assert_not_includes text, '{N/A justification}'
      assert_not_includes text, '{Met justification}'
      assert_not_includes text, '{Met URL}'
    end
  end

  test 'Get silver criterion renders strongest requirement annotation' do
    get '/en/criteria/1'
    assert_response :success

    assert_select "li[id='1.external_dependencies']", count: 1 do |elements|
      text = elements.first.text
      assert_includes text, '{Met URL}'
      assert_not_includes text, '{Met justification}'
    end
  end

  test 'Get one criteria set, silver, in English' do
    get '/en/criteria/1'
    assert_response :success
    assert_includes @response.body, 'MUST achieve a passing level badge'
    assert_includes @response.body, 'Basic project website content'
    assert_includes @response.body, 'MUST achieve a passing level badge'
    assert_not_includes @response.body, 'MUST achieve a silver level badge'
  end

  test 'Get one criteria set in French' do
    get '/fr/criteria/0'
    assert_response :success
    assert_includes @response.body, 'Basique'
    assert_includes @response.body, 'Contenu basique du site Web du projet'
    assert_includes @response.body,
                    'décrire succinctement ce que le logiciel fait'
  end

  # Getting the entire set of criteria in another language is a stress test
  # on the translation infrastructure. In particular, various keys much match.
  test 'Get entire criteria set in French' do
    get '/fr/criteria'
    assert_response :success
    assert_includes @response.body, 'Basique'
    assert_includes @response.body, 'Contenu basique du site Web du projet'
  end

  test 'Get gold criteria level' do
    get '/en/criteria/gold'
    assert_response :success
  end

  test 'Get criteria with invalid level defaults to passing' do
    get '/en/criteria/invalid_level'
    assert_response :success
    # Should default to level 0 (passing)
  end

  test 'Get criteria with bronze (synonym for passing)' do
    get '/en/criteria/bronze'
    assert_response :success
    assert_includes @response.body, 'Basic project website content'
  end

  # Security/robustness: non-scalar boolean params (which Rails parses into an
  # Array or Hash) must not raise an unhandled exception. Previously these
  # crafted query strings triggered a 500 (NoMethodError) on this public,
  # unauthenticated page; the toggle should simply fall back to its default.
  test 'Get criteria with array-valued toggle param does not error' do
    get '/en/criteria?details[]=1'
    assert_response :success
    assert_not_includes @response.body, 'Details:'
  end

  test 'Get criteria with hash-valued toggle param does not error' do
    get '/en/criteria?rationale[x]=1&autofill[y]=1'
    assert_response :success
    assert_not_includes @response.body, 'Rationale:'
    assert_not_includes @response.body, 'Autofill:'
  end
end
