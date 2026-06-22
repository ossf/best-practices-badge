#URL: =~"^https?://[^\\s]+$"

#Link: {
  url: #URL
  description: string
}

#Justification: {
  description: string
  links?: [...#Link]
}

#UnmetJustification: {
  description: string
  links: [...#Link]
}

#Criterion: {
  result: "met" | "unmet" | "unknown"
  if result != "" {
    if result == "unmet" {
      justification: #UnmetJustification
    }
    if result == "met" {
      justification?: #Justification
    }
  }
}

#NullableCriterion: {
  result: "met" | "unmet" | "unknown" | "na"
  if result != "" {
    if result == "unmet" {
      justification: #UnmetJustification
    }
    if result == "met" {
      justification?: #Justification
    }
    if result == "na" {
      justification: #Justification
    }
  }
}

#PassingCriteria: {
  basics: {
    description_good: #Criterion
    interact: #Criterion
    contribution: #Criterion
    contribution_requirements: #Criterion
    license_expression: string
    floss_license: #Criterion
    floss_license_osi: #Criterion
    license_location: #Criterion
    documentation_basics: #NullableCriterion
    documentation_interface: #NullableCriterion
    sites_https: #Criterion
    discussion: #Criterion
    english: #Criterion
    maintained: #Criterion
  }
  change_control: {
    repo_public: #Criterion
    repo_track: #Criterion
    repo_interim: #Criterion
    repo_distributed: #Criterion
    version_unique: #Criterion
    version_semver: #Criterion
    version_tags: #Criterion
    release_notes: #NullableCriterion
    release_notes_vulns: #NullableCriterion
  }
  reporting: {
    report_process: #Criterion
    report_tracker: #Criterion
    report_responses: #Criterion
    enhancement_responses: #Criterion
    report_archive: #Criterion
    vulnerability_report_process: #Criterion
    vulnerability_report_private: #NullableCriterion
    vulnerability_report_response: #NullableCriterion
  }
  quality: {
    build: #NullableCriterion
    build_common_tools: #NullableCriterion
    build_floss_tools: #NullableCriterion
    test: #Criterion
    test_invocation: #Criterion
    test_most: #Criterion
    test_continuous_integration: #Criterion
    test_policy: #Criterion
    tests_are_added: #Criterion
    tests_documented_added: #Criterion
    warnings: #NullableCriterion
    warnings_fixed: #NullableCriterion
    warnings_strict: #NullableCriterion
  }
  security: {
    know_secure_design: #Criterion
    know_common_errors: #Criterion
    crypography_used: bool
    if crypography_used {
      crypto_published: #Criterion
      crypto_call: #Criterion
      crypto_floss: #Criterion
      crypto_keylength: #Criterion
      crypto_working: #Criterion
      crypto_weaknesses: #Criterion
      crypto_pfs: #Criterion
      crypto_password_storage: #Criterion
      crypto_random: #Criterion
    }
    delivery_mitm: #Criterion
    delivery_unsigned: #Criterion
    vulnerabilities_fixed_60_days: #Criterion
    vulnerabilities_critical_fixed: #Criterion
    no_leaked_credentials: #Criterion
  }
  analysis: {
    static_analysis: #NullableCriterion
    static_analysis_common_vulnerabilities: #NullableCriterion
    static_analysis_fixed: #NullableCriterion
    static_analysis_often: #NullableCriterion
    dynamic_analysis: #Criterion
    dynamic_analysis_unsafe: #NullableCriterion
    dynamic_analysis_enable_assertions: #Criterion
    dynamic_analysis_fixed: #NullableCriterion
  }
}

#SilverCriteria: {
  basics: {
    achieve_passing: bool
    contribution_requirements: #Criterion
    dco: #Criterion
    governance: #Criterion
    code_of_conduct: #Criterion
    roles_responsibilities: #Criterion
    access_continuity: #Criterion
    bus_factor: #Criterion
    documentation_roadmap: #Criterion
    documentation_architecture: #NullableCriterion
    documentation_security: #NullableCriterion
    documentation_quick_start: #NullableCriterion
    documentation_current: #NullableCriterion
    documentation_achievements: #Criterion
    accessibility_best_practices: #NullableCriterion
    internationalization: #NullableCriterion
    sites_password_security: #NullableCriterion
  }
  change_control: {
    maintenance_or_update: #NullableCriterion
  }
  reporting: {
    report_tracker: #NullableCriterion
    vulnerability_report_credit: #NullableCriterion
    vulnerability_response_process: #Criterion
  }
  quality: {
    coding_standards: #NullableCriterion
    coding_standards_enforced: #NullableCriterion
    build_standard_variables: #NullableCriterion
    build_preserve_debug: #NullableCriterion
    build_non_recursive: #NullableCriterion
    build_repeatable: #NullableCriterion
    installation_common: #NullableCriterion
    installation_standard_variables: #NullableCriterion
    installation_development_quick:  #NullableCriterion
    external_dependencies: #NullableCriterion
    dependency_monitoring: #NullableCriterion
    updateable_reused_components: #NullableCriterion
    interfaces_current: #NullableCriterion
    automated_integration_testing: #Criterion
    regression_tests_added50: #NullableCriterion
    test_statement_coverage80: #NullableCriterion
    test_policy_mandated: #NullableCriterion
    tests_documented_added: #NullableCriterion
    warnings_strict: #NullableCriterion
  }
  security: {
    implement_secure_design: #NullableCriterion
    crypto_weaknesses: #NullableCriterion
    crypto_algorithm_agility: #NullableCriterion
    crypto_credential_agility: #NullableCriterion
    crypto_used_network: #NullableCriterion
    crypto_tls12: #NullableCriterion
    crypto_certificate_verification: #NullableCriterion
    crypto_verification_private: #NullableCriterion
    signed_releases: #NullableCriterion
    version_tags_signed: #Criterion
    input_validation: #NullableCriterion
    hardening: #NullableCriterion
    assurance_case: #Criterion
  }
  analysis: {
    static_analysis_common_vulnerabilities: #NullableCriterion
    dynamic_analysis_unsafe: #NullableCriterion
  }
}

#GoldCriteria: {
  basics: {
    achieve_silver: bool
    bus_factor: #Criterion
    contributors_unassociated: #Criterion
    copyright_per_file: #Criterion
    license_per_file: #Criterion
  }
  change_control: {
    repo_distributed: #Criterion
    small_tasks: #Criterion
    require_2FA: #Criterion
    secure_2FA: #Criterion
  }
  quality: {
    code_review_standards: #NullableCriterion
    two_person_review: #NullableCriterion
    build_reproducible: #NullableCriterion
    test_invocation: #Criterion
    test_continuous_integration: #Criterion
    test_statement_coverage90: #NullableCriterion
    test_branch_coverage80: #NullableCriterion
  }
  security: {
    crypto_used_network: #NullableCriterion
    crypto_tls12: #NullableCriterion
    hardened_site: #Criterion
    security_review: #Criterion
    hardening: #NullableCriterion
  }
  analysis: {
    dynamic_analysis: #NullableCriterion
    dynamic_analysis_enable_assertions: #NullableCriterion
  }
}

//// Schema Implementation ////

project_identification: {
  name: string
  description: string
  url: #URL
  primary_repo_url: #URL
  primary_languages: [...string]
  comment?: string
  cpe?: string
  disable_activity_reminder?: bool
}

gold?: #GoldCriteria
silver?: #SilverCriteria
passing: #PassingCriteria

if gold.basics.achieve_silver == true {
  silver: #SilverCriteria
}
