# frozen_string_literal: true

# Copyright the Linux Foundation and the
# OpenSSF Best Practices badge contributors
# SPDX-License-Identifier: MIT

# Template for translation instructions
module TranslationInstructionsTemplate
  # We need to disable FormatStringToken, because our instructions will
  # specifically discuss show such tokens as examples.
  # rubocop:disable Metrics/MethodLength, Style/FormatStringToken
  def self.generate(locale:, lang:, examples: nil)
    examples_text =
      if examples
        en_file = File.basename(examples[:en_filepath])
        locale_file = File.basename(examples[:locale_filepath])
        "\nTRANSLATION EXAMPLES:\n" \
          "- English: #{en_file}\n" \
          "- #{lang}: #{locale_file}\n" \
          "(#{examples[:term_count]} technical terms with existing translations)\n"
      else
        ''
      end

    <<~INSTRUCTIONS
      TRANSLATION INSTRUCTIONS FOR #{lang.upcase}
      ========================================

      Project: OpenSSF Best Practices Badge
      Target: #{lang} (#{locale})
      #{examples_text}
      FILE FORMAT:
      - Source file has 'en:' as root key with English values (DO NOT MODIFY)
      - Target/output file must have '#{locale}:' as root key
      - Translate all VALUES to #{lang}
      - Keep all keys unchanged (in English) in the output file
      - Write translations to the TARGET (output) file, not the source file
      - The target (output) file already exists with empty strings,
        you need to replace the empty content with your translations


      CRITICAL RULES:
      1. Change root YAML key from 'en:' to '#{locale}:'
      2. Only translate VALUES, never YAML keys
      3. Keep %{variable} placeholders EXACTLY as-is
      4. Keep ALL HTML tags UNCHANGED - every <tag>, </tag>, and <tag/> from English MUST appear in translation
      5. Change /en/ paths to /#{locale}/ in URLs
      6. Preserve YAML structure (same nesting, keys, indentation)
      7. Translate pluralization (zero/one/few/many/other) appropriately
      8. Don't translate proper names (GitHub, OpenSSF, etc.)
      9. The translation must not be blank unlesss the source is blank

      YAML FORMATTING (CRITICAL - YAML errors cause COMPLETE FAILURE):
      - **ALWAYS** wrap ALL string values in DOUBLE QUOTES
      - This applies to EVERY value, even if the English source uses single quotes
      - Correct:   key: "translated value here"
      - WRONG:     key: translated value here

      **ESCAPE INTERNAL DOUBLE QUOTES** (VERY IMPORTANT):
      - If your translation contains double quotes inside the text, ESCAPE them as \\"
      - English source: 'The term "best" means...'
      - CORRECT:  key: "The term \\"best\\" means..."
      - WRONG:    key: "The term "best" means..."  (BREAKS YAML!)
      - This includes quotation marks around terms, definitions, titles, etc.

      WHY QUOTING IS MANDATORY:
      - URLs contain colons (https://...) which break unquoted YAML
      - HTML attributes contain colons and special characters
      - Chinese/Japanese punctuation can confuse YAML parsers
      - Unescaped internal quotes terminate the string prematurely
      - Example of FAILURE: key: "<p>The "term" means</p>"
      - Example of SUCCESS: key: "<p>The \\"term\\" means</p>"

      HTML TAG EXAMPLES:
      English:  "Read the <strong>documentation</strong> for <em>details</em>"
      Correct (for German):  "Lesen Sie die <strong>Dokumentation</strong> für <em>Details</em>"
      WRONG:    "Lesen Sie die Dokumentation für Details"  (missing an HTML tag - WILL FAIL VALIDATION)

      VALIDATION:
      Your translation will be validated for:
      - Correct keys, preserved placeholders, valid YAML
      - **HTML tags preserved** - missing tags will cause REJECTION
      - URL count matches

      WORKFLOW:
      1. Review examples (if provided) to understand style
      2. Read the source file (English text)
      3. Write translations to the TARGET file with '#{locale}:' as root key
      4. Translate values accurately and naturally for #{lang}
      5. Review all your translations, once created, to ensure accuracy, clarity, and naturalness for #{lang} (fixing as needed).

      We can later import them with rake translation:import[#{locale},PATH]
    INSTRUCTIONS
  end
  # rubocop:enable Metrics/MethodLength, Style/FormatStringToken
end
