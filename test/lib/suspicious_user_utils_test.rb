# frozen_string_literal: true

# Copyright the OpenSSF Best Practices badge contributors
# SPDX-License-Identifier: MIT

require 'test_helper'

class SuspiciousUserUtilsTest < ActiveSupport::TestCase
  test 'suspicious_email? identifies random-looking emails' do
    assert_not SuspiciousUserUtils.suspicious_email?('good@example.com')
    assert_not SuspiciousUserUtils.suspicious_email?('CANNOT_DECRYPT')
    assert_not SuspiciousUserUtils.suspicious_email?('a.b.c@example.com')
    assert SuspiciousUserUtils.suspicious_email?('a.b.c.d@example.com')
    assert SuspiciousUserUtils.suspicious_email?('foo.bar.baz.qux@example.com')
  end

  test 'name_suspicion_reasons handles legitimate names' do
    assert_empty SuspiciousUserUtils.name_suspicion_reasons('David A. Wheeler')
    assert_empty SuspiciousUserUtils.name_suspicion_reasons('Javier Vázquez')
    # Length <= 6 (letters) is too short to determine suspicious signals
    assert_empty SuspiciousUserUtils.name_suspicion_reasons('Short')
  end

  test 'name_suspicion_reasons identifies low vowel ratio' do
    reasons = SuspiciousUserUtils.name_suspicion_reasons('bcdfghjklmnp')
    assert_includes reasons, 'low_vowels'
  end

  test 'name_suspicion_reasons identifies consonant runs' do
    # "Kpwqxz" has 6 consonants in a row
    reasons = SuspiciousUserUtils.name_suspicion_reasons('Kpwqxz Name')
    assert_includes reasons, 'consonant_run'
  end

  test 'name_suspicion_reasons identifies rare letters' do
    # Skip capitalized first letters, then check rare letters (qxzj)
    # "xzj" is 3/3 = 100% rare letters
    reasons = SuspiciousUserUtils.name_suspicion_reasons('Xxzj Xxzj')
    assert_includes reasons, 'rare_letters'
  end

  test 'name_suspicion_reasons ignores non-Latin script' do
    # Should return empty array early if non-Latin script is detected
    assert_empty SuspiciousUserUtils.name_suspicion_reasons('Иван Иванов')
  end
end
