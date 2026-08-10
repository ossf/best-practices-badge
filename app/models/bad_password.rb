# frozen_string_literal: true

# Copyright the OpenSSF Best Practices badge contributors
# SPDX-License-Identifier: MIT

# This is a simple list of HMAC (keyed cryptographically hashed) records with
# column "forbidden_hash" of all "lowercased known bad passwords".
# There's not much to it; ActiveRecord handles quickly seeing if it exists.

# In *production*, make sure you set 'BADGEAPP_BADPWKEY' to a secret key
# and initialize this database table.
# You can (re)initialize this database table at any time by running:
# rake update_bad_password_db

class BadPassword < ApplicationRecord
  # Should we do the bad password lookups?
  # We will do a lookup in the test environment *or* if the log level
  # is not debug log level (level 0).
  # The ||= is because Rails reloads. It's okay if it recalculates this
  # twice if it's false, it'll produce the same result each time.
  DO_LOOKUPS ||= Rails.env.test? || (Rails.logger.level != 0)

  # Provide warning if we are NOT actually doing the bad password lookups.
  # We want to make sure we avoid logging those lookups, by not doing them,
  # but we want to warn that it's happening.
  Rails.logger.info('Bad password lookups disabled') unless DO_LOOKUPS

  # Use this key in HMAC to encrypt and cryptographically hash
  # the 'bad passwords' and any password used to
  # compare them. As a result, at runtime the database only sees HMACs
  # of passwords, never passwords, when comparing to the bad password table.
  # This isn't necessary for security; passwords are only
  # *stored* in bcrypt format. However, if an attacker manages to read
  # communication lines from the app to the *running* database system,
  # or control the running database system itself,
  # this measure will ensure that the attacker never gets
  # access to unencrypted passwords.
  # In an effort to be max-hard on
  # attackers, we'll use a keyed cryptographic hash, and whine when we don't
  # get a key. Then an attacker can only get a keyed HMAC, even if
  # they can see the database communication in real time (including via a
  # log of SQL queries). Even a rainbow table won't help if the key isn't known.
  # We *allow* execution with a known key, because that way we can run tests
  # or do interactive development without having to rebuild the database
  # each time.
  # We use SHA-512, so 128 bytes (512 bits) of key is recommended.
  # Here's one way to create a key: openssl rand -hex 128
  DEFAULT_BADPWKEY ||= 'a5' * 128 # For testing and development
  BADPWKEY ||= ENV['BADGEAPP_BADPWKEY'] || DEFAULT_BADPWKEY
  Rails.logger.info('BADGEAPP_BADPWKEY unset') if BADPWKEY == DEFAULT_BADPWKEY
  BADPWKEY_BYTES ||= [BADPWKEY].pack('H*')

  # Returns HMAC-SHA512 hash of the given password using the configured key.
  # @param pw [String] the password to hash
  # @return [String] hexadecimal representation of the HMAC hash
  def self.hash_password(pw)
    OpenSSL::HMAC.hexdigest('SHA512', BADPWKEY_BYTES, pw)
  end

  # Loads bad passwords from compressed file and returns array of hashed records.
  # @param max [Integer, nil] maximum number of passwords to load, nil for all
  # @return [Array<Hash>] array of hashes with :forbidden_hash keys
  # rubocop:disable Metrics/MethodLength
  def self.bad_passwords_from_file(max = nil)
    require 'zlib'
    bad_password_array = []
    count = 0
    Zlib::GzipReader.open('raw-bad-passwords-lowercase.txt.gz') do |gz|
      gz.each_line do |line|
        pw = line.chomp.downcase.freeze
        hashed_pw = hash_password(pw)
        bad_password_array.push({ forbidden_hash: hashed_pw })
        count += 1
        break unless max.nil? || count < max
      end
    end
    bad_password_array
  end
  # rubocop:enable Metrics/MethodLength

  # Forces reload of bad password database from file.
  # Deletes all existing records and loads fresh data from file.
  # @param max [Integer, nil] maximum number of passwords to load for testing
  # @return [void]
  def self.force_load(max = nil)
    BadPassword.delete_all
    bad_password_array = bad_passwords_from_file(max)
    # Bulk insert all records in a single SQL statement for performance
    # rubocop:disable Rails/SkipsModelValidations
    BadPassword.insert_all!(bad_password_array) # No validations to skip
    # rubocop:enable Rails/SkipsModelValidations
  end

  # Check if a password exists in the "bad password" database.
  # It will only execute the database check if we should do lookups at all
  # (because they won't be logged), otherwise it always returns false.
  # This presents exposure of password-related info in logs. Even if the
  # information was logged, it only exposes keyed HMAC hashes,
  # so even SQL query logs don't reveal actual passwords, but we're
  # being extra-cautions.
  #
  # I originally wanted to use Rails.logger.silence to do this.
  # However, there is no clear evidence that `Rails.logger.silence` is
  # thread-safe, and much evidence it isn't. Simply disabling logging of the
  # global logging object is *not* okay, because that would
  # sometimes disable logging of other events.
  # It's better to not check for bad passwords to ensure *no* password
  # is ever exposed.
  #
  # @param pw [String] the password to check
  # @return [Boolean] true if password is found in bad password database
  def self.unlogged_exists?(pw)
    pw_hash = hash_password(pw.downcase)
    DO_LOOKUPS && exists?(forbidden_hash: pw_hash)
  end
end
