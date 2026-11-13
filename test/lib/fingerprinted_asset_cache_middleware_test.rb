# frozen_string_literal: true

# Copyright the OpenSSF Best Practices badge contributors
# SPDX-License-Identifier: MIT

require 'test_helper'

class FingerprintedAssetCacheMiddlewareTest < ActiveSupport::TestCase
  HASH = 'f098b7364af46f181ea6b6d164e21494cbdb923eb9707491086ed622020f588f'

  def cache_control_for(path, status: 200)
    app = ->(_env) { [status, { 'cache-control' => 'unchanged' }, []] }
    middleware = FingerprintedAssetCacheMiddleware.new(app)
    middleware.call('PATH_INFO' => path)[1]['cache-control']
  end

  test 'fingerprinted asset paths are recognized' do
    [
      "/assets/favicon-#{HASH}.ico",
      "/assets/application-#{HASH}.css",
      "/assets/project-logos/linux-#{HASH}.png",
      "/assets/Thumbs_up-#{HASH}.svg.gz"
    ].each do |path|
      assert FingerprintedAssetCacheMiddleware.fingerprinted?(path), path
    end
  end

  test 'non-fingerprinted paths are not recognized' do
    [
      '/favicon.ico',
      '/404.html',
      '/.well-known/security.txt',
      '/assets/sources',
      '/assets/project-logos-originals/NOTES',
      "/assets/favicon-#{HASH[0..-2]}.ico", # Too short
      "/assets/favicon-#{HASH.upcase}.ico", # Sprockets uses lowercase
      "/assets/favicon-#{HASH}", # No extension
      "/en/projects/favicon-#{HASH}.ico", # Not under /assets/
      "/assets/favicon-#{HASH}.ico/../../secret"
    ].each do |path|
      assert_not FingerprintedAssetCacheMiddleware.fingerprinted?(path), path
    end
  end

  test 'only served fingerprinted files become immutable' do
    immutable = FingerprintedAssetCacheMiddleware::IMMUTABLE
    path = "/assets/favicon-#{HASH}.ico"
    assert_equal immutable, cache_control_for(path)
    assert_equal immutable, cache_control_for(path, status: 304)
    assert_equal 'unchanged', cache_control_for(path, status: 404)
    assert_equal 'unchanged', cache_control_for('/404.html')
  end

  test 'the default for public/ files is never immutable' do
    assert_not_includes(
      FingerprintedAssetCacheMiddleware::DEFAULT_HEADERS['cache-control'],
      'immutable'
    )
  end
end
