# Translations

This document describes how human-generated translations are managed for the
OpenSSF Best Practices Badge application.

We use both human-generated and machine-generated translations.
Where available, the human-generated translations are used, otherwise
we use machine-generated translations so there's always a translation available.
The machine-generated translations are heavily guided by our
human-generated translations.
For details on that, see the document on
[machine-generated translations](./machine-translations.md).

## TL;DR

If you *maintain* this system's translations:

* `git checkout main` - start in the main branch
* `git pull` - make sure you're current
* `rake translation:sync` to get human translations and let the humans know
  what's new to be translated
* `translation:all` to create machine translations of everything not already
  translated by humans, using the existing human translations as a
  template/model. The machine translations will be used when we don't have
  human translations.
* `git checkout -b update_YYYY_MM_DD` - create a new branch
* `git commit -asv` - Record all changes
* `git push` - push translations, if they work, merge them in

## Overview

The application supports multiple languages. English (`en`) is the source
language, with translations available for (sorted in English alphabetic order):

- Chinese Simplified (`zh-CN`)
- French (`fr`)
- German (`de`)
- Japanese (`ja`)
- Portuguese Brazilian (`pt-BR`)
- Russian (`ru`)
- Spanish (`es`)
- Swahili (`sw`)

Other natural languages can be added.

Translations come from two sources:

1. **Human translations** - Primary source, provided via translation.io
2. **Machine translations** - Fill gaps where human translations don't exist

Current human translations always take precedence over machine translations.

## Human Translations

Human translations are managed through [translation.io](https://translation.io).
Translators use the translation.io web interface to provide translations.

**Files:**

- `config/locales/en.yml` - English source text
- `config/locales/translation.*.yml` - Human translations from translation.io

**Syncing translations:**

```bash
rake translation:sync
```

This sends updated English text to translation.io and retrieves
any new human translations.

## Machine Translations

Machine translations provide fallback text when human translations
aren't available. They're stored separately and automatically
overridden when humans provide translations.

**Files:**

- `config/machine_translations/*.yml` - Machine-translated text
- `config/machine_translations/src_en_*.yml` - Source tracking files

**Source Tracking:**

The `src_en_*.yml` files track the English text that was used to create
each machine translation. When English source text changes, the system
automatically detects this and marks those translations for re-translation.
These files must be committed to the repository.

Example:

- `config/machine_translations/fr.yml` - French translations
- `config/machine_translations/src_en_fr.yml` - English source used for French

If a key in `en.yml` changes but the tracked source in `src_en_fr.yml`
is different, the system knows the French translation is stale and needs
updating. Human translations always take precedence and are never
automatically invalidated.

### Example-Based Translation

When automated translation is performed using Copilot, the system
automatically provides example translations to help maintain consistent
terminology across the application.

**How It Works:**

1. **Term Extraction**: The system identifies technical terms in the text
   to be translated:
   - Acronyms (MFA, CI/CD, VCS)
   - Proper nouns (GitHub, OpenSSF, Scorecard)
   - Technical compounds (multi-factor, version-control)
   - Long technical words (authentication, vulnerability)

2. **Example Selection**: For each identified term, the system finds existing
   human translations containing that term and includes them as examples
   (limited to 15 examples to avoid overwhelming the AI).

3. **Example Files**: Creates two example YAML files:
   - `copilot_examples_en_*.yml` - English source with technical terms
   - `copilot_examples_{locale}_*.yml` - How those terms were previously translated

4. **Prompt Integration**: The translation prompt instructs the AI to review
   these examples and use the same translations for the same terms.

This ensures consistency in terminology across the application without
requiring manual glossary maintenance.

### How Precedence Works

Rails I18n loads translation files in order, with later files overriding
earlier ones. Machine translations are loaded first, then human translations,
so human translations always win:

1. Load `config/machine_translations/*.yml` (machine translations)
2. Load `config/locales/*.yml` (human translations override)

### Rake Tasks

#### Show translation status

```bash
rake translation:status
```

Shows how many keys have human translations, machine translations,
or are missing for each locale.

#### Export keys for translation

```bash
rake translation:export[LOCALE,COUNT]
```

Exports untranslated keys to a YAML file for translation.

Examples:

```bash
rake translation:export[fr,50]      # Export 50 French keys
rake translation:export[de,100]     # Export 100 German keys
rake translation:export             # Export 50 keys for next priority locale
```

The exported file is saved to `tmp/translate_to_LOCALE_TIMESTAMP.yml`.

#### Import translated file

```bash
rake translation:import[LOCALE,FILE]
```

Imports a translated YAML file into machine translations.

**Key Validation:** The import process validates that all keys in the
translated file exist in the English source. Any unexpected keys
(e.g., hallucinated keys from AI translation) are automatically removed
and logged. Missing keys are acceptable (translator may skip some).

Example:

```bash
rake translation:import[fr,tmp/translate_to_fr_20240101_120000.yml]
```

#### Clean up machine translations

```bash
rake translation:cleanup
```

Removes machine translations for keys that now have human translations.
Run this periodically after `rake translation:sync`.

#### List untranslated keys

```bash
rake translation:untranslated[LOCALE]
```

Lists keys that need translation for a specific locale.

### Translation Workflow

1. **Export** keys needing translation:

   ```bash
   rake translation:export[fr,50]
   ```

2. **Translate** the exported YAML file using any tool:
   - GitHub Copilot
   - ChatGPT or other LLMs
   - Human translator
   - Any translation service

3. **Review** the translations for accuracy

4. **Import** the translated file:

   ```bash
   rake translation:import[fr,tmp/translate_to_fr_20240101_120000.yml]
   ```

5. **Commit** the updated machine translation files

### Translation Guidelines

When translating:

- Only translate VALUES, never the keys
- Keep template variables like `%{name}` unchanged
- Keep HTML tags like `<a href="...">` unchanged
- Change `/en/` paths to the target locale (e.g., `/fr/`)
- Preserve YAML formatting and indentation

### Priority Order

Machine translations are processed in this priority order:

1. French (fr) - reviewer can verify to a limited extent
2. German (de) - reviewer can verify to a very limited extent
3. Japanese (ja)
4. Chinese Simplified (zh-CN)
5. Portuguese Brazilian (pt-BR)
6. Spanish (es)
7. Russian (ru)
8. Swahili (sw) - lowest priority, limited LLM support

## Automatically translating

Run `translation:copilot` to automatically call GitHub pilot to
perform translations of what needs translating and add them.
When run, copilot only has read/write access to a `tmp` directory.

Run `translation:all` to repeatedly call this, with breaks in between.
The goal is to slowly fill in
translations *without* significantly burdening the AI system.

## Adding a New Language

To add support for a new language:

1. Add the locale to `config/initializers/i18n.rb`
2. Create `config/locales/localization.LOCALE.yml` with locale-specific
   settings (date formats, etc.)
3. Add the locale to translation.io
4. Run `rake translation:sync`
5. Optionally create machine translations to fill gaps
