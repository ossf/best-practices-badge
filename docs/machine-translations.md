# Machine Translations

This document describes our approach to machine-generated translations
in the OpenSSF Best Practices Badge application.

**Important**: We always prefer human-generated translations.
Machine translations are only used as a fallback when human translations
aren't yet available for a given text string. This ensures users always
see text in their language, even for newly-added content, while
maintaining high quality through human review for established content.

## Overview

The application supports multiple languages beyond English:
Chinese Simplified, French, German, Japanese, Portuguese Brazilian,
Russian, Spanish, and Swahili. Translating all application text into
these languages is a significant ongoing effort.

We use a hybrid approach:

1. **Human translations** (primary): Humans translators who natively
   understand the target language provide
   high-quality translations via [translation.io](https://translation.io).
   Running `rake translation:sync` sends the current English text to that
   site and retrieves updated human translations that
   are stored in `config/locales/translation.*.yml`.

2. **Machine translations** (fallback): When human translations don't exist,
   we use machine-generated translations stored in
   `config/machine_translations/*.yml` (the `LOCALE.yml` files store the
   translation, the `src_en_LOCALE.yml` files store the English that they
   were translated from so we can easily detect changes in the English).

### Custom I18n Backend

We use Rails' standard I18n front-end API. However,
we use a custom I18n backend implementation (rather than Rails' default
approach) for two critical reasons:

1. **Preventing pollution of human translations**: The translation.io system
   synchronizes with our translation files. If we simply loaded machine
   translations as regular I18n data, translation.io would treat them as
   translations and send them to the remote system, potentially overriding
   or interfering with human translations. Our custom backend keeps
   machine translations completely separate from the translation.io workflow.

2. **Performance**: This is an extremely busy, high-traffic site under
   constant attack. Rails' default I18n backend wasn't efficient enough
   for our needs. Our custom backend is optimized for fast lookup with
   minimal memory overhead.

Our custom backend (`lib/machine_translation_fallback_backend.rb`) implements
the standard Rails I18n interface, so all `I18n.t()` calls work normally.
It implements translations so that translations have the following priority:

1. Human translations if available (highest priority)
2. If not found, machine translations if available
3. If neither exists, fall back to English

This ensures:

- Human translations always take precedence (highest quality)
- Machine translations provide coverage when human translations don't exist
- The translation.io workflow remains clean and unaffected
- Performance remains optimal for our high-traffic environment

## We use our human translations to guide machine translations

Our approach takes batches of text to translate, selects as examples
the most-relevant human translations for that text to translate,
and provides an LLM with the batches and relevant human translation
examples. This enables the human translations to guide the machine
translations, especially when translating the many specialized technical
terms we use (such as "version control").

A reasonable question would be,
"Why not just send English text directly to
Google Translate, DeepL, or another translation API when needed?"

We intentionally avoid this approach for several important reasons:

### 1. Consistency in Technical Terminology

Our application uses extensive technical terminology that must be
translated consistently throughout the interface:

- **Acronyms**: MFA, VCS, CI/CD, HTTPS, SLSA, SBOM, CPE
- **Proper nouns**: GitHub, GitLab, OpenSSF, Scorecard, Passkeys
- **Technical compounds**: multi-factor authentication, version-control,
  code-review
- **Domain terms**: vulnerability, cryptography, repository, criteria

Different translations of the same term confuse users. For example,
if "repository" is translated as "dépôt" in one place and "référentiel"
in another (both valid French translations), users may think these are
different concepts.

### 2. Context-Aware Translation

Generic translation APIs don't understand our domain. They might translate:

- "badge" as a physical badge/pin rather than a certification badge
- "project" as a school project rather than a software project
- "passing" as physically passing by rather than meeting criteria
- "silver" as the metal rather than a certification level

Our human translators understand the OpenSSF Best Practices context.
By using their translations as examples, machine translations inherit
this understanding.

### 3. Quality and Accuracy

Translation APIs optimize for speed and generality. Our approach optimizes
for quality through:

- **Example-based translation**: Machine translations see how human
  translators handled similar technical content
- **Terminology consistency**: The same English term maps to the same
  target-language term across the entire application
- **Demanding LLM re-review**: We demand that the LLM re-review its own
  proposed translations. Asking an LLM to re-review its own work
  is a surprisingly effective way to improve the quality of its results.
- **Mechanical verification**: We demand that the LLM generate YAML, and
  then we check the YAML (is it valid YAML, are the keys correct,
  are all HTML tags there). These can often detect when a serious problem
  has occurred.
- **Human oversight**: Machine translations can be reviewed and replaced
  with human translations without changing our infrastructure

### 4. Cost Control

Translation APIs charge per character or request. With thousands of
translation keys and frequent updates, costs would accumulate quickly.
Our approach uses AI (like GitHub Copilot) in controlled batches,
keeping costs predictable and manageable.

### 5. Source Tracking

We track which English source text was used to create each machine
translation. When English text changes, we know which translations
need updating. Some translation APIs don't provide this tracking,
leading to stale translations.

## How We Use Human Translations to Guide Machine Translations

Our machine translation process is designed to
mimic our human translators' work. This is the key insight that makes
our approach more effective than it would be otherwise.

### The Process

When machine-translating text to a target language (e.g., French):

1. **Identify untranslated text**: Find keys in English that lack
   human translations in French

2. **Extract technical terms**: Analyze the untranslated text to identify:
   - Acronyms (2+ consecutive capitals: MFA, HTTPS, CI/CD)
   - Proper nouns (capitalized words: GitHub, OpenSSF)
   - Technical compounds (hyphenated: multi-factor, version-control)
   - Long technical words (>12 characters: authentication, vulnerability)

3. **Find translation examples**: Search existing human translations for
   entries containing those same technical terms. For example, if we're
   translating text containing "multi-factor authentication", we find
   human translations that already use that phrase.

4. **Create example files**: Generate two YAML files:
   - `copilot_examples_en_*.yml`: English text with the identified terms
   - `copilot_examples_fr_*.yml`: How humans translated those terms

5. **Generate translations**: Provide the AI with:
   - The text to translate
   - The example files showing how humans translated similar content
   - Detailed instructions emphasizing consistency with examples

6. **Review and validate**: The AI reviews its own work, then we
   validate the YAML structure and ensure no keys or placeholders
   were altered

This approach creates a virtuous cycle: as human translators provide
more translations, machine translations improve by having more
examples to learn from.

### Example

Suppose we need to translate this English text to French:

> "Enable multi-factor authentication (MFA) for all repository contributors."

Our system:

1. Identifies technical terms: "multi-factor authentication", "MFA", "repository"
2. Finds human translations containing these terms, such as:
   - "Multi-factor authentication significantly improves security"
     → "L'authentification multifacteur améliore considérablement la sécurité"
   - "Contributors must have repository access"
     → "Les contributeurs doivent avoir accès au dépôt"
3. Shows these examples to the AI
4. The AI produces: "Activez l'authentification multifacteur (MFA) pour
   tous les contributeurs au dépôt"

This translation uses the same terms human translators chose, maintaining
consistency across the application.

## Source Tracking and Staleness Detection

Machine translations can become stale when English source text changes.
We track this automatically.

### Source Tracking Files

For each locale, we maintain two files:

- `config/machine_translations/fr.yml`: French machine translations
- `config/machine_translations/src_en_fr.yml`: English source used to
  create those translations

When we machine-translate a key, we store both the translation and the
English text that was translated. This serves as a snapshot.

### Detecting Stale Translations

When running `rake translation:export` (export to an arbitrary AI system):

1. Compare current English text (`config/locales/en.yml`)
2. Against tracked source (`config/machine_translations/src_en_fr.yml`)
3. If different, mark that key as needing re-translation

This happens automatically. Stale machine translations are treated as
"untranslated" and included in the next export batch.

**Important exception**: Human translations are never automatically
invalidated. If a human translation exists (even if English changed),
it takes precedence. Only machine translations are subject to automatic
staleness detection.

## Translation Priority Order

When machine-translating, we process languages in this priority order:

1. **French** - Reviewer can verify translations (limited proficiency)
2. **German** - Reviewer can verify to a very limited extent
3. **Japanese** - High-quality LLM support
4. **Chinese Simplified** - High-quality LLM support
5. **Portuguese Brazilian** - Good LLM support
6. **Spanish** - Good LLM support
7. **Russian** - Good LLM support
8. **Swahili** - Limited LLM support

This ordering serves two purposes:

1. **Quality validation**: Languages the reviewer can verify are
   processed first, allowing us to catch issues early
2. **Resource allocation**: If we can only translate N keys, we
   translate the languages with better LLM support first

Unfortunately Swahili has less digital data available than many of the
other languages we support (such as French or Japanese), and the
quality of machine learning based systems are fundamentally dependent
on the amount and quality of training data.
We believe providing the translation is better than *not* providing it, and
as always the machine translations are only used when we don't have
human translations.

At the time of this writing,
our Brazilian Portuguese and Spanish translations suffer from their
relative paucity of human translations specific to our application.
However, these are widely-used languages with significant amounts
of digital data available for training. Therefore, LLMs will typically
be somewhat better at translating them.

## Rake Tasks for Machine Translation

The machine translation workflow is managed through rake tasks in
the `translation:` namespace.

### Show Translation Status

```bash
rake translation:status
```

Displays statistics for each locale:

- Total keys in English
- Keys with human translations
- Keys with machine translations only
- Keys missing translations entirely

For example, here is the output of 2026-02-14:

~~~~
Translation Status:
------------------------------------------------------------
fr       Human:  733  Machine:  223  Missing:    0
de       Human:  667  Machine:  289  Missing:    0
ja       Human:  733  Machine:  223  Missing:    0
zh-CN    Human:  687  Machine:  269  Missing:    0
pt-BR    Human:   21  Machine:  935  Missing:    0
es       Human:   79  Machine:  877  Missing:    0
ru       Human:  662  Machine:  294  Missing:    0
sw       Human:  179  Machine:  777  Missing:    0
~~~~

### Export Keys for Translation

```bash
rake translation:export[LOCALE,COUNT]
```

Exports untranslated keys to a YAML file for translation.

**Parameters:**

- `LOCALE`: Target language (fr, de, ja, zh-CN, pt-BR, es, ru, sw)
- `COUNT`: Number of keys to export (default: 50)

**Examples:**

```bash
# Export 50 French keys (default)
rake translation:export[fr,50]

# Export 100 German keys
rake translation:export[de,100]

# Auto-select next priority locale needing translation
rake translation:export
```

**What it does:**

1. Identifies untranslated keys (no human translation, no current
   machine translation, or stale machine translation)
2. Selects up to COUNT keys
3. Extracts technical terms from those keys
4. Finds existing human translations containing those terms
5. Creates example files showing how humans translated similar content
6. Generates:
   - `tmp/translate_to_LOCALE_TIMESTAMP.yml` (keys to translate)
   - `copilot_examples_en_TIMESTAMP.yml` (English examples)
   - `copilot_examples_LOCALE_TIMESTAMP.yml` (translated examples)
   - `tmp/translate_instructions_LOCALE_TIMESTAMP.txt` (detailed instructions)

The output files contain everything needed to translate the keys, whether
using an AI, a human translator, or any translation tool.

### Import Translated Files

```bash
rake translation:import[LOCALE,FILE]
```

Imports a translated YAML file into machine translations.

**Parameters:**

- `LOCALE`: Target language
- `FILE`: Path to translated YAML file

**Example:**

```bash
rake translation:import[fr,tmp/translate_to_fr_20240101_120000.yml]
```

**What it does:**

1. Loads the translated YAML file
2. Validates YAML structure
3. Verifies all keys exist in English source (removes hallucinated keys)
4. Checks that values aren't empty (unless English is empty)
5. Updates `config/machine_translations/LOCALE.yml` with new translations
6. Updates `config/machine_translations/src_en_LOCALE.yml` with source tracking

**Key validation**: The import process is strict about keys. If the
translated file contains keys that don't exist in English
(e.g., hallucinated by an AI), they're automatically removed and logged.
This prevents pollution of the translation database.

### Clean Up Machine Translations

```bash
rake translation:cleanup
```

Removes machine translations for keys that now have human translations.

**When to run**: After `rake translation:sync` retrieves new human
translations from translation.io.

**What it does:**

1. For each locale, compares machine translations against human translations
2. Removes any machine translation where a human translation now exists
3. Updates both the translation file and source tracking file

The cleanup is conservative:
it only removes keys where a non-empty human translation exists.

This isn't all that important, because our backend doesn't keep
unused translations.

### List Untranslated Keys

```bash
rake translation:untranslated[LOCALE]
```

Lists keys needing translation for a specific locale.

Shows the first 20 untranslated keys and a count of how many total
untranslated keys exist. Useful for understanding translation workload.

### Automated Translation via GitHub Copilot

```bash
rake translation:copilot[LOCALE,COUNT]
```

Fully automated translation using GitHub Copilot CLI.

**Parameters:**

- `LOCALE`: Target language (optional, auto-selects if omitted)
- `COUNT`: Number of keys to translate (default: 20)

**Example:**

```bash
# Translate 20 keys to French
rake translation:copilot[fr,20]

# Auto-select locale and translate 20 keys
rake translation:copilot
```

**What it does:**

This is a complete end-to-end automation:

1. Runs `translation:export` to create files
2. Invokes GitHub Copilot CLI with detailed translation instructions
3. Copilot translates the keys using the provided examples
4. Copilot reviews its own translations for quality
5. Validates the resulting YAML
6. Runs `translation:import` to add the translations

**Security**: The Copilot process runs in a restricted environment
with read/write access only to a `tmp/` directory. It cannot modify
source code or configuration directly.

This task is safe to run repeatedly.
By translating small batches repeatedly, we gradually fill in missing
translations without overwhelming the AI or incurring high costs.

## Translation Workflow (Manual)

For human review or non-Copilot translation:

1. **Export** untranslated keys:

   ```bash
   rake translation:export[fr,50]
   ```

   This creates files in `tmp/` with instructions.

2. **Translate** the file:

   - Use the provided example files for consistency
   - Follow the detailed instructions in `tmp/translate_instructions_*.txt`
   - Keep template variables like `%{name}` unchanged
   - Preserve HTML tags
   - Change `/en/` paths to `/fr/` (or target locale)

   You can use any tool: ChatGPT, DeepL, human translators, etc.

3. **Review** translations:

   - Ensure technical terms are consistent with examples
   - Check that all placeholders remain unchanged
   - Verify YAML formatting is correct

4. **Import** the translations:

   ```bash
   rake translation:import[fr,tmp/translate_to_fr_20240101_120000.yml]
   ```

5. **Commit** the changes:

   ```bash
   git add config/machine_translations/
   git commit -m "Add French machine translations for 50 keys"
   ```

## Translation Guidelines

When translating (whether manually or reviewing AI output):

### Must Follow

- **Only translate VALUES**: Never translate YAML keys (they're English identifiers)
- **Preserve placeholders**: Keep `%{variable}` exactly as-is
- **Preserve HTML tags**: Every `<tag>`, `</tag>`, and `<tag/>` must appear
  in the translation
- **Update locale paths**: Change `/en/` to `/LOCALE/` in URLs
- **Preserve YAML structure**: Same nesting, indentation, and hierarchy
- **Translate pluralization**: Adapt zero/one/few/many/other to target language
- **Non-empty values**: Don't leave translations blank unless English is blank

### Best Practices

- **Don't translate proper names**: GitHub, OpenSSF, Scorecard remain as-is
- **Use examples**: Consult provided example files for terminology consistency
- **Maintain tone**: Keep the professional, helpful tone of the English text
- **Consider context**: "badge" is a certification, not a physical object
- **Natural phrasing**: Translate meaning, not just words

## Quality Assurance

Machine translations go through multiple validation layers:

### 1. AI Self-Review

When using Copilot, we use a two-step process:

1. Initial translation
2. AI reviews its own translation, comparing to source and examples,
   fixing any issues

This catches many obvious errors before human review.

### 2. Structural Validation

The import process validates:

- YAML syntax is correct
- All keys from source are present
- No extra/hallucinated keys exist
- Values aren't empty (unless source is empty)
- Placeholders like `%{name}` are preserved

### 3. Source Tracking

When English changes, affected machine translations are automatically
marked for re-translation, preventing stale content.

### 4. Human Override

Human translators can always replace machine translations by providing
translations via translation.io. The human translation immediately
takes precedence.

## File Structure

```
config/
├── locales/
│   ├── en.yml                      # English source (always edit this)
│   ├── translation.de.yml          # Human translations from translation.io
│   ├── translation.es.yml
│   ├── translation.fr.yml
│   ├── translation.ja.yml
│   ├── translation.pt-BR.yml
│   ├── translation.ru.yml
│   ├── translation.sw.yml
│   └── translation.zh-CN.yml
└── machine_translations/
    ├── de.yml                      # Machine translations (German)
    ├── es.yml
    ├── fr.yml
    ├── ja.yml
    ├── pt-BR.yml
    ├── ru.yml
    ├── sw.yml
    ├── zh-CN.yml
    ├── src_en_de.yml               # Source tracking (German)
    ├── src_en_es.yml
    ├── src_en_fr.yml
    ├── src_en_ja.yml
    ├── src_en_pt-BR.yml
    ├── src_en_ru.yml
    ├── src_en_sw.yml
    └── src_en_zh-CN.yml
```

## Performance Impact

Machine translations are loaded at Rails startup, not per-request.
The performance impact is minimal:

- **Startup time**: Adds ~100ms to load additional YAML files
- **Memory**: ~1-2 MB per language for machine translations
- **Runtime**: Nearly zero cost (translations pre-loaded in memory)

This is far more efficient than calling translation APIs per-request.

## Limitations and Trade-offs

### What This Approach Handles Well

- Technical terminology consistency
- Placeholder and HTML preservation
- Cost-effective translation at scale
- Automatic staleness detection
- Graceful degradation (machine → human → English)

### Known Limitations

1. **Initial quality**: Machine translations are lower quality than human
   translations.

2. **Cultural context**: AI may miss cultural nuances that human
   translators catch

3. **Idioms**: Machine translation of idioms may be awkward, though
   we minimize idioms in our UI text

4. **Complex grammar**: Some languages have grammatical cases or
   gender agreement that AI may not handle perfectly

5. **Swahili support weak**: LLM support for Swahili is limited

### Mitigation

All these limitations are acceptable because:

- Machine translations can be replaced by human translations
- Any translation, if intelligible, is better than English
  for non-English speakers

## Backend Technical Implementation

The custom backend in `lib/machine_translation_fallback_backend.rb` is
optimized for high performance because this application serves a very large
number of translation lookups per second on an extremely busy production site
under constant attack.

**Key Performance Optimizations:**

1. **Flattened Key Storage**: All translations are stored with dotted keys
   (e.g., `"criteria.0.description"`) in a flat hash rather than nested
   hashes. This enables O(1) lookups using `hash.dig(locale, key)` instead
   of traversing multiple hash levels.

2. **Frozen Strings**: All translation values are frozen at initialization
   time. This prevents Ruby from allocating new string objects on every
   translation lookup, significantly reducing memory churn and garbage
   collection pressure.

3. **Frozen Constants**: Empty hashes and arrays used as default parameters
   are stored as frozen constants (`EMPTY_HASH`, `EMPTY_ARRAY`). This avoids
   allocating new objects for every method call that uses default parameters.

4. **Pre-determined Fallbacks**: English fallbacks are merged into each
   locale's hash at initialization time. There's no runtime fallback
   logic - every key either has a value or doesn't. This eliminates
   conditional branches in the hot path.

5. **Single Merged Hash**: Machine and human translations are merged at
   startup into a single flat hash structure. Runtime lookups check
   one hash, not multiple layers. Source YAML files are discarded
   after merging to minimize memory usage.

6. **Efficient Pluralization**: Pluralization parent hashes (containing
   `:zero`, `:one`, `:other`, etc.) are built during the initial flattening
   pass, not reconstructed on every lookup.

**Memory Efficiency:**

- Only the final merged flat hash is retained in memory
- Source YAML data structures are discarded after flattening
- One YAML file is loaded at a time to minimize peak memory usage
- Frozen strings prevent duplication

**Why This Matters:**

A typical Rails page in this application makes dozens to hundreds of
translation lookups. With many concurrent users, aggressive web crawlers,
and attackers constantly probing the site, even small inefficiencies in the
translation layer compound into significant performance and memory problems.

The flattened key structure, frozen strings, and pre-merged fallbacks
eliminate allocation pressure in the hot path, keeping memory growth
under control and response times fast.

## Summary

Our machine translation approach balances quality, cost, and coverage:

- **Human translations are primary**: Always used when available
- **Machine translations fill gaps**: Provide immediate coverage
- **Human examples guide quality**: Human translations guide the AI
- **Terminology consistency**: Technical terms translated more uniformly
- **Automatic staleness detection**: Keeps translations current
- **Human override**: Easy path to replace machine with human translations

This approach ensures users always see text in their language while
maintaining high quality through human review for established content.
The system improves over time as more human translations become available
to guide future machine translations.

For details on human translation management, see [translations.md](./translations.md).
