# frozen_string_literal: true

# Copyright 2015-2017, the Linux Foundation, IDA, and the
# OpenSSF Best Practices badge contributors
# SPDX-License-Identifier: MIT

require 'test_helper'

class TranslationTest < ActionDispatch::IntegrationTest
  # setup do
  # end

  # Test typical pages in all supported locales.  This helps us detect
  # if there's a locale-specific problem, e.g., if we lack the necessary
  # keys for pluralization (Russian and Arabic have esp. complex requirements).
  test 'Can get common pages in all supported locales' do
    I18n.available_locales.each do |my_locale|
      get "/#{my_locale}"
      assert_response :success

      # TODO
      # get "/#{my_locale}/"
      # assert_redirected_to "/#{my_locale}"

      get "/#{my_locale}/projects"
      assert_response :success

      get "/#{my_locale}/projects/#{projects(:one).id}/passing"
      assert_response :success

      get "/#{my_locale}/users/#{users(:test_user).id}"
      assert_response :success

      get "/#{my_locale}/signup"
      assert_response :success

      get "/#{my_locale}/login"
      assert_response :success

      get "/#{my_locale}/criteria_stats"
      assert_response :success

      # Skip testing /project_stats - it takes longer to generate and
      # is unlikely to be a problem.
    end
  end

  test 'Correctly redirect to browser default locale at root' do
    get '/', headers: { HTTP_ACCEPT_LANGUAGE: 'fr,en-US;q=0.7,en;q=0.3' }
    assert_redirected_to root_url(locale: :fr)
  end

  test 'Correctly redirect to English at root when no locale given' do
    get '/'
    assert_redirected_to root_url(locale: :en)
  end

  test 'Do not switch locale if German given' do
    get '/de', headers: { HTTP_ACCEPT_LANGUAGE: 'fr,en-US;q=0.7,en;q=0.3' }
    assert_response :success
  end

  test 'Do not switch locale if English given' do
    get '/en', headers: { HTTP_ACCEPT_LANGUAGE: 'fr,en-US;q=0.7,en;q=0.3' }
    assert_response :success
  end

  test 'Correctly switch to browser default locale in /projects' do
    get '/projects',
        headers: { HTTP_ACCEPT_LANGUAGE: 'fr,en-US;q=0.7,en;q=0.3' }
    assert_redirected_to projects_url(locale: :fr)
  end

  test 'Do not switch locale of /projects if one given' do
    get '/de/projects',
        headers: { HTTP_ACCEPT_LANGUAGE: 'fr,en-US;q=0.7,en;q=0.3' }
    assert_response :success
  end
end
