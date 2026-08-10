#!/usr/bin/env ruby
# frozen_string_literal: true

# Copyright the Linux Foundation and the
# OpenSSF Best Practices badge contributors
# SPDX-License-Identifier: MIT

# Generate baseline badge SVG files.
#
# This script generates all baseline badge images:
# - Level badges: badge_baseline_1.svg, badge_baseline_2.svg, badge_baseline_3.svg
# - Percentage badges: badge_baseline_pct_0.svg through badge_baseline_pct_99.svg
#
# Badge left-side text reads "openssf baseline <version>", where the version
# comes from BaselineConfig::CURRENT_VERSION in app/lib/baseline_config.rb.
# Update that constant when the baseline version changes, then re-run this
# script to regenerate the badge images.
#
# Usage:
#   ruby script/generate_baseline_badges.rb
#
# After running this script, run `rake assets:precompile` to update the
# asset pipeline.
#
# == Width calculation ==
#
# SVG badge widths must match the rendered text to avoid squishing or
# stretching. This script measures text widths from actual font metrics
# using Python3 + Pillow, with Verdana as the measurement font.
#
# Verdana is the right choice: it is the first (and therefore preferred)
# font in the SVG font-family stack used by every badge:
#   font-family="Verdana,Geneva,DejaVu Sans,sans-serif"
#
# Geneva and DejaVu Sans have nearly identical metrics to Verdana at 11px
# (within ~1px), so Verdana measurements produce correct-looking results
# regardless of which font a particular viewer's browser actually renders.
#
# If Python3, Pillow, or Verdana.ttf is unavailable this script falls back
# to a built-in character-width table that was measured from Verdana 11px
# and prints instructions for enabling accurate measurement.

require 'json'
require_relative '../app/lib/baseline_config'

OUTPUT_DIR = File.expand_path('../app/assets/images', __dir__)

# The SVG uses font-size="110" with transform="scale(.1)" = 11px effective.
BADGE_FONT_SIZE_PX = 11

# Verdana.ttf search paths on common platforms (tried in order).
VERDANA_PATHS = [
  './verdana.ttf', # local
  '/usr/share/fonts/truetype/msttcorefonts/Verdana.ttf', # Debian/Ubuntu msttcorefonts
  '/usr/share/fonts/truetype/msttcorefonts/verdana.ttf', # alternate case
  '/Library/Fonts/Verdana.ttf',                          # macOS (Microsoft Office)
  '/Library/Fonts/Microsoft/Verdana.ttf',                # macOS (newer Office)
  'C:/Windows/Fonts/verdana.ttf'                         # Windows
].freeze

# Padding (pixels) added on each side of text within a badge section.
BADGE_PADDING_PX = 10

BASELINE_COLORS = {
  1 => '#007ec6',
  2 => '#0066a1',
  3 => '#004b87'
}.freeze

PERCENTAGE_COLOR  = '#c45500'
CONSTRUCTION_ICON = '🚧'

# Advance widths for Verdana Regular 11px (pixels), measured via
# Python PIL's font.getlength(). Indexed as FALLBACK_WIDTHS[char.ord - 32]
# for printable ASCII (32-126). The per-character sums exactly reproduce
# getlength() measurements on full strings (no kerning correction needed).
# Used as fallback when Python3/Pillow/Verdana are unavailable.
FALLBACK_WIDTHS = [
  3.875, 4.328, 5.047, 9.0,    7.0, 11.844, 8.0, 2.953, # 32-39  SP ! " # $ % & '
  5.0,   5.0,   7.0,   9.0,    4.0,    5.0,   4.0,    5.0,   # 40-47  ( ) * + , - . /
  7.0,   7.0,   7.0,   7.0,    7.0,    7.0,   7.0,    7.0,   # 48-55  0 1 2 3 4 5 6 7
  7.0,   7.0,   5.0,   5.0,    9.0,    9.0,   9.0,    6.0,   # 56-63  8 9 : ; < = > ?
  11.0,  7.516, 7.547, 7.688,  8.469,  6.953, 6.328,  8.531, # 64-71  @ A B C D E F G
  8.266, 4.625, 5.0,   7.625,  6.125,  9.266, 8.234,  8.656, # 72-79  H I J K L M N O
  6.641, 8.656, 7.656, 7.516,  6.781,  8.047, 7.516, 10.875, # 80-87  P Q R S T U V W
  7.531, 6.766, 7.531, 5.0,    5.0,    5.0,   9.0,    7.0,   # 88-95  X Y Z [ \ ] ^ _
  7.0,   6.609, 6.859, 5.734,  6.859,  6.547, 3.875,  6.859, # 96-103 ` a b c d e f g
  6.969, 3.016, 3.781, 6.516,  3.016, 10.703, 6.969,  6.672, # 104-111 h i j k l m n o
  6.859, 6.859, 4.688, 5.734,  4.328,  6.969, 6.516,  9.0,   # 112-119 p q r s t u v w
  6.516, 6.516, 5.781, 6.984,  5.0,    6.984, 9.0            # 120-126 x y z { | } ~
].freeze

# Default for non-ASCII characters in fallback mode.
# Calibrated at 11.0 so "🚧 X%" and "🚧 XX%" widths match PIL measurements.
FALLBACK_NONASCII_WIDTH = 11.0

VERDANA_MISSING_MSG = <<~MSG

  WARNING: Verdana.ttf not found. Badge widths will use the built-in
  fallback character-width table (measured from Verdana 11px). This is
  accurate, but for exact pixel-perfect measurement install Verdana:

    Debian/Ubuntu:  sudo apt-get install ttf-mscorefonts-installer
    Other Linux:    install the 'msttcorefonts' package
    macOS/Windows:  Verdana ships with Microsoft Office or system fonts

MSG

PYTHON_MISSING_MSG = <<~MSG

  WARNING: python3 not found. Badge widths will use the built-in
  fallback character-width table (measured from Verdana 11px).

  For exact pixel-perfect measurement, install Python 3 and Pillow:
    sudo apt-get install python3 python3-pil
    # or: pip3 install Pillow

MSG

PIL_MISSING_MSG = <<~MSG

  WARNING: Python3 is present but could not load Pillow (PIL) with
  Verdana. Badge widths will use the built-in fallback table.

  To enable accurate measurement:
    pip3 install Pillow
    # or: sudo apt-get install python3-pil

MSG

# Returns text width in pixels using the fallback character-width table.
def fallback_text_width(text)
  text.each_char.sum do |c|
    ord = c.ord
    ord.between?(32, 126) ? FALLBACK_WIDTHS[ord - 32] : FALLBACK_NONASCII_WIDTH
  end
end

# Emits a warning and returns the fallback method descriptor.
def warn_and_fallback(msg)
  warn msg
  { method: :fallback }
end

# Returns true if python3 can load PIL and open Verdana at BADGE_FONT_SIZE_PX.
def pil_works?(font_path)
  probe = <<~PYTHON.chomp
    from PIL import ImageFont
    ImageFont.truetype(#{font_path.inspect}, #{BADGE_FONT_SIZE_PX})
    print('ok')
  PYTHON
  IO.popen(['python3', '-c', probe], err: File::NULL) { |io| io.read.strip } == 'ok'
rescue StandardError
  false
end

# Detects the best available text-width measurement method.
# Returns { method: :pil, font_path: "..." } or { method: :fallback }.
# Prints an actionable warning if PIL or Verdana is unavailable.
def detect_measurement_method
  verdana_path = VERDANA_PATHS.find { |p| File.exist?(p) }
  return warn_and_fallback(VERDANA_MISSING_MSG) unless verdana_path
  return { method: :pil, font_path: verdana_path } if pil_works?(verdana_path)

  warn_and_fallback(PIL_MISSING_MSG)
rescue Errno::ENOENT
  warn_and_fallback(PYTHON_MISSING_MSG)
end

# Returns the Python script that measures text widths via PIL.
def pil_measure_script(font_path)
  <<~PYTHON
    import json, sys
    from PIL import ImageFont
    font = ImageFont.truetype(#{font_path.inspect}, #{BADGE_FONT_SIZE_PX})
    for t in json.loads(sys.stdin.read()):
        try: print(font.getlength(t))
        except AttributeError:
            bb = font.getbbox(t)
            print((bb[2]-bb[0]) if bb else 0)
  PYTHON
end

# Measures multiple texts at once via Python3 + PIL (one subprocess call).
# Returns an array of float widths parallel to texts, or nil on failure.
def measure_texts_pil(texts, font_path)
  output =
    IO.popen(['python3', '-c', pil_measure_script(font_path)], 'r+') do |io|
      io.write(texts.to_json)
      io.close_write
      io.read
    end
  lines = output.strip.split("\n")
  lines.length == texts.length ? lines.map(&:to_f) : nil
rescue StandardError
  nil
end

# Measures all texts needed for badge generation in one pass.
# Returns a hash of pixel widths keyed by role.
def measure_all_widths(method_info)
  left_text = "openssf baseline #{BaselineConfig::CURRENT_VERSION}"
  texts = [left_text, '1', "#{CONSTRUCTION_ICON} 0%", "#{CONSTRUCTION_ICON} 10%"]
  pxs =
    if method_info[:method] == :pil
      measure_texts_pil(texts, method_info[:font_path]) || texts.map { |t| fallback_text_width(t) }
    else
      texts.map { |t| fallback_text_width(t) }
    end
  left_px, digit_px, pct1_px, pct2_px = pxs
  { left: left_px, digit: digit_px, pct1: pct1_px, pct2: pct2_px, left_text: left_text }
end

# Badge section pixel width for a given text pixel width.
def section_width(text_px)
  text_px.ceil + (2 * BADGE_PADDING_PX)
end

# SVG textLength value for a given text pixel width.
# The badge SVG uses font-size="110" with transform="scale(.1)", so
# the SVG coordinate system is 10× the display pixel count.
def svg_text_length(text_px)
  (text_px * 10).round
end

# Computes SVG layout geometry for a two-section badge.
# Returns section widths (lw, rw, tw) and text-positioning values (lcx, rcx, ltl, rtl).
def badge_geometry(left_px, right_px)
  lw = section_width(left_px)
  rw = section_width(right_px)
  {
    lw: lw, rw: rw, tw: lw + rw,
    ltl: svg_text_length(left_px),
    rtl: svg_text_length(right_px),
    lcx: (lw / 2.0 * 10).to_i,
    rcx: ((lw + (rw / 2.0)) * 10).to_i
  }
end

# Generates the SVG for a level badge (1, 2, or 3).
def generate_level_badge(level, widths)
  lbl        = widths[:left_text]
  g          = badge_geometry(widths[:left], widths[:digit])
  lw, rw, tw = g.values_at(:lw, :rw, :tw)
  ltl, rtl   = g.values_at(:ltl, :rtl)
  lcx, rcx   = g.values_at(:lcx, :rcx)
  aria  = "#{lbl}: #{level}"
  color = BASELINE_COLORS[level]
  <<~SVG.strip
    <svg xmlns="http://www.w3.org/2000/svg" xmlns:xlink="http://www.w3.org/1999/xlink" width="#{tw}" height="20" role="img" aria-label="#{aria}"><title>#{aria}</title><linearGradient id="s" x2="0" y2="100%"><stop offset="0" stop-color="#bbb" stop-opacity=".1"/><stop offset="1" stop-opacity=".1"/></linearGradient><clipPath id="r"><rect width="#{tw}" height="20" rx="3" fill="#fff"/></clipPath><g clip-path="url(#r)"><rect width="#{lw}" height="20" fill="#555"/><rect x="#{lw}" width="#{rw}" height="20" fill="#{color}"/><rect width="#{tw}" height="20" fill="url(#s)"/></g><g fill="#fff" text-anchor="middle" font-family="Verdana,Geneva,DejaVu Sans,sans-serif" text-rendering="geometricPrecision" font-size="110"><text aria-hidden="true" x="#{lcx}" y="150" fill="#010101" fill-opacity=".3" transform="scale(.1)" textLength="#{ltl}">#{lbl}</text><text x="#{lcx}" y="140" transform="scale(.1)" fill="#fff" textLength="#{ltl}">#{lbl}</text><text aria-hidden="true" x="#{rcx}" y="150" fill="#010101" fill-opacity=".3" transform="scale(.1)" textLength="#{rtl}">#{level}</text><text x="#{rcx}" y="140" transform="scale(.1)" fill="#fff" textLength="#{rtl}">#{level}</text></g></svg>
  SVG
end

# Generates the SVG for an in-progress percentage badge (0-99%).
def generate_percentage_badge(pct, widths)
  pct_w      = pct < 10 ? widths[:pct1] : widths[:pct2]
  lbl        = widths[:left_text]
  g          = badge_geometry(widths[:left], pct_w)
  lw, rw, tw = g.values_at(:lw, :rw, :tw)
  ltl, rtl   = g.values_at(:ltl, :rtl)
  lcx, rcx   = g.values_at(:lcx, :rcx)
  label = "#{CONSTRUCTION_ICON} #{pct}%"
  aria  = "#{lbl}: in progress #{pct}%"
  <<~SVG.strip
    <svg xmlns="http://www.w3.org/2000/svg" xmlns:xlink="http://www.w3.org/1999/xlink" width="#{tw}" height="20" role="img" aria-label="#{aria}"><title>#{aria}</title><linearGradient id="s" x2="0" y2="100%"><stop offset="0" stop-color="#bbb" stop-opacity=".1"/><stop offset="1" stop-opacity=".1"/></linearGradient><clipPath id="r"><rect width="#{tw}" height="20" rx="3" fill="#fff"/></clipPath><g clip-path="url(#r)"><rect width="#{lw}" height="20" fill="#555"/><rect x="#{lw}" width="#{rw}" height="20" fill="#{PERCENTAGE_COLOR}"/><rect width="#{tw}" height="20" fill="url(#s)"/></g><g fill="#fff" text-anchor="middle" font-family="Verdana,Geneva,DejaVu Sans,sans-serif" text-rendering="geometricPrecision" font-size="110"><text aria-hidden="true" x="#{lcx}" y="150" fill="#010101" fill-opacity=".3" transform="scale(.1)" textLength="#{ltl}">#{lbl}</text><text x="#{lcx}" y="140" transform="scale(.1)" fill="#fff" textLength="#{ltl}">#{lbl}</text><text aria-hidden="true" x="#{rcx}" y="150" fill="#010101" fill-opacity=".3" transform="scale(.1)" textLength="#{rtl}">#{label}</text><text x="#{rcx}" y="140" transform="scale(.1)" fill="#fff" textLength="#{rtl}">#{label}</text></g></svg>
  SVG
end

# Main execution

puts "Generating baseline badges in #{OUTPUT_DIR}..."
puts "  Version: #{BaselineConfig::CURRENT_VERSION}"

method_info = detect_measurement_method
widths      = measure_all_widths(method_info)

measurer_label =
  if method_info[:method] == :pil
    "Python3+Pillow+Verdana (#{method_info[:font_path]})"
  else
    'built-in fallback table (Verdana 11px measurements)'
  end
puts "  Width measurement: #{measurer_label}"
puts "  Left text: #{widths[:left_text].inspect} " \
     "(#{widths[:left].round(1)}px → #{section_width(widths[:left])}px section)"

[1, 2, 3].each do |level|
  svg  = generate_level_badge(level, widths)
  path = "#{OUTPUT_DIR}/badge_baseline_#{level}.svg"
  File.write(path, "#{svg}\n")
  tw = section_width(widths[:left]) + section_width(widths[:digit])
  puts "  Generated: badge_baseline_#{level}.svg (total width: #{tw}px)"
end

(0..99).each do |pct|
  svg  = generate_percentage_badge(pct, widths)
  path = "#{OUTPUT_DIR}/badge_baseline_pct_#{pct}.svg"
  File.write(path, "#{svg}\n")
end
puts '  Generated: badge_baseline_pct_0.svg through badge_baseline_pct_99.svg'

puts <<~DONE

  Done! Generated 3 level badges and 100 percentage badges.

  Next steps:
  1. Run `rake assets:precompile` to update the asset pipeline
  2. Badge widths are computed from text metrics each run (no manual update needed)
DONE
