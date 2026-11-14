# frozen_string_literal: true

# Copyright the OpenSSF Best Practices badge contributors
# SPDX-License-Identifier: MIT

require 'test_helper'
require Rails.root.join(
  'db',
  'migrate',
  '20261101170000_migrate_attr_encrypted_to_rails_encryption.rb'
)

class MigrateAttrEncryptedToRailsEncryptionTest < ActiveSupport::TestCase
  test 'properly decrypts attr_encrypted email and re-encrypts with Rails encryption' do
    migration = MigrateAttrEncryptedToRailsEncryption.new
    key = [User::TEST_EMAIL_ENCRYPTION_KEY].pack('H*')
    user = users(:test_user_cs)

    decrypted = migration.decrypt_attr_encrypted_email(
      user.encrypted_email, user.encrypted_email_iv, key
    )
    assert_equal 'CaseSensitive@example.org', decrypted

    user.write_attribute(:email, nil)
    user.write_attribute(:original_email, nil)
    user.save!(touch: false, validate: false)
    assert_nil user.reload.email

    user.email = decrypted
    user.save!(touch: false, validate: false)
    user.reload

    assert_equal 'CaseSensitive@example.org', user.email
    assert_includes User.where(email: 'casesensitive@example.org'), user
    assert_includes User.where(email: 'CaseSensitive@example.org'), user
  end

  test 'migration can run repeatedly without changing ciphertext or timestamps' do
    with_migration_schema do |migration|
      migration.down
      legacy = migration.connection.select_rows(
        'SELECT id, encrypted_email, encrypted_email_iv, email_bidx, updated_at FROM users ORDER BY id'
      )
      migration.up
      first = migration.connection.select_rows('SELECT id, email, original_email FROM users ORDER BY id')
      migration.up
      assert_equal first, migration.connection.select_rows(
        'SELECT id, email, original_email FROM users ORDER BY id'
      )
      assert_equal legacy, migration.connection.select_rows(
        'SELECT id, encrypted_email, encrypted_email_iv, email_bidx, updated_at FROM users ORDER BY id'
      )
      assert_equal 'CaseSensitive@example.org', User.find(users(:test_user_cs).id).email
    end
  end

  test 'rollback preserves changed and newly created email addresses and their indexes' do
    with_migration_schema do |migration|
      changed = users(:test_user_cs)
      other_local = users(:test_user)
      swapped_email_a = other_local.email
      swapped_email_b = 'ChangedCase@example.org'
      other_local.update!(email: 'temp-swap@example.org')
      changed.update!(email: swapped_email_a)
      other_local.update!(email: swapped_email_b)
      added = User.create!(name: 'New User', email: 'NewCase@example.org', provider: 'github')
      expected = {
        changed.id => changed.email,
        other_local.id => other_local.email,
        added.id => added.email
      }
      migration.down
      migration.down
      expected.each do |id, email|
        row = migration.connection.select_one("SELECT * FROM users WHERE id = #{id}")
        assert_equal email, migration.decrypt_attr_encrypted_email(
          row['encrypted_email'], row['encrypted_email_iv'], [User::TEST_EMAIL_ENCRYPTION_KEY].pack('H*')
        )
        assert_equal BlindIndex.generate_bidx(email.downcase, key: User::TEST_EMAIL_BLIND_INDEX_KEY),
                     row['email_bidx']
      end
      migration.up
      User.reset_column_information
      expected.each do |id, email|
        assert_equal email, User.find(id).email
        assert_equal id, User.find_by(email: email.downcase).id
      end
    end
  end

  test 'migration rejects corrupted legacy ciphertext instead of losing data' do
    migration = MigrateAttrEncryptedToRailsEncryption.new
    assert_raises(OpenSSL::Cipher::CipherError) do
      migration.decrypt_attr_encrypted_email(
        users(:test_user).encrypted_email, users(:test_user).encrypted_email_iv, ['f' * 64].pack('H*')
      )
    end
  end

  private

  def with_migration_schema
    migration = MigrateAttrEncryptedToRailsEncryption.new
    ActiveRecord::Base.transaction(requires_new: true) do
      migration.suppress_messages { yield migration }
      raise ActiveRecord::Rollback
    end
  ensure
    User.reset_column_information
    MigrateAttrEncryptedToRailsEncryption::MigrationUser.reset_column_information
  end
end
