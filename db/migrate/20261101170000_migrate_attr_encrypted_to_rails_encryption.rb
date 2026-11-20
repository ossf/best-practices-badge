# frozen_string_literal: true

# Copyright the OpenSSF Best Practices badge contributors
# SPDX-License-Identifier: MIT

# Preserve the legacy columns until a separate cleanup: `up` only adds the new
# columns and copies data into them, while `down` copies data back into the
# legacy columns before removing the new ones. Both run inside PostgreSQL's
# migration transaction.
# Use a migration-local model so future User callbacks cannot affect the copy.
class MigrateAttrEncryptedToRailsEncryption < ActiveRecord::Migration[8.1]
  class MigrationUser < ActiveRecord::Base
    self.table_name = 'users'
    encrypts :email, deterministic: true, downcase: true
    encrypts :original_email
  end

  # Separate DDL keeps the column-existence guards effective on reruns.
  # rubocop:disable-next Rails/BulkChangeTable
  def up
    add_column :users, :email, :text, if_not_exists: true,
                                    comment: 'Deterministically encrypted lowercase email'
    add_column :users, :original_email, :text, if_not_exists: true,
                                             comment: 'Encrypted email preserving original case'
    add_index :users, :email, if_not_exists: true
    add_index :users, :email, name: 'email_local_unique', unique: true,
                            where: "provider = 'local'", if_not_exists: true
    copy_legacy_emails
  end

  # rubocop:disable-next Rails/BulkChangeTable
  def down
    return unless column_exists?(:users, :email)

    require 'blind_index'
    prepare_model
    # Clear stale blind indexes before rebuilding so swapped local emails
    # cannot collide with the email_local_unique_bidx partial unique index.
    # rubocop:disable-next Rails/SkipsModelValidations
    MigrationUser.update_all(email_bidx: nil)
    MigrationUser.find_each(batch_size: 400) do |user|
      # Copy data without callbacks, validations, or timestamp changes.
      # rubocop:disable-next Rails/SkipsModelValidations
      user.update_columns(legacy_attributes(user.original_email || user.email))
    end
    remove_column :users, :original_email
    remove_column :users, :email
  end

  # Copies each legacy-format email address into the new columns. Rows that
  # already have a new-format email are skipped, so this is safe to re-run;
  # `rake copy_legacy_emails` reuses it for rows written by the previous
  # release while this migration was running.
  # @return [Integer] number of rows copied
  def copy_legacy_emails
    prepare_model
    copied = 0
    MigrationUser.find_each(batch_size: 400) do |user|
      next if user.ciphertext_for(:email).present?
      next if user.encrypted_email.blank? || user.encrypted_email_iv.blank?

      email = decrypt_attr_encrypted_email(
        user.encrypted_email, user.encrypted_email_iv, encryption_key
      )
      user.email = email
      # Copy data without callbacks, validations, or timestamp changes.
      # rubocop:disable-next Rails/SkipsModelValidations
      user.update_columns(email: user.email, original_email: email)
      copied += 1
    end
    copied
  end

  def decrypt_attr_encrypted_email(encrypted_email, encrypted_email_iv, key)
    raw = Base64.decode64(encrypted_email)
    cipher = OpenSSL::Cipher.new('aes-256-gcm')
    cipher.decrypt
    cipher.key = key
    cipher.iv = Base64.decode64(encrypted_email_iv)
    cipher.auth_tag = raw[-16..]
    cipher.auth_data = ''
    cipher.update(raw[0...-16]) + cipher.final
  end

  private

  def prepare_model
    MigrationUser.reset_column_information
  end

  def encryption_key
    [key_hex('EMAIL_ENCRYPTION_KEY', '1')].pack('H*')
  end

  def key_hex(name, test_digit)
    Rails.env.test? ? (test_digit * 64) : ENV.fetch(name, test_digit * 64)
  end

  def legacy_attributes(email)
    return { encrypted_email: nil, encrypted_email_iv: nil, email_bidx: nil } if email.nil?

    cipher = OpenSSL::Cipher.new('aes-256-gcm')
    cipher.encrypt
    cipher.key = encryption_key
    iv = cipher.random_iv
    cipher.auth_data = ''
    ciphertext = cipher.update(email) + cipher.final + cipher.auth_tag
    {
      encrypted_email: Base64.encode64(ciphertext),
      encrypted_email_iv: Base64.encode64(iv),
      email_bidx: BlindIndex.generate_bidx(
        email.downcase, key: key_hex('EMAIL_BLIND_INDEX_KEY', '2')
      )
    }
  end
end
