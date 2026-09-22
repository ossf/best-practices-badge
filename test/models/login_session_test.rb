# frozen_string_literal: true

# Copyright the Linux Foundation and the
# OpenSSF Best Practices badge contributors
# SPDX-License-Identifier: MIT

require 'test_helper'

# rubocop:disable-next Metrics/ClassLength
class LoginSessionTest < ActiveSupport::TestCase
  setup do
    @user = users(:test_user)
  end

  test 'create_for stores a digest, never the raw session id' do
    login_session = LoginSession.create_for(
      @user, ip_address: '127.0.0.1', user_agent: 'test-agent'
    )
    raw_id = login_session.raw_session_id
    assert_not_nil raw_id
    assert_not_equal raw_id, login_session.session_id_digest
    # The raw value must never leak into any stored column, not just the
    # one column obviously meant to hold a digest.
    login_session.attributes.each_value do |value|
      assert_not_includes value.to_s, raw_id if value.is_a?(String)
    end
  end

  test 'create_for sets user, ip_address, user_agent, and last_used_at' do
    login_session = LoginSession.create_for(
      @user, ip_address: '127.0.0.1', user_agent: 'test-agent'
    )
    assert_equal @user.id, login_session.user_id
    assert_equal '127.0.0.1', login_session.ip_address
    assert_equal 'test-agent', login_session.user_agent
    assert_in_delta Time.now.utc, login_session.last_used_at, 5.seconds
  end

  test 'find_by_session_id round-trips with create_for' do
    login_session = LoginSession.create_for(
      @user, ip_address: '127.0.0.1', user_agent: 'test-agent'
    )
    found = LoginSession.find_by_session_id(login_session.raw_session_id)
    assert_equal login_session, found
  end

  test 'find_by_session_id returns nil for an unknown session id' do
    assert_nil LoginSession.find_by_session_id('bogus-session-id')
  end

  test 'find_by_session_id returns nil for a blank session id' do
    assert_nil LoginSession.find_by_session_id(nil)
    assert_nil LoginSession.find_by_session_id('')
  end

  test 'idle_expired? is false just inside the window, true just past it' do
    login_session = LoginSession.create_for(
      @user, ip_address: '127.0.0.1', user_agent: 'test-agent'
    )
    login_session.last_used_at = SessionsHelper::SESSION_TTL.ago.utc + 1.minute
    assert_not login_session.idle_expired?
    login_session.last_used_at = SessionsHelper::SESSION_TTL.ago.utc - 1.minute
    assert login_session.idle_expired?
  end

  test 'absolutely_expired? is false just inside the cap, true just past it' do
    login_session = LoginSession.create_for(
      @user, ip_address: '127.0.0.1', user_agent: 'test-agent'
    )
    login_session.created_at =
      SessionsHelper::ABSOLUTE_SESSION_AGE.ago.utc + 1.minute
    assert_not login_session.absolutely_expired?
    login_session.created_at =
      SessionsHelper::ABSOLUTE_SESSION_AGE.ago.utc - 1.minute
    assert login_session.absolutely_expired?
  end

  test 'destroying a user destroys their login_sessions' do
    login_session = LoginSession.create_for(
      @user, ip_address: '127.0.0.1', user_agent: 'test-agent'
    )
    # Assert against this user's own rows specifically, not a global
    # LoginSession.count delta: many other tests legitimately create
    # LoginSession rows for this same fixture user (any test that calls
    # log_in_as(users(:test_user)) does), so a global-count assertion is
    # fragile to test order/parallelism even though transactional
    # fixtures should isolate each test's own writes.
    assert LoginSession.exists?(login_session.id)
    @user.destroy
    assert_not LoginSession.exists?(login_session.id)
    assert_empty LoginSession.where(user_id: @user.id)
  end

  test 'purge_stale deletes idle-expired rows but keeps rows just inside the window' do
    fresh = LoginSession.create_for(
      @user, ip_address: '127.0.0.1', user_agent: 'fresh'
    )
    fresh.update_columns(last_used_at: SessionsHelper::SESSION_TTL.ago.utc + 1.minute)

    stale = LoginSession.create_for(
      @user, ip_address: '127.0.0.1', user_agent: 'stale'
    )
    stale.update_columns(last_used_at: SessionsHelper::SESSION_TTL.ago.utc - 1.minute)

    assert_equal 1, LoginSession.purge_stale
    assert LoginSession.exists?(fresh.id)
    assert_not LoginSession.exists?(stale.id)
  end

  test 'purge_stale deletes absolutely-expired rows even if recently used' do
    fresh = LoginSession.create_for(
      @user, ip_address: '127.0.0.1', user_agent: 'fresh'
    )
    fresh.update_columns(
      created_at: SessionsHelper::ABSOLUTE_SESSION_AGE.ago.utc + 1.minute
    )

    stale = LoginSession.create_for(
      @user, ip_address: '127.0.0.1', user_agent: 'stale'
    )
    # last_used_at stays at its just-created, recent value (not
    # idle-expired), to isolate the absolute-cap branch of purge_stale's
    # OR condition specifically, rather than the idle branch tested above.
    stale.update_columns(
      created_at: SessionsHelper::ABSOLUTE_SESSION_AGE.ago.utc - 1.minute
    )

    assert_equal 1, LoginSession.purge_stale
    assert LoginSession.exists?(fresh.id)
    assert_not LoginSession.exists?(stale.id)
  end

  # hex_key_for (HexKeyManagement): production branch (env_test: false)
  # is never reached during normal test runs; exercise it explicitly.

  test 'hex_key_for falls back to test key when env var absent' do
    saved = ENV.delete('SESSION_ID_HMAC_KEY')
    assert_equal LoginSession::TEST_SESSION_ID_HMAC_KEY,
                 LoginSession.send(:hex_key_for, env_var: 'SESSION_ID_HMAC_KEY',
                                                  test_value: LoginSession::TEST_SESSION_ID_HMAC_KEY,
                                                  env_test: false)
  ensure
    ENV['SESSION_ID_HMAC_KEY'] = saved if saved
  end

  test 'hex_key_for uses SESSION_ID_HMAC_KEY env var when set' do
    fake_key = 'c' * LoginSession::DIGITS_OF_SESSION_ID_HMAC_KEY
    saved = ENV.fetch('SESSION_ID_HMAC_KEY', nil)
    ENV['SESSION_ID_HMAC_KEY'] = fake_key
    assert_equal fake_key,
                 LoginSession.send(:hex_key_for, env_var: 'SESSION_ID_HMAC_KEY',
                                                  test_value: LoginSession::TEST_SESSION_ID_HMAC_KEY,
                                                  env_test: false)
  ensure
    ENV['SESSION_ID_HMAC_KEY'] = saved
  end
end
