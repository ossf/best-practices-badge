# frozen_string_literal: true

# Copyright the Linux Foundation and the
# OpenSSF Best Practices badge contributors
# SPDX-License-Identifier: MIT

# Adds column and table comments to document non-obvious schema conventions.
# Comments appear in both schema.rb (readable by developers and AI) and in
# the database (readable by schema-aware tools). Topics covered: the _status
# integer encoding, the two legacy string-typed URL status fields that predate
# it, tiered percentage composite fields, badge achievement timestamps
# (most-recent vs. first-ever), first-edit automation flags,
# pending-notification counters, and encrypted email fields on users.
class AddSchemaComments < ActiveRecord::Migration[8.1]
  STATUS_ENCODING = '0=unknown(?), 1=unmet, 2=N/A, 3=met'

  TIERED_PCT_COMMENT =
    '<100 = in_progress (value = % toward passing); ' \
    '100-199 = passing (value-100 = % toward silver); ' \
    '200-299 = silver (value-200 = % toward gold); ' \
    '300 = gold'

  BASELINE_TIERED_PCT_COMMENT =
    '<100 = in_progress (value = % toward baseline-1); ' \
    '100-199 = baseline-1 (value-100 = % toward baseline-2); ' \
    '200-299 = baseline-2 (value-200 = % toward baseline-3); ' \
    '300 = baseline-3 (same encoding as tiered_percentage)'

  # Original comment on baseline_tiered_percentage before this migration
  OLD_BASELINE_TIERED_PCT_COMMENT = 'Tiered percentage for baseline series (0-300)'

  # rubocop:disable Metrics/MethodLength
  def up
    change_table_comment :projects,
                         "Best practices criteria results. Integer _status columns: #{STATUS_ENCODING}. " \
                         'Paired _justification text columns hold free-text explanations.'

    # These two URL fields predate the integer _status convention and use
    # a string type with "?" as the default instead.
    change_column_comment :projects, :homepage_url_status,
                          "String (legacy URL field, not the integer enum); '?' = unknown/not evaluated"
    change_column_comment :projects, :report_url_status,
                          "String (legacy URL field, not the integer enum); '?' = unknown/not evaluated"

    # Completion percentages per badge level (0-100 each)
    change_column_comment :projects, :badge_percentage_0,
                          'Completion percentage (0-100) toward passing badge'
    change_column_comment :projects, :badge_percentage_1,
                          'Completion percentage (0-100) toward silver badge'
    change_column_comment :projects, :badge_percentage_2,
                          'Completion percentage (0-100) toward gold badge'
    change_column_comment :projects, :badge_percentage_baseline_1,
                          'Completion percentage (0-100) toward baseline-1 badge'
    change_column_comment :projects, :badge_percentage_baseline_2,
                          'Completion percentage (0-100) toward baseline-2 badge'
    change_column_comment :projects, :badge_percentage_baseline_3,
                          'Completion percentage (0-100) toward baseline-3 badge'

    # Composite tiered percentages (0-300, combining all levels into one field)
    change_column_comment :projects, :tiered_percentage, TIERED_PCT_COMMENT
    change_column_comment :projects, :baseline_tiered_percentage,
                          BASELINE_TIERED_PCT_COMMENT

    # Most-recently-achieved timestamps (NOT reset when a badge is subsequently lost;
    # compare lost_*_at to determine whether the badge is currently held)
    change_column_comment :projects, :achieved_passing_at,
                          'Most recently achieved passing; not cleared on loss (compare lost_passing_at)'
    change_column_comment :projects, :achieved_silver_at,
                          'Most recently achieved silver; not cleared on loss (compare lost_silver_at)'
    change_column_comment :projects, :achieved_gold_at,
                          'Most recently achieved gold; not cleared on loss (compare lost_gold_at)'
    change_column_comment :projects, :achieved_baseline_1_at,
                          'Most recently achieved baseline-1; not cleared on loss'
    change_column_comment :projects, :achieved_baseline_2_at,
                          'Most recently achieved baseline-2; not cleared on loss'
    change_column_comment :projects, :achieved_baseline_3_at,
                          'Most recently achieved baseline-3; not cleared on loss'

    # First-ever achievement timestamps (set once, never reset)
    change_column_comment :projects, :first_achieved_passing_at,
                          'First time ever passing was achieved; never reset after badge loss'
    change_column_comment :projects, :first_achieved_silver_at,
                          'First time ever silver was achieved; never reset after badge loss'
    change_column_comment :projects, :first_achieved_gold_at,
                          'First time ever gold was achieved; never reset after badge loss'

    # True once a user has edited each level for the first time.
    # Controls whether first-edit automation (Chief) runs on next save.
    change_column_comment :projects, :passing_saved,
                          'True after first form edit of passing criteria; gates first-edit automation'
    change_column_comment :projects, :silver_saved,
                          'True after first form edit of silver criteria; gates first-edit automation'
    change_column_comment :projects, :gold_saved,
                          'True after first form edit of gold criteria; gates first-edit automation'
    change_column_comment :projects, :baseline_1_saved,
                          'True after first form edit of baseline-1 criteria; gates first-edit automation'
    change_column_comment :projects, :baseline_2_saved,
                          'True after first form edit of baseline-2 criteria; gates first-edit automation'
    change_column_comment :projects, :baseline_3_saved,
                          'True after first form edit of baseline-3 criteria; gates first-edit automation'

    # Pending email notification counters.
    # Non-zero means an email has not yet been sent.
    # Metal levels: BADGE_LEVELS = ['in_progress','passing','silver','gold']
    # Baseline levels: BASELINE_BADGE_LEVELS = ['in_progress','baseline-1',...]
    change_column_comment :projects, :unreported_badge_loss,
                          'BADGE_LEVELS index of lost metal badge level pending notification email; 0=nothing pending'
    change_column_comment :projects, :unreported_badge_warning,
                          'BADGE_LEVELS index of at-risk metal badge level pending warning email; 0=nothing pending'
    change_column_comment :projects, :unreported_baseline_badge_loss,
                          'BASELINE_BADGE_LEVELS index of lost baseline badge level pending notification email; 0=nothing pending'
    change_column_comment :projects, :unreported_baseline_badge_warning,
                          'BASELINE_BADGE_LEVELS index of at-risk baseline badge level pending warning email; 0=nothing pending'

    change_column_comment :projects, :badge_warning_effective_date,
                          'Date when pending criteria changes take effect (i.e., when the badge will be lost)'

    change_column_comment :projects, :cpe,
                          'Common Platform Enumeration identifier for NVD vulnerability tracking'
    change_column_comment :projects, :lock_version,
                          'Rails optimistic locking column; incremented on each update to detect concurrent edits'

    # Users: encrypted email storage and lookup
    change_column_comment :users, :encrypted_email,
                          'AES-256-GCM encrypted email address'
    change_column_comment :users, :encrypted_email_iv,
                          'Initialization vector (IV) for AES-256-GCM email encryption'
    change_column_comment :users, :email_bidx,
                          'HMAC blind index for encrypted-email lookup without decrypting'

    # Users: authentication fields
    change_column_comment :users, :provider,
                          "'local' for password-based accounts; OAuth provider name (e.g., 'github') for OAuth accounts"
    change_column_comment :users, :uid,
                          "OAuth provider's unique user ID; blank for local (password-based) accounts"
    change_column_comment :users, :role,
                          "'admin' for administrators; blank/nil for normal users"
  end
  # rubocop:enable Metrics/MethodLength

  # rubocop:disable Metrics/MethodLength
  def down
    change_table_comment :projects, nil

    change_column_comment :projects, :homepage_url_status, nil
    change_column_comment :projects, :report_url_status, nil
    change_column_comment :projects, :badge_percentage_0, nil
    change_column_comment :projects, :badge_percentage_1, nil
    change_column_comment :projects, :badge_percentage_2, nil
    change_column_comment :projects, :badge_percentage_baseline_1, nil
    change_column_comment :projects, :badge_percentage_baseline_2, nil
    change_column_comment :projects, :badge_percentage_baseline_3, nil
    change_column_comment :projects, :tiered_percentage, nil
    # Restore original comment rather than removing it entirely
    change_column_comment :projects, :baseline_tiered_percentage,
                          OLD_BASELINE_TIERED_PCT_COMMENT
    change_column_comment :projects, :achieved_passing_at, nil
    change_column_comment :projects, :achieved_silver_at, nil
    change_column_comment :projects, :achieved_gold_at, nil
    change_column_comment :projects, :achieved_baseline_1_at, nil
    change_column_comment :projects, :achieved_baseline_2_at, nil
    change_column_comment :projects, :achieved_baseline_3_at, nil
    change_column_comment :projects, :first_achieved_passing_at, nil
    change_column_comment :projects, :first_achieved_silver_at, nil
    change_column_comment :projects, :first_achieved_gold_at, nil
    change_column_comment :projects, :passing_saved, nil
    change_column_comment :projects, :silver_saved, nil
    change_column_comment :projects, :gold_saved, nil
    change_column_comment :projects, :baseline_1_saved, nil
    change_column_comment :projects, :baseline_2_saved, nil
    change_column_comment :projects, :baseline_3_saved, nil
    change_column_comment :projects, :unreported_badge_loss, nil
    change_column_comment :projects, :unreported_badge_warning, nil
    change_column_comment :projects, :unreported_baseline_badge_loss, nil
    change_column_comment :projects, :unreported_baseline_badge_warning, nil
    change_column_comment :projects, :badge_warning_effective_date, nil
    change_column_comment :projects, :cpe, nil
    change_column_comment :projects, :lock_version, nil

    change_column_comment :users, :encrypted_email, nil
    change_column_comment :users, :encrypted_email_iv, nil
    change_column_comment :users, :email_bidx, nil
    change_column_comment :users, :provider, nil
    change_column_comment :users, :uid, nil
    change_column_comment :users, :role, nil
  end
  # rubocop:enable Metrics/MethodLength
end
