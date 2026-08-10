# frozen_string_literal: true

# Copyright 2015-2017, the Linux Foundation, IDA, and the
# OpenSSF Best Practices badge contributors
# SPDX-License-Identifier: MIT

require 'test_helper'

# rubocop:disable Metrics/ClassLength
class UserTest < ActiveSupport::TestCase
  setup do
    @user = User.new(
      name: 'Example User', email: 'user@example.com',
      provider: 'local',
      password: 'p@$$w0rd', password_confirmation: 'p@$$w0rd'
    )
  end

  test 'should be valid' do
    assert @user.valid?
  end

  test 'name should be present' do
    @user.name = ''
    assert_not @user.valid?
  end

  test 'email should be present' do
    @user.email = ' '
    assert_not @user.valid?
  end

  test 'username should not be too long' do
    @user.name = 'a' * 51
    assert_not @user.valid?
  end

  test 'email should not be too long' do
    @user.email = ('e' * 250) + '@mail.com'
    assert_not @user.valid?
  end

  test 'email validation should accept good emails' do
    good_emails = %w[
      user@mail.com USER@foo.COM A_US-ER@abc.mail.org
      first.last@foo.co hello+bye@baz.uk
    ]
    good_emails.each do |good_email|
      @user.email = good_email
      assert @user.valid?, "#{good_email.inspect} should be valid"
    end
  end

  test 'email validation should reject bad emails' do
    bad_emails = %w[
      user@mail,com user_at_foo.org user.name@mail.
      foo@bar_baz.com foo@bar+baz.com
    ]
    bad_emails.each do |bad_email|
      @user.email = bad_email
      assert_not @user.valid?, "#{bad_email.inspect} should be invalid"
    end
  end

  test 'emails should be unique' do
    duplicate_user = @user.dup
    @user.save!
    assert_not duplicate_user.valid?
  end

  test 'emails should be unique when ignoring case' do
    duplicate_user = @user.dup
    duplicate_user.email = @user.email.upcase
    @user.save!
    assert_not duplicate_user.valid?
  end

  # test 'password should be present and not empty' do
  #   @user.password = @user.password_confirmation = ' ' * 7
  #   assert_not @user.valid?
  # end

  test 'password should have a minimum length' do
    @user.password = @user.password_confirmation = 'a' * 7
    assert_not @user.valid?
  end

  test 'rekey test' do
    # This is a somewhat complicated setup to create a user with an old key.
    # We don't bother setting up an old blind index, because we're going
    # to just obliterate it anyway.
    user1 = User.new
    # Set a different email address to initialize attr_encrypted
    user1.email = 'wrong_email'
    # Now insert some encrypted data using an "old" key
    old_key = ['ea' * 32].pack('H*')
    old_iv = Base64.decode64(user1.encrypted_email_iv)
    email_address = 'bogus@stuff.com'
    user1.encrypted_email = User.encrypt_email(
      email_address,
      key: old_key, iv: old_iv
    )
    # Setup done, now invoke rekey to test rekeying the record.
    user1.rekey(old_key)
    # Check if rekey results are correct
    assert email_address, user1.email
    new_blind_index = BlindIndex.generate_bidx( # Recalc so test's less fragile
      email_address,
      key: [User::TEST_EMAIL_BLIND_INDEX_KEY].pack('H*'),
      options: User.blind_indexes[:email]
    )
    assert new_blind_index, user1.email_bidx
  end

  test 'associated projects should be destroyed' do
    @user.save!
    @user.projects.create!(
      homepage_url: 'https://www.example.org',
      repo_url: 'https://www.example.org/code'
    )
    assert_difference 'Project.count', -1 do
      @user.destroy
    end
  end

  test 'authenticated? should return false for a user with nil digest' do
    assert_not @user.authenticated?(:remember, '')
  end

  test 'gravatar URL for local user' do
    avatar_id = Digest::MD5.hexdigest(users(:admin_user).email.downcase)
    assert_equal "https://secure.gravatar.com/avatar/#{avatar_id}?d=mm&size=80",
                 users(:admin_user).avatar_url
  end

  test 'gravatar URL for github user' do
    assert_equal 'https://avatars.githubusercontent.com/github-user?size=80',
                 users(:github_user).avatar_url
  end

  test 'lookup_gravatar_url returns bogus hash when decryption unavailable' do
    bogus_url = "https://secure.gravatar.com/avatar/#{'0' * 32}"
    assert_equal bogus_url,
                 users(:admin_user).lookup_gravatar_url(decryption_available: false)
  end

  test 'Bcrypt of text with full rounds' do
    ActiveModel::SecurePassword.min_cost = false
    assert_match(/\$2a\$/, User.digest('foobar'))
    ActiveModel::SecurePassword.min_cost = true
  end

  class StubUserEmail < User
    def email
      raise OpenSSL::Cipher::CipherError
    end
  end

  test 'Test user.email_if_decryptable when not decryptable' do
    u = StubUserEmail.new
    assert_equal 'CANNOT_DECRYPT', u.email_if_decryptable
  end

  # deliverable_email? is the one place we decide whether an address can
  # be mailed at all, so that a caller deciding whether to send cannot
  # disagree with the mailer doing the sending.  Each rejection below is
  # a reason a mailer already declined to send; see
  # docs/warning_failures.md.
  test 'deliverable_email? accepts a usable address' do
    assert_predicate users(:test_user), :deliverable_email?
  end

  test 'deliverable_email? rejects a missing address' do
    assert_not_predicate User.new, :deliverable_email?
  end

  test 'deliverable_email? rejects an address that will not decrypt' do
    assert_not_predicate StubUserEmail.new, :deliverable_email?
  end

  test 'deliverable_email? rejects an address without an at sign' do
    u = users(:test_user)
    u.email = 'no-at-sign'
    assert_not_predicate u, :deliverable_email?
  end

  test 'Data model encrypted email addresses and blind index keys work' do
    # We precompute the user data fixtures, and it's possible we got it wrong.
    # Walk through the data set to do sanity checks for each value.
    User.find_each do |user|
      # puts(user.name)
      assert user.name.present?, "Empty name for #{user.id}"
      assert user.encrypted_email.present?,
             "Email not present for #{user.name}"
      assert(
        user.encrypted_email_iv.present?,
        "Email IV not present for #{user.name}"
      )
      # This will also fail if the email is not encrypted correctly:
      assert user.email.present?, "Email not present for #{user.name}"
      assert user.provider.present?, "Provider not present for #{user.name}"
      assert(
        user.provider != 'local' || user.password_digest.present?,
        "Local user has no password: #{user.name}, #{user.email}"
      )
      # An incorrect bidx could lead to confusing test results, so we
      # *definitely* want the following check.
      # Check that bidx was computed correctly:
      assert_equal User.generate_email_bidx(user.email), user.email_bidx
    end
  end

  test 'authenticate_local_user returns user with valid credentials' do
    user = users(:test_user)
    authenticated_user = User.authenticate_local_user(user.email, 'password')
    assert_equal user, authenticated_user
  end

  test 'authenticate_local_user returns nil with invalid password' do
    user = users(:test_user)
    authenticated_user = User.authenticate_local_user(user.email, 'wrong_password')
    assert_nil authenticated_user
  end

  test 'authenticate_local_user returns nil with non-existent email' do
    authenticated_user = User.authenticate_local_user('nonexistent@example.com', 'password')
    assert_nil authenticated_user
  end

  test 'verify_password_against_hash works correctly' do
    password = 'test_password'
    hash = User.digest(password)

    # Should return true for correct password
    assert User.verify_password_against_hash?(hash, password)

    # Should return false for incorrect password
    assert_not User.verify_password_against_hash?(hash, 'wrong_password')
  end

  test 'authenticate_local_user timing protection against email enumeration' do
    user = users(:test_user)

    # Warm up and reduce noise by running multiple iterations
    10.times do
      User.authenticate_local_user(user.email, 'wrong_password')
      User.authenticate_local_user('nonexistent@example.com', 'wrong_password')
    end

    # Collect 50 samples of each scenario for statistical analysis
    existing_email_times = []
    nonexistent_email_times = []

    50.times do
      # Time existing email with wrong password
      start_time = Time.current
      User.authenticate_local_user(user.email, 'wrong_password')
      existing_email_times << (Time.current - start_time)

      # Time non-existent email
      start_time = Time.current
      User.authenticate_local_user('nonexistent@example.com', 'wrong_password')
      nonexistent_email_times << (Time.current - start_time)
    end

    # Sort and remove outliers (best and worst 10 from each set)
    existing_trimmed = existing_email_times.sort[10..-11]
    nonexistent_trimmed = nonexistent_email_times.sort[10..-11]

    # Calculate averages of the trimmed data
    existing_avg = existing_trimmed.sum / existing_trimmed.size
    nonexistent_avg = nonexistent_trimmed.sum / nonexistent_trimmed.size

    # Compare the averages - they should be similar
    # Allow 50% variance for test environment noise, but should be much closer in practice
    timing_ratio = [existing_avg, nonexistent_avg].max / [existing_avg, nonexistent_avg].min
    assert timing_ratio < 1.5,
           "Timing difference too large (#{timing_ratio.round(3)}x) - " \
           'potential timing attack vulnerability. ' \
           "Existing avg: #{existing_avg.round(6)}s, " \
           "Nonexistent avg: #{nonexistent_avg.round(6)}s"
  end

  test 'find_unactivated_by_valid_token returns user with valid token' do
    user = users(:test_user_not_active)
    user.create_activation_digest
    user.save!
    assert_equal user, User.find_unactivated_by_valid_token(user.email, user.activation_token)
  end

  test 'find_unactivated_by_valid_token returns nil with invalid token' do
    user = users(:test_user_not_active)
    user.create_activation_digest
    user.save!
    assert_nil User.find_unactivated_by_valid_token(user.email, 'invalid_token')
  end

  test 'find_unactivated_by_valid_token returns nil for non-existent email' do
    assert_nil User.find_unactivated_by_valid_token('nobody@example.com', 'any_token')
  end

  test 'find_unactivated_by_valid_token returns nil for already-activated user' do
    user = users(:test_user)
    assert user.activated?
    user.create_activation_digest
    user.save!
    assert_nil User.find_unactivated_by_valid_token(user.email, user.activation_token)
  end

  test 'local users can create remember tokens' do
    user = users(:test_user) # Local user
    assert_equal 'local', user.provider
    assert_nil user.remember_digest

    user.remember
    assert_not_nil user.remember_digest
    assert_not_nil user.remember_token
  end

  test 'GitHub users cannot create remember tokens' do
    github_user = users(:github_user)
    assert_equal 'github', github_user.provider
    assert_nil github_user.remember_digest

    error =
      assert_raises(ArgumentError) do
        github_user.remember
      end
    assert_equal 'GitHub users cannot use remember tokens', error.message
    assert_nil github_user.reload.remember_digest
  end

  # email_encryption_key_hex / email_blind_index_key_hex
  # These private class methods have a production branch (env_test: false) that
  # is never reached during normal test runs; we exercise it explicitly here.

  test 'email_encryption_key_hex returns test key in test mode' do
    assert_equal User::TEST_EMAIL_ENCRYPTION_KEY,
                 User.send(:email_encryption_key_hex)
  end

  test 'email_encryption_key_hex falls back to test key when env var absent' do
    saved = ENV.delete('EMAIL_ENCRYPTION_KEY')
    assert_equal User::TEST_EMAIL_ENCRYPTION_KEY,
                 User.send(:email_encryption_key_hex, env_test: false)
  ensure
    ENV['EMAIL_ENCRYPTION_KEY'] = saved if saved
  end

  test 'email_encryption_key_hex uses EMAIL_ENCRYPTION_KEY env var when set' do
    fake_key = 'a' * User::DIGITS_OF_EMAIL_ENCRYPTION_KEY
    saved = ENV.fetch('EMAIL_ENCRYPTION_KEY', nil)
    ENV['EMAIL_ENCRYPTION_KEY'] = fake_key
    assert_equal fake_key, User.send(:email_encryption_key_hex, env_test: false)
  ensure
    ENV['EMAIL_ENCRYPTION_KEY'] = saved
  end

  test 'email_blind_index_key_hex returns test key in test mode' do
    assert_equal User::TEST_EMAIL_BLIND_INDEX_KEY,
                 User.send(:email_blind_index_key_hex)
  end

  test 'email_blind_index_key_hex falls back to test key when env var absent' do
    saved = ENV.delete('EMAIL_BLIND_INDEX_KEY')
    assert_equal User::TEST_EMAIL_BLIND_INDEX_KEY,
                 User.send(:email_blind_index_key_hex, env_test: false)
  ensure
    ENV['EMAIL_BLIND_INDEX_KEY'] = saved if saved
  end

  test 'email_blind_index_key_hex uses EMAIL_BLIND_INDEX_KEY env var when set' do
    fake_key = 'b' * User::DIGITS_OF_EMAIL_BLIND_INDEX_KEY
    saved = ENV.fetch('EMAIL_BLIND_INDEX_KEY', nil)
    ENV['EMAIL_BLIND_INDEX_KEY'] = fake_key
    assert_equal fake_key, User.send(:email_blind_index_key_hex, env_test: false)
  ensure
    ENV['EMAIL_BLIND_INDEX_KEY'] = saved
  end

  # --- purge_unactivated_accounts ---

  # Build an old never-activated local user and return it after saving.
  # Bypasses the auto-timestamp so created_at is in the purgeable past.
  def old_unactivated_user(email)
    u = User.new(
      name: 'Test Bot', email: email,
      password: 'p@$$w0rd', password_confirmation: 'p@$$w0rd',
      provider: 'local', activated: false, preferred_locale: 'en'
    )
    u.save!
    u.update_column(:created_at,
                    (User::UNACTIVATED_ACCOUNT_LIFETIME + 1.day).ago)
    u
  end

  test 'purge_unactivated_accounts deletes old unactivated local accounts' do
    u = old_unactivated_user('purge-old@example.com')
    User.purge_unactivated_accounts
    assert_not User.exists?(u.id)
  end

  test 'purge_unactivated_accounts keeps recently created unactivated accounts' do
    u = User.create!(
      name: 'New Bot', email: 'purge-new@example.com',
      password: 'p@$$w0rd', password_confirmation: 'p@$$w0rd',
      provider: 'local', activated: false, preferred_locale: 'en'
    )
    User.purge_unactivated_accounts
    assert User.exists?(u.id)
  end

  test 'purge_unactivated_accounts keeps activated local accounts' do
    User.purge_unactivated_accounts
    assert User.exists?(users(:test_user).id)
  end

  test 'purge_unactivated_accounts keeps old unactivated accounts that own a project' do
    u = old_unactivated_user('purge-with-project@example.com')
    project = u.projects.build(
      name: 'Purge Test Project',
      description: 'Temporary project for purge test',
      license: 'MIT',
      homepage_url: 'https://example.com',
      repo_url: 'https://example.com/repo',
      entry_locale: 'en'
    )
    project.save!(validate: false)
    User.purge_unactivated_accounts
    assert User.exists?(u.id)
  end

  test 'purge_unactivated_accounts keeps old unactivated accounts with additional rights' do
    u = old_unactivated_user('purge-with-rights@example.com')
    AdditionalRight.create!(user_id: u.id, project_id: projects(:one).id)
    User.purge_unactivated_accounts
    assert User.exists?(u.id)
  end

  test 'purge_unactivated_accounts does not touch github accounts' do
    u = users(:github_user)
    User.purge_unactivated_accounts
    assert User.exists?(u.id)
  end
end
# rubocop:enable Metrics/ClassLength
