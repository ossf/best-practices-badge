# frozen_string_literal: true

# Copyright the Linux Foundation and the
# OpenSSF Best Practices badge contributors
# SPDX-License-Identifier: MIT

# A stashed form submission from a logged-out submitter, awaiting re-login.
# See docs/login-session-implementation.md section 15 for the full design,
# and docs/login-session-18.md step 18 for why this is looked up by a
# random token's HMAC digest rather than its own primary key: mirrors
# LoginSession (app/models/login_session.rb) exactly, for the same reason.
# A SECRET_KEY_BASE leak alone must not be enough to forge a working
# identifier for someone else's row.
class PendingResubmission < ApplicationRecord
  extend HexKeyManagement

  DIGITS_OF_PENDING_RESUBMISSION_HMAC_KEY = 256 / 8 * 2 # 256-bit HMAC key in hex

  # For tests. '4' is unused by the three existing test keys ('1' and '2'
  # are User's, '3' is LoginSession's), so a copy-paste error between them
  # is easy to spot.
  TEST_PENDING_RESUBMISSION_HMAC_KEY = '4' * DIGITS_OF_PENDING_RESUBMISSION_HMAC_KEY

  # The raw random token, set only right after #stash_for and never
  # persisted (there is no raw-token column, only hashed_random_id).
  # Exists so a caller that just created a row gets both the row and the
  # cookie value from one call, instead of creating a row and then
  # querying it back.
  attr_reader :raw_token

  # Raw HMAC key bytes, computed once at class-load (see
  # HexKeyManagement#hex_key: findings #8 and #9).
  PENDING_RESUBMISSION_HMAC_KEY = hex_key(
    env_var: 'PENDING_RESUBMISSION_HMAC_KEY', test_value: TEST_PENDING_RESUBMISSION_HMAC_KEY
  )

  def self.digest(token)
    OpenSSL::HMAC.hexdigest('SHA256', PENDING_RESUBMISSION_HMAC_KEY, token)
  end

  # @param resubmit_path [String] path to resubmit the stashed fields to
  # @param resubmit_method [String] HTTP method to resubmit with
  # @param params_json [String] stashed fields, JSON-encoded
  # @param sensitive_fields_dropped [Boolean] true if a password/email
  #   field was excluded from params_json
  # @return [PendingResubmission] the created row; #raw_token holds the
  #   raw token to store in the client's cookie
  def self.stash_for(resubmit_path:, resubmit_method:, params_json:, sensitive_fields_dropped:)
    token = SecureRandom.urlsafe_base64 # reuse User.new_token's shape; own
    # call since this class has no User dependency to reach that through.
    pending = create!(
      resubmit_path: resubmit_path,
      resubmit_method: resubmit_method,
      params_json: params_json,
      sensitive_fields_dropped: sensitive_fields_dropped,
      hashed_random_id: digest(token)
    )
    pending.instance_variable_set(:@raw_token, token)
    pending
  end

  # @param token [String, nil] the raw token from the cookie
  # @return [PendingResubmission, nil] the matching row, or nil if not found
  def self.find_by_token(token)
    return if token.blank?

    find_by(hashed_random_id: digest(token))
  end

  # How long an unconsumed stash is kept around before the daily purge task
  # (lib/tasks/default.rake's `daily` task) deletes it. Nothing else destroys
  # a row anymore (docs/login-session-evaluation.md finding #4: destroying it as soon as
  # PendingResubmissionsController#show renders lost the stash for good if
  # the browser never actually completed the resubmission, e.g. a closed
  # tab); ApplicationController#finalize_pending_resubmission only destroys
  # a row once the browser actually resubmits it and that resubmission's
  # save succeeds. Kept at the original 3
  # days (not shortened to 1, despite there no longer being an earlier
  # natural cleanup point) so a brief outage of the daily task itself, or
  # of the site, doesn't purge someone's still-unresumed edit out from
  # under them.
  STALE_LIFETIME = 3.days

  # @return [Integer] the number of stale rows deleted
  def self.purge_stale
    where(created_at: ...STALE_LIFETIME.ago).delete_all
  end
end
