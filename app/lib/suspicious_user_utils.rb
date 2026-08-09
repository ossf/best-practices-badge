# frozen_string_literal: true

# Copyright the OpenSSF Best Practices badge contributors
# SPDX-License-Identifier: MIT

# SuspiciousUserUtils - logic for identifying potentially suspicious
# activated users based on their name and email patterns.
module SuspiciousUserUtils
  module_function

  # Vowels including common accented Latin forms (U+0000-U+024F range).
  LATIN_VOWELS = /[aeiouyáéíóúàèìòùâêîôûäëïöüãõåæœ]/i
  # Characters outside Basic Latin + Latin Extended-A/B: flag as non-Latin script.
  NON_LATIN_SCRIPT = /[^ -ɏ]/

  # Returns true if the email string looks suspicious (e.g. many short segments).
  def suspicious_email?(email)
    return false if email == 'CANNOT_DECRYPT'

    local = email.split('@').first.to_s
    local.split('.').count { |seg| seg.length <= 3 } >= 4
  end

  # Returns an array of reasons why the name string looks suspicious.
  # Returns an empty array if the name looks legitimate.
  # rubocop:disable Metrics/MethodLength, Metrics/AbcSize
  def name_suspicion_reasons(name)
    return [] if name.match?(NON_LATIN_SCRIPT)

    letters = name.downcase.gsub(/[^a-záéíóúàèìòùâêîôûäëïöüãõåæœ]/, '')
    return [] if letters.length <= 6

    reasons = []
    vowels = letters.scan(LATIN_VOWELS).length
    reasons << 'low_vowels' if vowels.to_f / letters.length < 0.15

    # Check each word separately so spaces don't create artificial consonant
    # runs across word boundaries (e.g. "Scott R. Shinn" → "ttrsh").
    consonant_run =
      name.downcase.split.any? do |word|
        word.gsub(/[^a-záéíóúàèìòùâêîôûäëïöüãõåæœ]/i, '')
            .match?(/[^aeiouyáéíóúàèìòùâêîôûäëïöüãõåæœ]{5}/i)
      end
    reasons << 'consonant_run' if consonant_run

    # Skip capitalised first letters before checking rare letters — they are
    # conventional in proper names (Javier, Vázquez) and not a randomness signal.
    inner = name.split
                .map { |w| w.match?(/\A[[:upper:]]/) ? w[1..] : w }
                .join.downcase.gsub(/[^a-záéíóúàèìòùâêîôûäëïöüãõåæœ]/, '')
    rare = inner.scan(/[qxzj]/).length
    reasons << 'rare_letters' if inner.length >= 4 &&
                                 rare.to_f / inner.length >= 0.35
    reasons
  end
  # rubocop:enable Metrics/MethodLength, Metrics/AbcSize
end
