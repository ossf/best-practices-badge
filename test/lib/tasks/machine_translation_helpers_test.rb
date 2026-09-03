# frozen_string_literal: true

# Copyright the Linux Foundation and the
# OpenSSF Best Practices badge contributors
# SPDX-License-Identifier: MIT

require 'test_helper'
require Rails.root.join('lib/tasks/machine_translation_helpers')

# Coverage isn't required here (lib/tasks is excluded from the project's
# coverage requirement, since it's not run in production), but the pure
# helper functions below are cheap to test and worth getting right, since
# a mistake here silently degrades translation consistency rather than
# raising an error.
# rubocop:disable Metrics/ClassLength
class MachineTranslationHelpersTest < ActiveSupport::TestCase
  test 'strip_html_and_urls removes tags and full URLs' do
    text = 'See <a href="https://example.com/path?x=1">the docs</a> for HTTPS.'
    cleaned = MachineTranslationHelpers.strip_html_and_urls(text)
    assert_not_includes cleaned, '<a'
    assert_not_includes cleaned, 'href'
    assert_not_includes cleaned, 'example.com'
    assert_includes cleaned, 'the docs'
    assert_includes cleaned, 'HTTPS'
  end

  test 'tokenize_words drops short fragments and HTML/URL noise' do
    text = 'Use version control (e.g. Git) via <code>https://git-scm.com</code>.'
    words = MachineTranslationHelpers.tokenize_words(text)
    assert_includes words, 'version'
    assert_includes words, 'control'
    assert_not_includes words, 'e' # from "e.g."
    assert_not_includes words, 'code' # HTML tag name
    assert_not_includes words, 'com' # URL fragment
  end

  test 'ngram_phrases builds contiguous phrases and drops stopword phrases' do
    words = %w[the version control system]

    assert_equal %w[version control system], MachineTranslationHelpers.ngram_phrases(words, 1)
    assert_equal ['version control', 'control system'],
                 MachineTranslationHelpers.ngram_phrases(words, 2)
    # "the version control" is dropped because "the" is a stopword
    assert_equal ['version control system'], MachineTranslationHelpers.ngram_phrases(words, 3)
  end

  test 'ngram_phrases returns nothing when n exceeds the word count' do
    assert_empty MachineTranslationHelpers.ngram_phrases(%w[one two], 3)
  end

  test 'corpus_occurrences counts distinct strings, not raw occurrences' do
    english = {
      'a' => 'version control is great',
      'b' => 'we use version control here too',
      'c' => 'version control, version control, version control' # repeats in ONE string
    }
    # 3 distinct strings contain the phrase, regardless of internal repeats
    assert_equal 3, MachineTranslationHelpers.corpus_occurrences('version control', english)
    assert_equal 0, MachineTranslationHelpers.corpus_occurrences('nonexistent phrase', english)
  end

  test 'corpus_occurrences requires a whole-word match, not a substring' do
    english = {
      'a' => 'Please log in to continue.',
      'b' => 'Your login attempt failed.',
      'c' => 'You are already logged in.'
    }
    # Only "a" has "log" as its own word; "login" and "logged" must not count
    assert_equal 1, MachineTranslationHelpers.corpus_occurrences('log', english)
  end

  test 'contains_acronym? detects genuine acronyms but not ordinary capitalized words' do
    assert MachineTranslationHelpers.contains_acronym?('OR')
    assert MachineTranslationHelpers.contains_acronym?('CI/CD')
    assert MachineTranslationHelpers.contains_acronym?('SBOM format') # embedded in a phrase
    assert_not MachineTranslationHelpers.contains_acronym?('Version')
    assert_not MachineTranslationHelpers.contains_acronym?('GitHub')
    assert_not MachineTranslationHelpers.contains_acronym?('version control')
  end

  test 'corpus_occurrences matches acronyms case-sensitively, avoiding common-word collisions' do
    english = {
      'a' => 'This criterion must be met OR unmet, not both.',
      'b' => 'You can eat an apple or a pear.',
      'c' => 'She likes apples or oranges.'
    }
    # Only "a" has the emphasized acronym "OR"; the ordinary word "or" in
    # "b" and "c" must not count as a match.
    assert_equal 1, MachineTranslationHelpers.corpus_occurrences('OR', english)
  end

  test 'corpus_occurrences matches ordinary phrases case-insensitively' do
    english = {
      'a' => 'Distributed version control matters for teams.',
      'b' => 'Use version control daily.'
    }
    assert_equal 2, MachineTranslationHelpers.corpus_occurrences('version control', english)
  end

  test 'extract_recurring_ngrams finds a phrase repeated across strings' do
    english = {
      'a' => 'Our project uses distributed version control for everything.',
      'b' => 'Version control lets many people collaborate.',
      'c' => 'This sentence has nothing in common with the others.'
    }
    terms = MachineTranslationHelpers.extract_recurring_ngrams(english['a'], english)
    assert_includes terms, 'version control'
  end

  test 'extract_recurring_ngrams excludes a phrase seen only once' do
    english = {
      'a' => 'This unique phrase appears nowhere else in the corpus.',
      'b' => 'A completely unrelated sentence about something else.'
    }
    terms = MachineTranslationHelpers.extract_recurring_ngrams(english['a'], english)
    assert_not_includes terms, 'unique phrase'
  end

  test 'extract_technical_terms includes short recurring words missed by length-based heuristics' do
    english = {
      'a' => 'Every badge has a repository and a license.',
      'b' => 'The badge links to the project repository and its license.'
    }
    terms = MachineTranslationHelpers.extract_technical_terms(english.keys, english)
    assert_includes terms, 'badge'
    assert_includes terms, 'repository'
    assert_includes terms, 'license'
  end

  test 'greedy_set_cover covers every term using fewer examples than terms' do
    # "a" covers x and y in one example; "b" covers z (y is already
    # covered by "a"); "c" only covers x, so it never gets picked.
    coverage = { 'a' => %w[x y], 'b' => %w[y z], 'c' => %w[x] }
    selected = MachineTranslationHelpers.greedy_set_cover(coverage, 2)
    assert_equal %w[a b], selected.sort
  end

  test 'greedy_set_cover stops early once nothing new is covered' do
    coverage = { 'a' => %w[x], 'b' => %w[x] } # "b" covers nothing "a" didn't
    selected = MachineTranslationHelpers.greedy_set_cover(coverage, 5)
    assert_equal ['a'], selected
  end

  test 'greedy_set_cover prefers the single example covering the most terms' do
    coverage = { 'big' => %w[a b c], 'small1' => %w[a], 'small2' => %w[b] }
    selected = MachineTranslationHelpers.greedy_set_cover(coverage, 1)
    assert_equal ['big'], selected
  end

  test 'greedy_set_cover handles an empty coverage map or a zero limit' do
    assert_empty MachineTranslationHelpers.greedy_set_cover({}, 10)
    assert_empty MachineTranslationHelpers.greedy_set_cover({ 'a' => %w[x] }, 0)
  end

  test 'fill_with_touching_examples prefers leftover keys touching the most terms' do
    coverage = { 'a' => %w[x y], 'b' => %w[y z], 'c' => %w[x], 'd' => %w[x y z] }
    selected = %w[a b] # already fully covers x, y, and z
    result = MachineTranslationHelpers.fill_with_touching_examples(coverage, selected, 4)
    # "d" touches all 3 terms (most, even though redundant); "c" touches only 1
    assert_equal %w[a b d c], result
  end

  test 'fill_with_touching_examples returns selected unchanged when no budget remains' do
    coverage = { 'a' => %w[x], 'b' => %w[y] }
    selected = %w[a b]
    assert_equal selected, MachineTranslationHelpers.fill_with_touching_examples(coverage, selected, 2)
  end

  test 'human_translation_present? is false for a key present but blank' do
    # translation.io exports every tracked segment with a blank
    # placeholder until a human actually translates it, so the key
    # existing in the hash does not mean a human translation exists.
    human_translations = { 'osps_gv_02_01.description' => nil, 'osps_gv_02_01.details' => '' }
    assert_not MachineTranslationHelpers.human_translation_present?(human_translations, 'osps_gv_02_01.description')
    assert_not MachineTranslationHelpers.human_translation_present?(human_translations, 'osps_gv_02_01.details')
  end

  test 'human_translation_present? is true only for a real, non-blank value' do
    human_translations = { 'sessions.signed_in' => 'Connecte !' }
    assert MachineTranslationHelpers.human_translation_present?(human_translations, 'sessions.signed_in')
    assert_not MachineTranslationHelpers.human_translation_present?(human_translations, 'no_such_key')
  end
end
# rubocop:enable Metrics/ClassLength
