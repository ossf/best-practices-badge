# frozen_string_literal: true

# Copyright the Linux Foundation and the
# OpenSSF Best Practices badge contributors
# SPDX-License-Identifier: MIT

# Rake tasks for machine translation workflow.
#
# These tasks help manage machine translations that fill gaps where human
# translations aren't yet available. The workflow is:
#
# 1. Export untranslated keys: rake translation:export[fr,50]
# 2. Translate that file using any tool (Copilot, ChatGPT, human, etc.)
# 3. Import the translated file: rake translation:import[fr,tmp/file.yml]
# 4. Periodically clean up: rake translation:cleanup
#
# Human translations always take precedence over machine translations.

require_relative 'machine_translation_helpers'

# rubocop:disable Metrics/BlockLength
namespace :translation do
  desc 'List untranslated keys for a locale (e.g., rake translation:untranslated[fr])'
  task :untranslated, [:locale] => :environment do |_t, args|
    locale = args[:locale] || 'fr'
    MachineTranslationHelpers.validate_locale!(locale)

    missing = MachineTranslationHelpers.find_untranslated_keys(locale)
    puts "Found #{missing.length} untranslated keys for #{locale}:"
    missing.first(20).each { |key| puts "  #{key}" }
    puts "  ... and #{missing.length - 20} more" if missing.length > 20
  end

  desc 'Export untranslated keys to YAML for translation'
  task :export, %i[locale count] => :environment do |_t, args|
    locale = args[:locale] || MachineTranslationHelpers.next_locale_needing_translation
    count = (args[:count] || 50).to_i
    MachineTranslationHelpers.validate_locale!(locale)

    missing_keys = MachineTranslationHelpers.find_untranslated_keys(locale)
    if missing_keys.empty?
      puts "No untranslated keys for #{locale}!"
      next
    end

    result = MachineTranslationHelpers.export_keys_for_translation(
      locale, missing_keys.first(count)
    )
    MachineTranslationHelpers.print_export_instructions(
      locale, result[:filepath], result[:examples], result[:instructions]
    )
  end

  desc 'Import translated YAML into machine_translations'
  task :import, %i[locale file] => :environment do |_t, args|
    locale = args[:locale]
    file = args[:file]

    unless locale && file
      puts 'Usage: rake translation:import[LOCALE,FILE]'
      puts 'Example: rake translation:import[fr,tmp/translate_to_fr_20240101.yml]'
      next
    end

    MachineTranslationHelpers.validate_locale!(locale)
    MachineTranslationHelpers.import_translations(locale, file)
  end

  desc 'Remove machine translations that have human versions'
  task cleanup: :environment do
    MachineTranslationHelpers.cleanup_machine_translations
  end

  desc 'Show translation status for all locales'
  task status: :environment do
    MachineTranslationHelpers.print_status
  end

  desc 'Run automated translation via GitHub Copilot (safe for cron/timer)'
  task :copilot, %i[locale count] => :environment do |_t, args|
    unless MachineTranslationHelpers.acquire_copilot_lock
      puts 'Another Copilot translation is in progress. Skipping.'
      next
    end

    begin
      locale = args[:locale] || MachineTranslationHelpers.next_locale_needing_translation
      count = (args[:count] || MachineTranslationHelpers::COPILOT_BATCH_SIZE).to_i
      MachineTranslationHelpers.validate_locale!(locale)

      result = MachineTranslationHelpers.run_copilot_translation(locale, batch_size: count)

      if result[:success]
        puts "Successfully translated #{result[:translated]} keys for #{result[:locale]}"
        MachineTranslationHelpers.print_status
      else
        puts 'Translation failed. Check logs for details.'
        exit 1
      end
    ensure
      MachineTranslationHelpers.release_copilot_lock
    end
  end

  desc 'Translate all missing/obsolete segments in all locales (runs until complete)'
  task :all, [:batch_size] => :environment do |_t, args|
    batch_size = (args[:batch_size] || MachineTranslationHelpers::COPILOT_BATCH_SIZE).to_i
    wait_time = 10 # Seconds to wait between batches

    puts 'Starting automated machine translation for all locales...'
    puts '(this provides machine translations for missing segments and'
    puts 'segments that have machine translations but the English has changed)'
    puts "Batch size: #{batch_size}, Wait time: #{wait_time} seconds (#{wait_time / 60} minutes)"
    puts

    iteration = 0
    consecutive_failures = 0
    max_consecutive_failures = 10

    loop do
      iteration += 1
      puts "=== Iteration #{iteration} at #{Time.zone.now.strftime('%Y-%m-%d %H:%M:%S')} ==="

      # Find next locale that needs translation
      locale = MachineTranslationHelpers.next_locale_needing_translation
      missing_keys = MachineTranslationHelpers.find_untranslated_keys(locale)

      if missing_keys.empty?
        puts 'All strings have been translated across all locales!'
        puts 'Final status:'
        MachineTranslationHelpers.print_status
        break
      end

      puts "Found #{missing_keys.length} untranslated keys for #{MachineTranslationHelpers.language_name(locale)}"

      # Store count before translation attempt
      before_count = missing_keys.length

      # Run translation for this locale, catching any exit/failure
      puts "Translating batch of #{[batch_size, missing_keys.length].min} keys..."
      begin
        Rake::Task['translation:copilot'].reenable # Allow task to be called again
        Rake::Task['translation:copilot'].invoke(locale, batch_size)
      rescue SystemExit => e
        # Copilot task exited with error - log it but continue
        puts "Copilot task exited with status #{e.status} - continuing anyway..."
      end

      # Check if we made progress (even partial success counts)
      after_count = MachineTranslationHelpers.find_untranslated_keys(locale).length
      if after_count < before_count
        consecutive_failures = 0
        puts "Progress: #{before_count - after_count} keys translated successfully"
      else
        consecutive_failures += 1
        puts "No progress made (failure #{consecutive_failures}/#{max_consecutive_failures})"

        if consecutive_failures >= max_consecutive_failures
          puts ''
          puts "ERROR: #{max_consecutive_failures} consecutive failures with no progress."
          puts 'Stopping to prevent infinite loop. Manual intervention may be needed.'
          break
        end
      end

      # Wait before next iteration (unless we're done)
      remaining = MachineTranslationHelpers.find_untranslated_keys(locale)
      next if remaining.empty?

      puts
      puts "Waiting #{wait_time} seconds before next batch..."
      sleep wait_time
    end

    puts
    puts "Completed #{iteration} iterations."
  end
end
# rubocop:enable Metrics/BlockLength
