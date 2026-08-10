# frozen_string_literal: true

# Copyright 2015-2017, the Linux Foundation, IDA, and the
# OpenSSF Best Practices badge contributors
# SPDX-License-Identifier: MIT

# Examine software license (already determined), expressed with SPDX,
# to report if it's open source software (OSS) and meets OSI requirements.

# rubocop:disable Metrics/ClassLength
class FlossLicenseDetective < Detective
  # Individual detectives must identify their inputs, outputs
  INPUTS = [:license].freeze
  OUTPUTS = %i[
    floss_license_osi_status floss_license_status
    osps_le_02_01_status
  ].freeze

  # This detective can override with high confidence (5) when it
  # detects OSI-approved or non-OSI licenses
  OVERRIDABLE_OUTPUTS = %i[
    floss_license_osi_status floss_license_status
    osps_le_02_01_status
  ].freeze

  # From: http://opensource.org/licenses/alphabetical
  # Note: We accept the older GNU license forms, e.g., "GPL-2.0", and
  # the newer SPDX 3.0 license names, e.g.,
  # "GPL-2.0-only" and "GPL-2.0-or-later".
  # SPDX 3.0 does not provide a way to say, "GPL version 2.0 is acceptable,
  # and I don't know if later versions are acceptable"; in practice,
  # "GPL-2.0" is being used that way.
  # See: https://spdx.org/news/news/2018/01/license-list-30-released
  OSI_LICENSES_FROM_OSI_WEBSITE = [
    'Academic Free License 3.0 (AFL-3.0)',
    'Adaptive Public License (APL-1.0)',
    'Apache License 2.0 (Apache-2.0)',
    'Apple Public Source License (APSL-2.0)',
    'Artistic license 2.0 (Artistic-2.0)',
    'Attribution Assurance Licenses (AAL)',
    'BSD 3-Clause "New" or "Revised" License (BSD-3-Clause)',
    'BSD 2-Clause "Simplified" or "FreeBSD" License (BSD-2-Clause)',
    'Boost Software License (BSL-1.0)',
    'CeCILL License 2.1 (CECILL-2.1)',
    'Computer Associates Trusted Open Source License 1.1 (CATOSL-1.1)',
    'Common Development and Distribution License 1.0 (CDDL-1.0)',
    'Common Public Attribution License 1.0 (CPAL-1.0)',
    'CUA Office Public License Version 1.0 (CUA-OPL-1.0)',
    'EU DataGrid Software License (EUDatagrid)',
    'Eclipse Public License 1.0 (EPL-1.0)',
    'Educational Community License, Version 2.0 (ECL-2.0)',
    'Eiffel Forum License V2.0 (EFL-2.0)',
    'Entessa Public License (Entessa)',
    'European Union Public License, Version 1.1 (EUPL-1.1)',
    'Fair License (Fair)',
    'Frameworx License (Frameworx-1.0)',
    'GNU Affero General Public License v3 (AGPL-3.0)',
    'GNU Affero General Public License v3 only (AGPL-3.0-only)',
    'GNU Affero General Public License v3 or later (AGPL-3.0-or-later)',
    'GNU General Public License version 2.0 (GPL-2.0)',
    'GNU General Public License version 2.0 only (GPL-2.0-only)',
    'GNU General Public License version 2.0 or later (GPL-2.0-or-later)',
    'GNU General Public License version 3.0 (GPL-3.0)',
    'GNU General Public License version 3.0 only (GPL-3.0-only)',
    'GNU General Public License version 3.0 or later (GPL-3.0-or-later)',
    'GNU Library or "Lesser" General Public License version 2.1 (LGPL-2.1)',
    'GNU Library or "Lesser" General Public License version 2.1 only ' \
    '(LGPL-2.1-only)',
    'GNU Library or "Lesser" General Public License version 2.1 or later ' \
    '(LGPL-2.1-or-later)',
    'GNU Library or "Lesser" General Public License version 3.0 (LGPL-3.0)',
    'GNU Library or "Lesser" General Public License version 3.0 only ' \
    '(LGPL-3.0-only)',
    'GNU Library or "Lesser" General Public License version 3.0 or later ' \
    '(LGPL-3.0-or-later)',
    'Historical Permission Notice and Disclaimer (HPND)',
    'IBM Public License 1.0 (IPL-1.0)',
    'IPA Font License (IPA)',
    'ISC License (ISC)',
    'LaTeX Project Public License 1.3c (LPPL-1.3c)',
    'Lucent Public License Version 1.02 (LPL-1.02)',
    'MirOS Licence (MirOS)',
    'Microsoft Public License (MS-PL)',
    'Microsoft Reciprocal License (MS-RL)',
    'MIT license (MIT)',
    'Motosoto License (Motosoto)',
    'Mozilla Public License 2.0 (MPL-2.0)',
    'Multics License (Multics)',
    'NASA Open Source Agreement 1.3 (NASA-1.3)',
    'NTP License (NTP)',
    'Naumen Public License (Naumen)',
    'Nethack General Public License (NGPL)',
    'Nokia Open Source License (Nokia)',
    'Non-Profit Open Software License 3.0 (NPOSL-3.0)',
    'OCLC Research Public License 2.0 (OCLC-2.0)',
    'Open Font License 1.1 (OFL-1.1)',
    'Open Group Test Suite License (OGTSL)',
    'Open Software License 3.0 (OSL-3.0)',
    'PHP License 3.0 (PHP-3.0)',
    'The PostgreSQL License (PostgreSQL)',
    'Python License (Python-2.0)',
    'CNRI Python license (CNRI-Python)',
    'Q Public License (QPL-1.0)',
    'RealNetworks Public Source License V1.0 (RPSL-1.0)',
    'Reciprocal Public License 1.5 (RPL-1.5)',
    'Ricoh Source Code Public License (RSCPL)',
    'Simple Public License 2.0 (SimPL-2.0)',
    'Sleepycat License (Sleepycat)',
    'Sun Public License 1.0 (SPL-1.0)',
    'Sybase Open Watcom Public License 1.0 (Watcom-1.0)',
    'University of Illinois/NCSA Open Source License (NCSA)',
    'Universal Permissive License (UPL)',
    'Vovida Software License v. 1.0 (VSL-1.0)',
    'W3C License (W3C)',
    'wxWindows Library License (WXwindows)',
    'X.Net License (Xnet)',
    'Zope Public License 2.0 (ZPL-2.0)',
    'zlib/libpng license (Zlib)'
  ].freeze

  # Create list of *just* SPDX names, e.g., ['Apache-2.0', 'MIT', 'GPL-2.0']
  KNOWN_OSI_LICENSES =
    FlossLicenseDetective::OSI_LICENSES_FROM_OSI_WEBSITE.map do |text|
      text.match(/\(([^()]*)\)/) do |m|
        m[1] # Return whatever is inside first parentheses
      end
    end

  # Report if string is an OSI-approved license.  We ignore case.
  # TODO: Handle AND, OR, WITH
  KNOWN_OSI_LICENSES_DOWNCASED =
    FlossLicenseDetective::KNOWN_OSI_LICENSES.map(&:downcase)
  def self.osi_license?(s)
    FlossLicenseDetective::KNOWN_OSI_LICENSES_DOWNCASED.include?(s.downcase)
  end

  # Individual detectives must implement "analyze"
  # rubocop:disable Metrics/MethodLength
  def analyze(_evidence, current)
    license = current[:license]
    return {} if license.blank?

    # Remove '+' - allowing later license versions is always fine.
    license = license.strip.chomp('+')

    if self.class.osi_license?(license)
      {
        floss_license_osi_status:
                  {
                    value: CriterionStatus::MET, confidence: 5,
                    explanation: I18n.t('detectives.floss_license.osi_approved',
                                        license: license)
                  },
        floss_license_status:
          {
            value: CriterionStatus::MET, confidence: 5,
            explanation: I18n.t('detectives.floss_license.osi_approved',
                                license: license)
          },
        osps_le_02_01_status:
          {
            value: CriterionStatus::MET, confidence: 5,
            explanation: I18n.t('detectives.floss_license.osi_approved_repository',
                                license: license)
          },
        # We can't know what the license of the *released* assets are
        # looking only at the repository, as the LICENSE file is focused
        # on the repository contents, so we can't do osps_le_02_02_status.
        # Often they're the same, but they don't *have* to be (the project
        # may choose to compile in some other components with different
        # licenses and release *that* as released software assets).
      }
    elsif license.match?(/\A[^(]/)
      {
        floss_license_osi_status:
                  {
                    value: CriterionStatus::UNMET, confidence: 1,
                    explanation: I18n.t('detectives.floss_license.not_in_osi_list')
                  }
      }
    else
      # We currently don't handle (...), so don't even guess.
      {}
    end
  end
  # rubocop:enable Metrics/MethodLength
end
# rubocop:enable Metrics/ClassLength
