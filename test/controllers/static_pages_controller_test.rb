# frozen_string_literal: true

# copyright 2015-2017, the linux foundation, ida, and the
# OpenSSF Best Practices badge contributors
# SPDX-License-Identifier: MIT

require 'test_helper'

# NOTE: we inherit from ActionDispatch::IntegrationTest, not
# ActionController::TestCase, because the latter is obsolete.
# rubocop: disable Metrics/BlockLength, Metrics/ClassLength
class StaticPagesControllerTest < ActionDispatch::IntegrationTest
  test 'should get home' do
    get root_path(locale: 'en')
    assert_response :success
    # assert_template 'home'
    # Check that it has some content
    assert_includes @response.body, 'Open Source Software'
    assert_includes @response.body, 'More information on the'
    assert_includes @response.body, 'target='
    # target=... better not end immediately, we need rel="noopener"
    assert_not_includes @response.body, 'target=[^ >]+>'
    # Check that our preload statements are present
    assert_select(
      'head link[rel="preload"][as="style"][type="text/css"]' \
      '[href^="/assets/"]'
    )
    assert_select(
      'head link[rel="preload"][as="script"][type="application/javascript"]' \
      '[href^="/assets/"]'
    )
    # Ensure locale cross-references are present, and that
    # the home page URL doesn't have a trailing slash UNLESS there's no locale.
    # If there's no locale, include a '/' to be consistent with root_path.
    #
    # There's a weird test environment artifact I haven't been
    # able to track down.  The view response sometimes has an original url of
    # http://127.0.0.1:31337 and other times it's http://www.example.com.
    # Values such as "request.host" are consistently the second value.
    # This doesn't happen when we only test this file, but instead happens
    # when there's a full "rails test" - which means some other test
    # causes this.  It seems to be an artifact of the test environment, and
    # not actually a bug in the deployed code, so the test here will be
    # flexible to handle the variations that occur in the test environment.
    # See also: projects_controller_test.rb
    #
    # We'll use assert_select to check that it's being interpreted correctly.
    # The Rails documentation is *terribly* outdated.  It claims this works:
    # assert_select 'link[rel="alternate"][hreflang="x-default"][href=?]',
    # but Rails 4.2 changed the required syntax to use ":match".  See:
    # https://github.com/rails/rails/issues/19098
    #
    assert_includes I18n.available_locales, :en
    assert_includes I18n.available_locales, :fr
    I18n.available_locales.each do |loc|
      # Metadata about related pages (useful for search engines)
      assert_select(
        'head link[rel="alternate"][hreflang="' + loc.to_s +
        '"]:match("href", ?)',
        %r{\Ahttps?://[a-z0-9.:]+/#{loc}\z}
      )
      # User locale selector (useful for users)
      assert_select(
        'li a:match("href", ?)',
        %r{\Ahttps?://[a-z0-9.:]+/#{loc}\z}
      )
    end
    assert_select(
      'head link[rel="alternate"][hreflang="x-default"]:match("href", ?)',
      %r{\Ahttps?://[a-z0-9.:]+/\z}
    )
  end

  test 'should get home in French when fr locale in URL' do
    get root_path(locale: :fr)
    assert_response :success
    # assert_template 'home'
    # Check that it has some content
    assert_includes @response.body, 'les projets de logiciel libre'
  end

  test 'should get cookie page' do
    get cookies_path(locale: :en)
    assert_response :success
    assert_includes @response.body, 'About Cookies'
    assert_includes @response.body, 'small data files'
  end

  test 'should get robots.txt' do
    get robots_path(locale: :en)
    assert_response :success
  end

  test 'should get criteria' do
    get criteria_stats_path(locale: :en)
    assert_response :success
    assert_includes @response.body, 'included in the percentage calculations'

    get criteria_stats_path(locale: :fr)
    assert_response :success
    assert_includes @response.body, 'Vous pouvez voir des statistiques'

    get criteria_stats_path(locale: :'zh-CN')
    assert_response :success
    assert_includes @response.body, '条款'
  end

  test 'should redirect criteria with trailing slash' do
    get '/en/criteria_stats/'
    assert_redirected_to '/en/criteria_stats'
    follow_redirect!
    assert_response :success
    # Notice that the trailing slash is now gone
    assert_equal '/en/criteria_stats', @request.fullpath
    assert_includes @response.body, 'included in the percentage calculations'
  end

  test 'should get criteria discussion' do
    get '/en/criteria_discussion'
    assert_response :success
    assert_includes @response.body, 'no set of practices'
  end

  test 'Ban WordPress admin request' do
    get '/wp-admin'
    assert_response :forbidden
    assert_includes @response.body, 'Forbidden'
  end

  # In a few special cases we fail fast to minimize processing of it.
  test 'No such page in well-known returns 404' do
    get '/.well-known/i-do-not-exist'
    assert_response :missing
    assert_includes @response.body, 'Error 404: Page Not Found'
    assert_includes @response.body, 'Sorry, no such page exists.'
  end

  test 'Missing page should redirect and then return 404' do
    get '/asdfasdfasdf'
    assert_response :missing
    assert_includes @response.body, 'Error 404: Page Not Found'
    assert_includes @response.body, 'Sorry, no such page exists'
  end

  test 'No such page in a locale returns 404' do
    get '/en/i-do-not-exist'
    assert_response :missing
    assert_includes @response.body, 'Error 404: Page Not Found'
    assert_includes @response.body, 'Sorry, no such page exists.'
  end

  test 'No such page that looks like a locale returns 404' do
    get '/no-such-page'
    assert_response :missing
    assert_includes @response.body, 'Error 404: Page Not Found'
    assert_includes @response.body, 'Sorry, no such page exists.'
  end

  test 'No such page in fr locale returns 404 with fr messages' do
    get '/fr/no-such-page'
    assert_response :missing
    assert_includes @response.body, 'Erreur 404 - Page non trouvée'
    assert_includes @response.body, 'Désolé, cette page n&#39;existe pas.'
  end

  # Accept-Language is an HTTP header sent by the browser to tell us
  # what locale to prefer.  Test to ensure that if we do NOT get a
  # locale in the URL, we'll use the browser Accept-Language value.
  test 'No such page with fr Accept-Language returns 404 with fr messages' do
    get '/no-such-page', headers: {
      'Accept-Language' => 'fr-CH, fr;q=0.9, en;q=0.8, de;q=0.7, *;q=0.5'
    }
    assert_response :missing
    assert_includes @response.body, 'Erreur 404 - Page non trouvée'
    assert_includes @response.body, 'Désolé, cette page n&#39;existe pas.'
  end

  # Accept-Language is overridden by a URL locale on an error message.
  test 'Express locale overrides Accept-Language in no such page' do
    get '/en/no-such-page', headers: {
      'Accept-Language' => 'fr-CH, fr;q=0.9, en;q=0.8, de;q=0.7, *;q=0.5'
    }
    assert_response :missing
    assert_includes @response.body, 'Error 404: Page Not Found'
    assert_includes @response.body, 'Sorry, no such page exists.'
  end

  # Test Google verifier.  We need this so David A. Wheeler can get
  # Google error messages.
  test 'Google verifier' do
    get '/google75f94b1182a77eb8.html'
    assert_equal "google-site-verification: google75f94b1182a77eb8.html\n",
                 @response.body
  end
end
# rubocop: enable Metrics/BlockLength, Metrics/ClassLength
