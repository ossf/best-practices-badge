# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[8.1].define(version: 2026_08_03_120000) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "citext"
  enable_extension "pg_catalog.plpgsql"
  enable_extension "pg_stat_statements"

  create_table "additional_rights", force: :cascade do |t|
    t.datetime "created_at", precision: nil, null: false
    t.integer "project_id", null: false
    t.datetime "updated_at", precision: nil, null: false
    t.integer "user_id", null: false
    t.index ["project_id"], name: "index_additional_rights_on_project_id"
    t.index ["user_id", "project_id"], name: "index_additional_rights_on_user_id_and_project_id", unique: true
    t.index ["user_id"], name: "index_additional_rights_on_user_id"
  end

  create_table "bad_passwords", id: false, force: :cascade do |t|
    t.string "forbidden_hash"
    t.index ["forbidden_hash"], name: "index_bad_passwords_on_forbidden_hash"
  end

  create_table "pg_search_documents", id: :serial, force: :cascade do |t|
    t.text "content"
    t.datetime "created_at", precision: nil, null: false
    t.integer "searchable_id"
    t.string "searchable_type"
    t.datetime "updated_at", precision: nil, null: false
    t.index ["searchable_type", "searchable_id"], name: "index_pg_search_documents_on_searchable_type_and_searchable_id"
  end

  create_table "project_stats", id: :serial, force: :cascade do |t|
    t.integer "active_edited_in_progress"
    t.integer "active_edited_projects"
    t.integer "active_in_progress"
    t.integer "active_projects"
    t.integer "additional_rights_entries"
    t.datetime "created_at", precision: nil, null: false
    t.integer "created_since_yesterday", null: false
    t.integer "github_users"
    t.integer "local_users"
    t.integer "percent_1_ge_100"
    t.integer "percent_1_ge_25"
    t.integer "percent_1_ge_50"
    t.integer "percent_1_ge_75"
    t.integer "percent_1_ge_90"
    t.integer "percent_2_ge_100"
    t.integer "percent_2_ge_25"
    t.integer "percent_2_ge_50"
    t.integer "percent_2_ge_75"
    t.integer "percent_2_ge_90"
    t.integer "percent_baseline_1_ge_100"
    t.integer "percent_baseline_1_ge_25"
    t.integer "percent_baseline_1_ge_50"
    t.integer "percent_baseline_1_ge_75"
    t.integer "percent_baseline_1_ge_90"
    t.integer "percent_baseline_2_ge_100"
    t.integer "percent_baseline_2_ge_25"
    t.integer "percent_baseline_2_ge_50"
    t.integer "percent_baseline_2_ge_75"
    t.integer "percent_baseline_2_ge_90"
    t.integer "percent_baseline_3_ge_100"
    t.integer "percent_baseline_3_ge_25"
    t.integer "percent_baseline_3_ge_50"
    t.integer "percent_baseline_3_ge_75"
    t.integer "percent_baseline_3_ge_90"
    t.integer "percent_ge_0", null: false
    t.integer "percent_ge_100", null: false
    t.integer "percent_ge_25", null: false
    t.integer "percent_ge_50", null: false
    t.integer "percent_ge_75", null: false
    t.integer "percent_ge_90", null: false
    t.integer "projects_edited"
    t.integer "projects_with_additional_rights"
    t.integer "reactivated_after_reminder", default: 0, null: false
    t.integer "reminders_sent", default: 0, null: false
    t.datetime "updated_at", precision: nil, null: false
    t.integer "updated_since_yesterday", null: false
    t.integer "users"
    t.integer "users_created_since_yesterday"
    t.integer "users_updated_since_yesterday"
    t.integer "users_with_additional_rights"
    t.integer "users_with_gold_projects"
    t.integer "users_with_multiple_projects"
    t.integer "users_with_passing_projects"
    t.integer "users_with_projects"
    t.integer "users_with_silver_projects"
    t.integer "users_without_projects"
    t.index ["created_at"], name: "index_project_stats_on_created_at"
  end

  create_table "projects", id: :serial, comment: "Best practices criteria results. Integer _status columns: 0=unknown(?), 1=unmet, 2=N/A, 3=met. Paired _justification text columns hold free-text explanations.", force: :cascade do |t|
    t.text "access_continuity_justification"
    t.integer "access_continuity_status", limit: 2, default: 0, null: false
    t.text "accessibility_best_practices_justification"
    t.integer "accessibility_best_practices_status", limit: 2, default: 0, null: false
    t.text "achieve_passing_justification"
    t.integer "achieve_passing_status", limit: 2, default: 0, null: false
    t.text "achieve_silver_justification"
    t.integer "achieve_silver_status", limit: 2, default: 0, null: false
    t.datetime "achieved_baseline_1_at", comment: "Most recently achieved baseline-1; not cleared on loss"
    t.datetime "achieved_baseline_2_at", comment: "Most recently achieved baseline-2; not cleared on loss"
    t.datetime "achieved_baseline_3_at", comment: "Most recently achieved baseline-3; not cleared on loss"
    t.datetime "achieved_gold_at", precision: nil, comment: "Most recently achieved gold; not cleared on loss (compare lost_gold_at)"
    t.datetime "achieved_passing_at", precision: nil, comment: "Most recently achieved passing; not cleared on loss (compare lost_passing_at)"
    t.datetime "achieved_silver_at", precision: nil, comment: "Most recently achieved silver; not cleared on loss (compare lost_silver_at)"
    t.text "assurance_case_justification"
    t.integer "assurance_case_status", limit: 2, default: 0, null: false
    t.text "automated_integration_testing_justification"
    t.integer "automated_integration_testing_status", limit: 2, default: 0, null: false
    t.integer "badge_percentage_0", comment: "Completion percentage (0-100) toward passing badge"
    t.integer "badge_percentage_1", default: 0, comment: "Completion percentage (0-100) toward silver badge"
    t.integer "badge_percentage_2", default: 0, comment: "Completion percentage (0-100) toward gold badge"
    t.integer "badge_percentage_baseline_1", comment: "Completion percentage (0-100) toward baseline-1 badge"
    t.integer "badge_percentage_baseline_2", comment: "Completion percentage (0-100) toward baseline-2 badge"
    t.integer "badge_percentage_baseline_3", comment: "Completion percentage (0-100) toward baseline-3 badge"
    t.date "badge_warning_effective_date", comment: "Date when pending criteria changes take effect (i.e., when the badge will be lost)"
    t.boolean "baseline_1_saved", default: false, null: false, comment: "True after first form edit of baseline-1 criteria; gates first-edit automation"
    t.boolean "baseline_2_saved", default: false, null: false, comment: "True after first form edit of baseline-2 criteria; gates first-edit automation"
    t.boolean "baseline_3_saved", default: false, null: false, comment: "True after first form edit of baseline-3 criteria; gates first-edit automation"
    t.integer "baseline_tiered_percentage", comment: "<100 = in_progress (value = % toward baseline-1); 100-199 = baseline-1 (value-100 = % toward baseline-2); 200-299 = baseline-2 (value-200 = % toward baseline-3); 300 = baseline-3 (same encoding as tiered_percentage)"
    t.text "build_common_tools_justification"
    t.integer "build_common_tools_status", limit: 2, default: 0, null: false
    t.text "build_floss_tools_justification"
    t.integer "build_floss_tools_status", limit: 2, default: 0, null: false
    t.text "build_justification"
    t.text "build_non_recursive_justification"
    t.integer "build_non_recursive_status", limit: 2, default: 0, null: false
    t.text "build_preserve_debug_justification"
    t.integer "build_preserve_debug_status", limit: 2, default: 0, null: false
    t.text "build_repeatable_justification"
    t.integer "build_repeatable_status", limit: 2, default: 0, null: false
    t.text "build_reproducible_justification"
    t.integer "build_reproducible_status", limit: 2, default: 0, null: false
    t.text "build_standard_variables_justification"
    t.integer "build_standard_variables_status", limit: 2, default: 0, null: false
    t.integer "build_status", limit: 2, default: 0, null: false
    t.text "bus_factor_justification"
    t.integer "bus_factor_status", limit: 2, default: 0, null: false
    t.text "code_of_conduct_justification"
    t.integer "code_of_conduct_status", limit: 2, default: 0, null: false
    t.text "code_review_standards_justification"
    t.integer "code_review_standards_status", limit: 2, default: 0, null: false
    t.text "coding_standards_enforced_justification"
    t.integer "coding_standards_enforced_status", limit: 2, default: 0, null: false
    t.text "coding_standards_justification"
    t.integer "coding_standards_status", limit: 2, default: 0, null: false
    t.text "contribution_justification"
    t.text "contribution_requirements_justification"
    t.integer "contribution_requirements_status", limit: 2, default: 0, null: false
    t.integer "contribution_status", limit: 2, default: 0, null: false
    t.text "contributors_unassociated_justification"
    t.integer "contributors_unassociated_status", limit: 2, default: 0, null: false
    t.text "copyright_per_file_justification"
    t.integer "copyright_per_file_status", limit: 2, default: 0, null: false
    t.string "cpe", comment: "Common Platform Enumeration identifier for NVD vulnerability tracking"
    t.datetime "created_at", precision: nil, null: false
    t.text "crypto_algorithm_agility_justification"
    t.integer "crypto_algorithm_agility_status", limit: 2, default: 0, null: false
    t.text "crypto_call_justification"
    t.integer "crypto_call_status", limit: 2, default: 0, null: false
    t.text "crypto_certificate_verification_justification"
    t.integer "crypto_certificate_verification_status", limit: 2, default: 0, null: false
    t.text "crypto_credential_agility_justification"
    t.integer "crypto_credential_agility_status", limit: 2, default: 0, null: false
    t.text "crypto_floss_justification"
    t.integer "crypto_floss_status", limit: 2, default: 0, null: false
    t.text "crypto_keylength_justification"
    t.integer "crypto_keylength_status", limit: 2, default: 0, null: false
    t.text "crypto_password_storage_justification"
    t.integer "crypto_password_storage_status", limit: 2, default: 0, null: false
    t.text "crypto_pfs_justification"
    t.integer "crypto_pfs_status", limit: 2, default: 0, null: false
    t.text "crypto_published_justification"
    t.integer "crypto_published_status", limit: 2, default: 0, null: false
    t.text "crypto_random_justification"
    t.integer "crypto_random_status", limit: 2, default: 0, null: false
    t.text "crypto_tls12_justification"
    t.integer "crypto_tls12_status", limit: 2, default: 0, null: false
    t.text "crypto_used_network_justification"
    t.integer "crypto_used_network_status", limit: 2, default: 0, null: false
    t.text "crypto_verification_private_justification"
    t.integer "crypto_verification_private_status", limit: 2, default: 0, null: false
    t.text "crypto_weaknesses_justification"
    t.integer "crypto_weaknesses_status", limit: 2, default: 0, null: false
    t.text "crypto_working_justification"
    t.integer "crypto_working_status", limit: 2, default: 0, null: false
    t.text "dco_justification"
    t.integer "dco_status", limit: 2, default: 0, null: false
    t.text "delivery_mitm_justification"
    t.integer "delivery_mitm_status", limit: 2, default: 0, null: false
    t.text "delivery_unsigned_justification"
    t.integer "delivery_unsigned_status", limit: 2, default: 0, null: false
    t.text "dependency_monitoring_justification"
    t.integer "dependency_monitoring_status", limit: 2, default: 0, null: false
    t.text "description"
    t.text "description_good_justification"
    t.integer "description_good_status", limit: 2, default: 0, null: false
    t.boolean "disabled_reminders", default: false, null: false
    t.text "discussion_justification"
    t.integer "discussion_status", limit: 2, default: 0, null: false
    t.text "documentation_achievements_justification"
    t.integer "documentation_achievements_status", limit: 2, default: 0, null: false
    t.text "documentation_architecture_justification"
    t.integer "documentation_architecture_status", limit: 2, default: 0, null: false
    t.text "documentation_basics_justification"
    t.integer "documentation_basics_status", limit: 2, default: 0, null: false
    t.text "documentation_current_justification"
    t.integer "documentation_current_status", limit: 2, default: 0, null: false
    t.text "documentation_interface_justification"
    t.integer "documentation_interface_status", limit: 2, default: 0, null: false
    t.text "documentation_quick_start_justification"
    t.integer "documentation_quick_start_status", limit: 2, default: 0, null: false
    t.text "documentation_roadmap_justification"
    t.integer "documentation_roadmap_status", limit: 2, default: 0, null: false
    t.text "documentation_security_justification"
    t.integer "documentation_security_status", limit: 2, default: 0, null: false
    t.text "dynamic_analysis_enable_assertions_justification"
    t.integer "dynamic_analysis_enable_assertions_status", limit: 2, default: 0, null: false
    t.text "dynamic_analysis_fixed_justification"
    t.integer "dynamic_analysis_fixed_status", limit: 2, default: 0, null: false
    t.text "dynamic_analysis_justification"
    t.integer "dynamic_analysis_status", limit: 2, default: 0, null: false
    t.text "dynamic_analysis_unsafe_justification"
    t.integer "dynamic_analysis_unsafe_status", limit: 2, default: 0, null: false
    t.text "english_justification"
    t.integer "english_status", limit: 2, default: 0, null: false
    t.text "enhancement_responses_justification"
    t.integer "enhancement_responses_status", limit: 2, default: 0, null: false
    t.string "entry_locale", limit: 7, default: "en", null: false, comment: "Locale of project description and justification text"
    t.text "external_dependencies_justification"
    t.integer "external_dependencies_status", limit: 2, default: 0, null: false
    t.datetime "first_achieved_baseline_1_at", comment: "First time baseline-1 was achieved"
    t.datetime "first_achieved_baseline_2_at", comment: "First time baseline-2 was achieved"
    t.datetime "first_achieved_baseline_3_at", comment: "First time baseline-3 was achieved"
    t.datetime "first_achieved_gold_at", precision: nil, comment: "First time ever gold was achieved; never reset after badge loss"
    t.datetime "first_achieved_passing_at", precision: nil, comment: "First time ever passing was achieved; never reset after badge loss"
    t.datetime "first_achieved_silver_at", precision: nil, comment: "First time ever silver was achieved; never reset after badge loss"
    t.text "floss_license_justification"
    t.text "floss_license_osi_justification"
    t.integer "floss_license_osi_status", limit: 2, default: 0, null: false
    t.integer "floss_license_status", limit: 2, default: 0, null: false
    t.text "general_comments"
    t.boolean "gold_saved", default: false, null: false, comment: "True after first form edit of gold criteria; gates first-edit automation"
    t.text "governance_justification"
    t.integer "governance_status", limit: 2, default: 0, null: false
    t.text "hardened_site_justification"
    t.integer "hardened_site_status", limit: 2, default: 0, null: false
    t.text "hardening_justification"
    t.integer "hardening_status", limit: 2, default: 0, null: false
    t.string "homepage_url"
    t.text "homepage_url_justification"
    t.string "homepage_url_status", default: "?", null: false, comment: "String (legacy URL field, not the integer enum); '?' = unknown/not evaluated"
    t.text "implement_secure_design_justification"
    t.integer "implement_secure_design_status", limit: 2, default: 0, null: false
    t.string "implementation_languages", default: ""
    t.text "input_validation_justification"
    t.integer "input_validation_status", limit: 2, default: 0, null: false
    t.text "installation_common_justification"
    t.integer "installation_common_status", limit: 2, default: 0, null: false
    t.text "installation_development_quick_justification"
    t.integer "installation_development_quick_status", limit: 2, default: 0, null: false
    t.text "installation_standard_variables_justification"
    t.integer "installation_standard_variables_status", limit: 2, default: 0, null: false
    t.text "interact_justification"
    t.integer "interact_status", limit: 2, default: 0, null: false
    t.text "interfaces_current_justification"
    t.integer "interfaces_current_status", limit: 2, default: 0, null: false
    t.text "internationalization_justification"
    t.integer "internationalization_status", limit: 2, default: 0, null: false
    t.text "know_common_errors_justification"
    t.integer "know_common_errors_status", limit: 2, default: 0, null: false
    t.text "know_secure_design_justification"
    t.integer "know_secure_design_status", limit: 2, default: 0, null: false
    t.datetime "last_loss_sent_at"
    t.datetime "last_reminder_at", precision: nil
    t.datetime "last_warning_sent_at"
    t.string "license"
    t.text "license_location_justification"
    t.integer "license_location_status", limit: 2, default: 0, null: false
    t.text "license_per_file_justification"
    t.integer "license_per_file_status", limit: 2, default: 0, null: false
    t.integer "lock_version", default: 0, comment: "Rails optimistic locking column; incremented on each update to detect concurrent edits"
    t.integer "loss_send_attempts", default: 0, null: false, comment: "Failed attempts to deliver the pending badge-loss notification; reset to 0 when a loss is newly recorded"
    t.datetime "lost_baseline_1_at"
    t.datetime "lost_baseline_2_at"
    t.datetime "lost_baseline_3_at"
    t.datetime "lost_gold_at", precision: nil
    t.datetime "lost_passing_at", precision: nil
    t.datetime "lost_silver_at", precision: nil
    t.text "maintained_justification"
    t.integer "maintained_status", limit: 2, default: 0, null: false
    t.text "maintenance_or_update_justification"
    t.integer "maintenance_or_update_status", limit: 2, default: 0, null: false
    t.string "name"
    t.text "no_leaked_credentials_justification"
    t.integer "no_leaked_credentials_status", limit: 2, default: 0, null: false
    t.text "osps_ac_01_01_justification"
    t.integer "osps_ac_01_01_status", limit: 2, default: 0, null: false
    t.text "osps_ac_02_01_justification"
    t.integer "osps_ac_02_01_status", limit: 2, default: 0, null: false
    t.text "osps_ac_03_01_justification"
    t.integer "osps_ac_03_01_status", limit: 2, default: 0, null: false
    t.text "osps_ac_03_02_justification"
    t.integer "osps_ac_03_02_status", limit: 2, default: 0, null: false
    t.text "osps_ac_04_01_justification"
    t.integer "osps_ac_04_01_status", limit: 2, default: 0, null: false
    t.text "osps_ac_04_02_justification"
    t.integer "osps_ac_04_02_status", limit: 2, default: 0, null: false
    t.text "osps_br_01_01_justification"
    t.integer "osps_br_01_01_status", limit: 2, default: 0, null: false
    t.text "osps_br_01_02_justification"
    t.integer "osps_br_01_02_status", limit: 2, default: 0, null: false
    t.text "osps_br_01_03_justification"
    t.integer "osps_br_01_03_status", limit: 2, default: 0, null: false
    t.text "osps_br_01_04_justification"
    t.integer "osps_br_01_04_status", limit: 2, default: 0, null: false
    t.text "osps_br_02_01_justification"
    t.integer "osps_br_02_01_status", limit: 2, default: 0, null: false
    t.text "osps_br_02_02_justification"
    t.integer "osps_br_02_02_status", limit: 2, default: 0, null: false
    t.text "osps_br_03_01_justification"
    t.integer "osps_br_03_01_status", limit: 2, default: 0, null: false
    t.text "osps_br_03_02_justification"
    t.integer "osps_br_03_02_status", limit: 2, default: 0, null: false
    t.text "osps_br_04_01_justification"
    t.integer "osps_br_04_01_status", limit: 2, default: 0, null: false
    t.text "osps_br_05_01_justification"
    t.integer "osps_br_05_01_status", limit: 2, default: 0, null: false
    t.text "osps_br_06_01_justification"
    t.integer "osps_br_06_01_status", limit: 2, default: 0, null: false
    t.text "osps_br_07_01_justification"
    t.integer "osps_br_07_01_status", limit: 2, default: 0, null: false
    t.text "osps_br_07_02_justification"
    t.integer "osps_br_07_02_status", limit: 2, default: 0, null: false
    t.text "osps_do_01_01_justification"
    t.integer "osps_do_01_01_status", limit: 2, default: 0, null: false
    t.text "osps_do_02_01_justification"
    t.integer "osps_do_02_01_status", limit: 2, default: 0, null: false
    t.text "osps_do_03_01_justification"
    t.integer "osps_do_03_01_status", limit: 2, default: 0, null: false
    t.text "osps_do_03_02_justification"
    t.integer "osps_do_03_02_status", limit: 2, default: 0, null: false
    t.text "osps_do_04_01_justification"
    t.integer "osps_do_04_01_status", limit: 2, default: 0, null: false
    t.text "osps_do_05_01_justification"
    t.integer "osps_do_05_01_status", limit: 2, default: 0, null: false
    t.text "osps_do_06_01_justification"
    t.integer "osps_do_06_01_status", limit: 2, default: 0, null: false
    t.text "osps_do_07_01_justification"
    t.integer "osps_do_07_01_status", limit: 2, default: 0, null: false
    t.text "osps_gv_01_01_justification"
    t.integer "osps_gv_01_01_status", limit: 2, default: 0, null: false
    t.text "osps_gv_01_02_justification"
    t.integer "osps_gv_01_02_status", limit: 2, default: 0, null: false
    t.text "osps_gv_02_01_justification"
    t.integer "osps_gv_02_01_status", limit: 2, default: 0, null: false
    t.text "osps_gv_03_01_justification"
    t.integer "osps_gv_03_01_status", limit: 2, default: 0, null: false
    t.text "osps_gv_03_02_justification"
    t.integer "osps_gv_03_02_status", limit: 2, default: 0, null: false
    t.text "osps_gv_04_01_justification"
    t.integer "osps_gv_04_01_status", limit: 2, default: 0, null: false
    t.text "osps_le_01_01_justification"
    t.integer "osps_le_01_01_status", limit: 2, default: 0, null: false
    t.text "osps_le_02_01_justification"
    t.integer "osps_le_02_01_status", limit: 2, default: 0, null: false
    t.text "osps_le_02_02_justification"
    t.integer "osps_le_02_02_status", limit: 2, default: 0, null: false
    t.text "osps_le_03_01_justification"
    t.integer "osps_le_03_01_status", limit: 2, default: 0, null: false
    t.text "osps_le_03_02_justification"
    t.integer "osps_le_03_02_status", limit: 2, default: 0, null: false
    t.text "osps_qa_01_01_justification"
    t.integer "osps_qa_01_01_status", limit: 2, default: 0, null: false
    t.text "osps_qa_01_02_justification"
    t.integer "osps_qa_01_02_status", limit: 2, default: 0, null: false
    t.text "osps_qa_02_01_justification"
    t.integer "osps_qa_02_01_status", limit: 2, default: 0, null: false
    t.text "osps_qa_02_02_justification"
    t.integer "osps_qa_02_02_status", limit: 2, default: 0, null: false
    t.text "osps_qa_03_01_justification"
    t.integer "osps_qa_03_01_status", limit: 2, default: 0, null: false
    t.text "osps_qa_04_01_justification"
    t.integer "osps_qa_04_01_status", limit: 2, default: 0, null: false
    t.text "osps_qa_04_02_justification"
    t.integer "osps_qa_04_02_status", limit: 2, default: 0, null: false
    t.text "osps_qa_05_01_justification"
    t.integer "osps_qa_05_01_status", limit: 2, default: 0, null: false
    t.text "osps_qa_05_02_justification"
    t.integer "osps_qa_05_02_status", limit: 2, default: 0, null: false
    t.text "osps_qa_06_01_justification"
    t.integer "osps_qa_06_01_status", limit: 2, default: 0, null: false
    t.text "osps_qa_06_02_justification"
    t.integer "osps_qa_06_02_status", limit: 2, default: 0, null: false
    t.text "osps_qa_06_03_justification"
    t.integer "osps_qa_06_03_status", limit: 2, default: 0, null: false
    t.text "osps_qa_07_01_justification"
    t.integer "osps_qa_07_01_status", limit: 2, default: 0, null: false
    t.text "osps_sa_01_01_justification"
    t.integer "osps_sa_01_01_status", limit: 2, default: 0, null: false
    t.text "osps_sa_02_01_justification"
    t.integer "osps_sa_02_01_status", limit: 2, default: 0, null: false
    t.text "osps_sa_03_01_justification"
    t.integer "osps_sa_03_01_status", limit: 2, default: 0, null: false
    t.text "osps_sa_03_02_justification"
    t.integer "osps_sa_03_02_status", limit: 2, default: 0, null: false
    t.text "osps_vm_01_01_justification"
    t.integer "osps_vm_01_01_status", limit: 2, default: 0, null: false
    t.text "osps_vm_02_01_justification"
    t.integer "osps_vm_02_01_status", limit: 2, default: 0, null: false
    t.text "osps_vm_03_01_justification"
    t.integer "osps_vm_03_01_status", limit: 2, default: 0, null: false
    t.text "osps_vm_04_01_justification"
    t.integer "osps_vm_04_01_status", limit: 2, default: 0, null: false
    t.text "osps_vm_04_02_justification"
    t.integer "osps_vm_04_02_status", limit: 2, default: 0, null: false
    t.text "osps_vm_05_01_justification"
    t.integer "osps_vm_05_01_status", limit: 2, default: 0, null: false
    t.text "osps_vm_05_02_justification"
    t.integer "osps_vm_05_02_status", limit: 2, default: 0, null: false
    t.text "osps_vm_05_03_justification"
    t.integer "osps_vm_05_03_status", limit: 2, default: 0, null: false
    t.text "osps_vm_06_01_justification"
    t.integer "osps_vm_06_01_status", limit: 2, default: 0, null: false
    t.text "osps_vm_06_02_justification"
    t.integer "osps_vm_06_02_status", limit: 2, default: 0, null: false
    t.boolean "passing_saved", default: false, null: false, comment: "True after first form edit of passing criteria; gates first-edit automation"
    t.text "regression_tests_added50_justification"
    t.integer "regression_tests_added50_status", limit: 2, default: 0, null: false
    t.text "release_notes_justification"
    t.integer "release_notes_status", limit: 2, default: 0, null: false
    t.text "release_notes_vulns_justification"
    t.integer "release_notes_vulns_status", limit: 2, default: 0, null: false
    t.text "repo_distributed_justification"
    t.integer "repo_distributed_status", limit: 2, default: 0, null: false
    t.text "repo_interim_justification"
    t.integer "repo_interim_status", limit: 2, default: 0, null: false
    t.text "repo_public_justification"
    t.integer "repo_public_status", limit: 2, default: 0, null: false
    t.text "repo_track_justification"
    t.integer "repo_track_status", limit: 2, default: 0, null: false
    t.string "repo_url"
    t.datetime "repo_url_updated_at", precision: nil
    t.text "report_archive_justification"
    t.integer "report_archive_status", limit: 2, default: 0, null: false
    t.text "report_process_justification"
    t.integer "report_process_status", limit: 2, default: 0, null: false
    t.text "report_responses_justification"
    t.integer "report_responses_status", limit: 2, default: 0, null: false
    t.text "report_tracker_justification"
    t.integer "report_tracker_status", limit: 2, default: 0, null: false
    t.text "report_url_justification"
    t.string "report_url_status", default: "?", null: false, comment: "String (legacy URL field, not the integer enum); '?' = unknown/not evaluated"
    t.text "require_2FA_justification"
    t.integer "require_2FA_status", limit: 2, default: 0, null: false
    t.text "roles_responsibilities_justification"
    t.integer "roles_responsibilities_status", limit: 2, default: 0, null: false
    t.text "secure_2FA_justification"
    t.integer "secure_2FA_status", limit: 2, default: 0, null: false
    t.text "security_review_justification"
    t.integer "security_review_status", limit: 2, default: 0, null: false
    t.text "signed_releases_justification"
    t.integer "signed_releases_status", limit: 2, default: 0, null: false
    t.boolean "silver_saved", default: false, null: false, comment: "True after first form edit of silver criteria; gates first-edit automation"
    t.text "sites_https_justification"
    t.integer "sites_https_status", limit: 2, default: 0, null: false
    t.text "sites_password_security_justification"
    t.integer "sites_password_security_status", limit: 2, default: 0, null: false
    t.text "small_tasks_justification"
    t.integer "small_tasks_status", limit: 2, default: 0, null: false
    t.text "static_analysis_common_vulnerabilities_justification"
    t.integer "static_analysis_common_vulnerabilities_status", limit: 2, default: 0, null: false
    t.text "static_analysis_fixed_justification"
    t.integer "static_analysis_fixed_status", limit: 2, default: 0, null: false
    t.text "static_analysis_justification"
    t.text "static_analysis_often_justification"
    t.integer "static_analysis_often_status", limit: 2, default: 0, null: false
    t.integer "static_analysis_status", limit: 2, default: 0, null: false
    t.text "test_branch_coverage80_justification"
    t.integer "test_branch_coverage80_status", limit: 2, default: 0, null: false
    t.text "test_continuous_integration_justification"
    t.integer "test_continuous_integration_status", limit: 2, default: 0, null: false
    t.text "test_invocation_justification"
    t.integer "test_invocation_status", limit: 2, default: 0, null: false
    t.text "test_justification"
    t.text "test_most_justification"
    t.integer "test_most_status", limit: 2, default: 0, null: false
    t.text "test_policy_justification"
    t.text "test_policy_mandated_justification"
    t.integer "test_policy_mandated_status", limit: 2, default: 0, null: false
    t.integer "test_policy_status", limit: 2, default: 0, null: false
    t.text "test_statement_coverage80_justification"
    t.integer "test_statement_coverage80_status", limit: 2, default: 0, null: false
    t.text "test_statement_coverage90_justification"
    t.integer "test_statement_coverage90_status", limit: 2, default: 0, null: false
    t.integer "test_status", limit: 2, default: 0, null: false
    t.text "tests_are_added_justification"
    t.integer "tests_are_added_status", limit: 2, default: 0, null: false
    t.text "tests_documented_added_justification"
    t.integer "tests_documented_added_status", limit: 2, default: 0, null: false
    t.integer "tiered_percentage", comment: "<100 = in_progress (value = % toward passing); 100-199 = passing (value-100 = % toward silver); 200-299 = silver (value-200 = % toward gold); 300 = gold"
    t.text "two_person_review_justification"
    t.integer "two_person_review_status", limit: 2, default: 0, null: false
    t.integer "unreported_badge_loss", default: 0, null: false, comment: "BADGE_LEVELS index of lost metal badge level pending notification email; 0=nothing pending"
    t.integer "unreported_badge_warning", default: 0, null: false, comment: "BADGE_LEVELS index of at-risk metal badge level pending warning email; 0=nothing pending"
    t.integer "unreported_baseline_badge_loss", default: 0, null: false, comment: "BASELINE_BADGE_LEVELS index of lost baseline badge level pending notification email; 0=nothing pending"
    t.integer "unreported_baseline_badge_warning", default: 0, null: false, comment: "BASELINE_BADGE_LEVELS index of at-risk baseline badge level pending warning email; 0=nothing pending"
    t.text "updateable_reused_components_justification"
    t.integer "updateable_reused_components_status", limit: 2, default: 0, null: false
    t.datetime "updated_at", precision: nil, null: false
    t.integer "user_id"
    t.text "version_semver_justification"
    t.integer "version_semver_status", limit: 2, default: 0, null: false
    t.text "version_tags_justification"
    t.text "version_tags_signed_justification"
    t.integer "version_tags_signed_status", limit: 2, default: 0, null: false
    t.integer "version_tags_status", limit: 2, default: 0, null: false
    t.text "version_unique_justification"
    t.integer "version_unique_status", limit: 2, default: 0, null: false
    t.text "vulnerabilities_critical_fixed_justification"
    t.integer "vulnerabilities_critical_fixed_status", limit: 2, default: 0, null: false
    t.text "vulnerabilities_fixed_60_days_justification"
    t.integer "vulnerabilities_fixed_60_days_status", limit: 2, default: 0, null: false
    t.text "vulnerability_report_credit_justification"
    t.integer "vulnerability_report_credit_status", limit: 2, default: 0, null: false
    t.text "vulnerability_report_private_justification"
    t.integer "vulnerability_report_private_status", limit: 2, default: 0, null: false
    t.text "vulnerability_report_process_justification"
    t.integer "vulnerability_report_process_status", limit: 2, default: 0, null: false
    t.text "vulnerability_report_response_justification"
    t.integer "vulnerability_report_response_status", limit: 2, default: 0, null: false
    t.text "vulnerability_response_process_justification"
    t.integer "vulnerability_response_process_status", limit: 2, default: 0, null: false
    t.integer "warning_send_attempts", default: 0, null: false, comment: "Failed attempts to deliver the pending badge-warning notification; reset to 0 when a warning is newly recorded"
    t.text "warnings_fixed_justification"
    t.integer "warnings_fixed_status", limit: 2, default: 0, null: false
    t.text "warnings_justification"
    t.integer "warnings_status", limit: 2, default: 0, null: false
    t.text "warnings_strict_justification"
    t.integer "warnings_strict_status", limit: 2, default: 0, null: false
    t.index ["achieved_gold_at"], name: "index_projects_on_achieved_gold_at"
    t.index ["achieved_passing_at"], name: "index_projects_on_achieved_passing_at"
    t.index ["achieved_silver_at"], name: "index_projects_on_achieved_silver_at"
    t.index ["badge_percentage_0"], name: "index_projects_on_badge_percentage_0"
    t.index ["badge_percentage_1"], name: "index_projects_on_badge_percentage_1"
    t.index ["badge_percentage_2"], name: "index_projects_on_badge_percentage_2"
    t.index ["baseline_tiered_percentage"], name: "index_projects_on_baseline_tiered_percentage"
    t.index ["created_at"], name: "index_projects_on_created_at"
    t.index ["homepage_url"], name: "index_projects_on_homepage_url"
    t.index ["last_reminder_at"], name: "index_projects_on_last_reminder_at"
    t.index ["lost_gold_at"], name: "index_projects_on_lost_gold_at"
    t.index ["lost_passing_at"], name: "index_projects_on_lost_passing_at"
    t.index ["lost_silver_at"], name: "index_projects_on_lost_silver_at"
    t.index ["name"], name: "index_projects_on_name"
    t.index ["repo_url"], name: "index_projects_on_repo_url"
    t.index ["repo_url"], name: "nonempty_repo_urls", unique: true, where: "((repo_url IS NOT NULL) AND ((repo_url)::text <> ''::text))"
    t.index ["tiered_percentage"], name: "index_projects_on_tiered_percentage"
    t.index ["unreported_badge_loss"], name: "index_projects_on_unreported_badge_loss", where: "(unreported_badge_loss > 0)"
    t.index ["unreported_badge_warning"], name: "index_projects_on_unreported_badge_warning", where: "(unreported_badge_warning > 0)"
    t.index ["unreported_baseline_badge_loss"], name: "index_projects_on_unreported_baseline_badge_loss", where: "(unreported_baseline_badge_loss > 0)"
    t.index ["unreported_baseline_badge_warning"], name: "index_projects_on_unreported_baseline_badge_warning", where: "(unreported_baseline_badge_warning > 0)"
    t.index ["updated_at"], name: "index_projects_on_updated_at"
    t.index ["user_id", "created_at"], name: "index_projects_on_user_id_and_created_at"
    t.index ["user_id"], name: "index_projects_on_user_id"
    t.check_constraint "\"require_2FA_status\" >= 0 AND \"require_2FA_status\" <= 3", name: "check_require_2fa_status_range"
    t.check_constraint "\"secure_2FA_status\" >= 0 AND \"secure_2FA_status\" <= 3", name: "check_secure_2fa_status_range"
    t.check_constraint "access_continuity_status >= 0 AND access_continuity_status <= 3", name: "check_access_continuity_status_range"
    t.check_constraint "accessibility_best_practices_status >= 0 AND accessibility_best_practices_status <= 3", name: "check_accessibility_best_practices_status_range"
    t.check_constraint "achieve_passing_status >= 0 AND achieve_passing_status <= 3", name: "check_achieve_passing_status_range"
    t.check_constraint "achieve_silver_status >= 0 AND achieve_silver_status <= 3", name: "check_achieve_silver_status_range"
    t.check_constraint "assurance_case_status >= 0 AND assurance_case_status <= 3", name: "check_assurance_case_status_range"
    t.check_constraint "automated_integration_testing_status >= 0 AND automated_integration_testing_status <= 3", name: "check_automated_integration_testing_status_range"
    t.check_constraint "build_common_tools_status >= 0 AND build_common_tools_status <= 3", name: "check_build_common_tools_status_range"
    t.check_constraint "build_floss_tools_status >= 0 AND build_floss_tools_status <= 3", name: "check_build_floss_tools_status_range"
    t.check_constraint "build_non_recursive_status >= 0 AND build_non_recursive_status <= 3", name: "check_build_non_recursive_status_range"
    t.check_constraint "build_preserve_debug_status >= 0 AND build_preserve_debug_status <= 3", name: "check_build_preserve_debug_status_range"
    t.check_constraint "build_repeatable_status >= 0 AND build_repeatable_status <= 3", name: "check_build_repeatable_status_range"
    t.check_constraint "build_reproducible_status >= 0 AND build_reproducible_status <= 3", name: "check_build_reproducible_status_range"
    t.check_constraint "build_standard_variables_status >= 0 AND build_standard_variables_status <= 3", name: "check_build_standard_variables_status_range"
    t.check_constraint "build_status >= 0 AND build_status <= 3", name: "check_build_status_range"
    t.check_constraint "bus_factor_status >= 0 AND bus_factor_status <= 3", name: "check_bus_factor_status_range"
    t.check_constraint "code_of_conduct_status >= 0 AND code_of_conduct_status <= 3", name: "check_code_of_conduct_status_range"
    t.check_constraint "code_review_standards_status >= 0 AND code_review_standards_status <= 3", name: "check_code_review_standards_status_range"
    t.check_constraint "coding_standards_enforced_status >= 0 AND coding_standards_enforced_status <= 3", name: "check_coding_standards_enforced_status_range"
    t.check_constraint "coding_standards_status >= 0 AND coding_standards_status <= 3", name: "check_coding_standards_status_range"
    t.check_constraint "contribution_requirements_status >= 0 AND contribution_requirements_status <= 3", name: "check_contribution_requirements_status_range"
    t.check_constraint "contribution_status >= 0 AND contribution_status <= 3", name: "check_contribution_status_range"
    t.check_constraint "contributors_unassociated_status >= 0 AND contributors_unassociated_status <= 3", name: "check_contributors_unassociated_status_range"
    t.check_constraint "copyright_per_file_status >= 0 AND copyright_per_file_status <= 3", name: "check_copyright_per_file_status_range"
    t.check_constraint "crypto_algorithm_agility_status >= 0 AND crypto_algorithm_agility_status <= 3", name: "check_crypto_algorithm_agility_status_range"
    t.check_constraint "crypto_call_status >= 0 AND crypto_call_status <= 3", name: "check_crypto_call_status_range"
    t.check_constraint "crypto_certificate_verification_status >= 0 AND crypto_certificate_verification_status <= 3", name: "check_crypto_certificate_verification_status_range"
    t.check_constraint "crypto_credential_agility_status >= 0 AND crypto_credential_agility_status <= 3", name: "check_crypto_credential_agility_status_range"
    t.check_constraint "crypto_floss_status >= 0 AND crypto_floss_status <= 3", name: "check_crypto_floss_status_range"
    t.check_constraint "crypto_keylength_status >= 0 AND crypto_keylength_status <= 3", name: "check_crypto_keylength_status_range"
    t.check_constraint "crypto_password_storage_status >= 0 AND crypto_password_storage_status <= 3", name: "check_crypto_password_storage_status_range"
    t.check_constraint "crypto_pfs_status >= 0 AND crypto_pfs_status <= 3", name: "check_crypto_pfs_status_range"
    t.check_constraint "crypto_published_status >= 0 AND crypto_published_status <= 3", name: "check_crypto_published_status_range"
    t.check_constraint "crypto_random_status >= 0 AND crypto_random_status <= 3", name: "check_crypto_random_status_range"
    t.check_constraint "crypto_tls12_status >= 0 AND crypto_tls12_status <= 3", name: "check_crypto_tls12_status_range"
    t.check_constraint "crypto_used_network_status >= 0 AND crypto_used_network_status <= 3", name: "check_crypto_used_network_status_range"
    t.check_constraint "crypto_verification_private_status >= 0 AND crypto_verification_private_status <= 3", name: "check_crypto_verification_private_status_range"
    t.check_constraint "crypto_weaknesses_status >= 0 AND crypto_weaknesses_status <= 3", name: "check_crypto_weaknesses_status_range"
    t.check_constraint "crypto_working_status >= 0 AND crypto_working_status <= 3", name: "check_crypto_working_status_range"
    t.check_constraint "dco_status >= 0 AND dco_status <= 3", name: "check_dco_status_range"
    t.check_constraint "delivery_mitm_status >= 0 AND delivery_mitm_status <= 3", name: "check_delivery_mitm_status_range"
    t.check_constraint "delivery_unsigned_status >= 0 AND delivery_unsigned_status <= 3", name: "check_delivery_unsigned_status_range"
    t.check_constraint "dependency_monitoring_status >= 0 AND dependency_monitoring_status <= 3", name: "check_dependency_monitoring_status_range"
    t.check_constraint "description_good_status >= 0 AND description_good_status <= 3", name: "check_description_good_status_range"
    t.check_constraint "discussion_status >= 0 AND discussion_status <= 3", name: "check_discussion_status_range"
    t.check_constraint "documentation_achievements_status >= 0 AND documentation_achievements_status <= 3", name: "check_documentation_achievements_status_range"
    t.check_constraint "documentation_architecture_status >= 0 AND documentation_architecture_status <= 3", name: "check_documentation_architecture_status_range"
    t.check_constraint "documentation_basics_status >= 0 AND documentation_basics_status <= 3", name: "check_documentation_basics_status_range"
    t.check_constraint "documentation_current_status >= 0 AND documentation_current_status <= 3", name: "check_documentation_current_status_range"
    t.check_constraint "documentation_interface_status >= 0 AND documentation_interface_status <= 3", name: "check_documentation_interface_status_range"
    t.check_constraint "documentation_quick_start_status >= 0 AND documentation_quick_start_status <= 3", name: "check_documentation_quick_start_status_range"
    t.check_constraint "documentation_roadmap_status >= 0 AND documentation_roadmap_status <= 3", name: "check_documentation_roadmap_status_range"
    t.check_constraint "documentation_security_status >= 0 AND documentation_security_status <= 3", name: "check_documentation_security_status_range"
    t.check_constraint "dynamic_analysis_enable_assertions_status >= 0 AND dynamic_analysis_enable_assertions_status <= 3", name: "check_dynamic_analysis_enable_assertions_status_range"
    t.check_constraint "dynamic_analysis_fixed_status >= 0 AND dynamic_analysis_fixed_status <= 3", name: "check_dynamic_analysis_fixed_status_range"
    t.check_constraint "dynamic_analysis_status >= 0 AND dynamic_analysis_status <= 3", name: "check_dynamic_analysis_status_range"
    t.check_constraint "dynamic_analysis_unsafe_status >= 0 AND dynamic_analysis_unsafe_status <= 3", name: "check_dynamic_analysis_unsafe_status_range"
    t.check_constraint "english_status >= 0 AND english_status <= 3", name: "check_english_status_range"
    t.check_constraint "enhancement_responses_status >= 0 AND enhancement_responses_status <= 3", name: "check_enhancement_responses_status_range"
    t.check_constraint "external_dependencies_status >= 0 AND external_dependencies_status <= 3", name: "check_external_dependencies_status_range"
    t.check_constraint "floss_license_osi_status >= 0 AND floss_license_osi_status <= 3", name: "check_floss_license_osi_status_range"
    t.check_constraint "floss_license_status >= 0 AND floss_license_status <= 3", name: "check_floss_license_status_range"
    t.check_constraint "governance_status >= 0 AND governance_status <= 3", name: "check_governance_status_range"
    t.check_constraint "hardened_site_status >= 0 AND hardened_site_status <= 3", name: "check_hardened_site_status_range"
    t.check_constraint "hardening_status >= 0 AND hardening_status <= 3", name: "check_hardening_status_range"
    t.check_constraint "implement_secure_design_status >= 0 AND implement_secure_design_status <= 3", name: "check_implement_secure_design_status_range"
    t.check_constraint "input_validation_status >= 0 AND input_validation_status <= 3", name: "check_input_validation_status_range"
    t.check_constraint "installation_common_status >= 0 AND installation_common_status <= 3", name: "check_installation_common_status_range"
    t.check_constraint "installation_development_quick_status >= 0 AND installation_development_quick_status <= 3", name: "check_installation_development_quick_status_range"
    t.check_constraint "installation_standard_variables_status >= 0 AND installation_standard_variables_status <= 3", name: "check_installation_standard_variables_status_range"
    t.check_constraint "interact_status >= 0 AND interact_status <= 3", name: "check_interact_status_range"
    t.check_constraint "interfaces_current_status >= 0 AND interfaces_current_status <= 3", name: "check_interfaces_current_status_range"
    t.check_constraint "internationalization_status >= 0 AND internationalization_status <= 3", name: "check_internationalization_status_range"
    t.check_constraint "know_common_errors_status >= 0 AND know_common_errors_status <= 3", name: "check_know_common_errors_status_range"
    t.check_constraint "know_secure_design_status >= 0 AND know_secure_design_status <= 3", name: "check_know_secure_design_status_range"
    t.check_constraint "license_location_status >= 0 AND license_location_status <= 3", name: "check_license_location_status_range"
    t.check_constraint "license_per_file_status >= 0 AND license_per_file_status <= 3", name: "check_license_per_file_status_range"
    t.check_constraint "maintained_status >= 0 AND maintained_status <= 3", name: "check_maintained_status_range"
    t.check_constraint "maintenance_or_update_status >= 0 AND maintenance_or_update_status <= 3", name: "check_maintenance_or_update_status_range"
    t.check_constraint "no_leaked_credentials_status >= 0 AND no_leaked_credentials_status <= 3", name: "check_no_leaked_credentials_status_range"
    t.check_constraint "osps_ac_01_01_status >= 0 AND osps_ac_01_01_status <= 3", name: "check_osps_ac_01_01_status_range"
    t.check_constraint "osps_ac_02_01_status >= 0 AND osps_ac_02_01_status <= 3", name: "check_osps_ac_02_01_status_range"
    t.check_constraint "osps_ac_03_01_status >= 0 AND osps_ac_03_01_status <= 3", name: "check_osps_ac_03_01_status_range"
    t.check_constraint "osps_ac_03_02_status >= 0 AND osps_ac_03_02_status <= 3", name: "check_osps_ac_03_02_status_range"
    t.check_constraint "osps_ac_04_01_status >= 0 AND osps_ac_04_01_status <= 3", name: "check_osps_ac_04_01_status_range"
    t.check_constraint "osps_ac_04_02_status >= 0 AND osps_ac_04_02_status <= 3", name: "check_osps_ac_04_02_status_range"
    t.check_constraint "osps_br_01_01_status >= 0 AND osps_br_01_01_status <= 3", name: "check_osps_br_01_01_status_range"
    t.check_constraint "osps_br_01_02_status >= 0 AND osps_br_01_02_status <= 3", name: "check_osps_br_01_02_status_range"
    t.check_constraint "osps_br_02_01_status >= 0 AND osps_br_02_01_status <= 3", name: "check_osps_br_02_01_status_range"
    t.check_constraint "osps_br_02_02_status >= 0 AND osps_br_02_02_status <= 3", name: "check_osps_br_02_02_status_range"
    t.check_constraint "osps_br_03_01_status >= 0 AND osps_br_03_01_status <= 3", name: "check_osps_br_03_01_status_range"
    t.check_constraint "osps_br_03_02_status >= 0 AND osps_br_03_02_status <= 3", name: "check_osps_br_03_02_status_range"
    t.check_constraint "osps_br_04_01_status >= 0 AND osps_br_04_01_status <= 3", name: "check_osps_br_04_01_status_range"
    t.check_constraint "osps_br_05_01_status >= 0 AND osps_br_05_01_status <= 3", name: "check_osps_br_05_01_status_range"
    t.check_constraint "osps_br_06_01_status >= 0 AND osps_br_06_01_status <= 3", name: "check_osps_br_06_01_status_range"
    t.check_constraint "osps_br_07_01_status >= 0 AND osps_br_07_01_status <= 3", name: "check_osps_br_07_01_status_range"
    t.check_constraint "osps_br_07_02_status >= 0 AND osps_br_07_02_status <= 3", name: "check_osps_br_07_02_status_range"
    t.check_constraint "osps_do_01_01_status >= 0 AND osps_do_01_01_status <= 3", name: "check_osps_do_01_01_status_range"
    t.check_constraint "osps_do_02_01_status >= 0 AND osps_do_02_01_status <= 3", name: "check_osps_do_02_01_status_range"
    t.check_constraint "osps_do_03_01_status >= 0 AND osps_do_03_01_status <= 3", name: "check_osps_do_03_01_status_range"
    t.check_constraint "osps_do_03_02_status >= 0 AND osps_do_03_02_status <= 3", name: "check_osps_do_03_02_status_range"
    t.check_constraint "osps_do_04_01_status >= 0 AND osps_do_04_01_status <= 3", name: "check_osps_do_04_01_status_range"
    t.check_constraint "osps_do_05_01_status >= 0 AND osps_do_05_01_status <= 3", name: "check_osps_do_05_01_status_range"
    t.check_constraint "osps_do_06_01_status >= 0 AND osps_do_06_01_status <= 3", name: "check_osps_do_06_01_status_range"
    t.check_constraint "osps_gv_01_01_status >= 0 AND osps_gv_01_01_status <= 3", name: "check_osps_gv_01_01_status_range"
    t.check_constraint "osps_gv_01_02_status >= 0 AND osps_gv_01_02_status <= 3", name: "check_osps_gv_01_02_status_range"
    t.check_constraint "osps_gv_02_01_status >= 0 AND osps_gv_02_01_status <= 3", name: "check_osps_gv_02_01_status_range"
    t.check_constraint "osps_gv_03_01_status >= 0 AND osps_gv_03_01_status <= 3", name: "check_osps_gv_03_01_status_range"
    t.check_constraint "osps_gv_03_02_status >= 0 AND osps_gv_03_02_status <= 3", name: "check_osps_gv_03_02_status_range"
    t.check_constraint "osps_gv_04_01_status >= 0 AND osps_gv_04_01_status <= 3", name: "check_osps_gv_04_01_status_range"
    t.check_constraint "osps_le_01_01_status >= 0 AND osps_le_01_01_status <= 3", name: "check_osps_le_01_01_status_range"
    t.check_constraint "osps_le_02_01_status >= 0 AND osps_le_02_01_status <= 3", name: "check_osps_le_02_01_status_range"
    t.check_constraint "osps_le_02_02_status >= 0 AND osps_le_02_02_status <= 3", name: "check_osps_le_02_02_status_range"
    t.check_constraint "osps_le_03_01_status >= 0 AND osps_le_03_01_status <= 3", name: "check_osps_le_03_01_status_range"
    t.check_constraint "osps_le_03_02_status >= 0 AND osps_le_03_02_status <= 3", name: "check_osps_le_03_02_status_range"
    t.check_constraint "osps_qa_01_01_status >= 0 AND osps_qa_01_01_status <= 3", name: "check_osps_qa_01_01_status_range"
    t.check_constraint "osps_qa_01_02_status >= 0 AND osps_qa_01_02_status <= 3", name: "check_osps_qa_01_02_status_range"
    t.check_constraint "osps_qa_02_01_status >= 0 AND osps_qa_02_01_status <= 3", name: "check_osps_qa_02_01_status_range"
    t.check_constraint "osps_qa_02_02_status >= 0 AND osps_qa_02_02_status <= 3", name: "check_osps_qa_02_02_status_range"
    t.check_constraint "osps_qa_03_01_status >= 0 AND osps_qa_03_01_status <= 3", name: "check_osps_qa_03_01_status_range"
    t.check_constraint "osps_qa_04_01_status >= 0 AND osps_qa_04_01_status <= 3", name: "check_osps_qa_04_01_status_range"
    t.check_constraint "osps_qa_04_02_status >= 0 AND osps_qa_04_02_status <= 3", name: "check_osps_qa_04_02_status_range"
    t.check_constraint "osps_qa_05_01_status >= 0 AND osps_qa_05_01_status <= 3", name: "check_osps_qa_05_01_status_range"
    t.check_constraint "osps_qa_05_02_status >= 0 AND osps_qa_05_02_status <= 3", name: "check_osps_qa_05_02_status_range"
    t.check_constraint "osps_qa_06_01_status >= 0 AND osps_qa_06_01_status <= 3", name: "check_osps_qa_06_01_status_range"
    t.check_constraint "osps_qa_06_02_status >= 0 AND osps_qa_06_02_status <= 3", name: "check_osps_qa_06_02_status_range"
    t.check_constraint "osps_qa_06_03_status >= 0 AND osps_qa_06_03_status <= 3", name: "check_osps_qa_06_03_status_range"
    t.check_constraint "osps_qa_07_01_status >= 0 AND osps_qa_07_01_status <= 3", name: "check_osps_qa_07_01_status_range"
    t.check_constraint "osps_sa_01_01_status >= 0 AND osps_sa_01_01_status <= 3", name: "check_osps_sa_01_01_status_range"
    t.check_constraint "osps_sa_02_01_status >= 0 AND osps_sa_02_01_status <= 3", name: "check_osps_sa_02_01_status_range"
    t.check_constraint "osps_sa_03_01_status >= 0 AND osps_sa_03_01_status <= 3", name: "check_osps_sa_03_01_status_range"
    t.check_constraint "osps_sa_03_02_status >= 0 AND osps_sa_03_02_status <= 3", name: "check_osps_sa_03_02_status_range"
    t.check_constraint "osps_vm_01_01_status >= 0 AND osps_vm_01_01_status <= 3", name: "check_osps_vm_01_01_status_range"
    t.check_constraint "osps_vm_02_01_status >= 0 AND osps_vm_02_01_status <= 3", name: "check_osps_vm_02_01_status_range"
    t.check_constraint "osps_vm_03_01_status >= 0 AND osps_vm_03_01_status <= 3", name: "check_osps_vm_03_01_status_range"
    t.check_constraint "osps_vm_04_01_status >= 0 AND osps_vm_04_01_status <= 3", name: "check_osps_vm_04_01_status_range"
    t.check_constraint "osps_vm_04_02_status >= 0 AND osps_vm_04_02_status <= 3", name: "check_osps_vm_04_02_status_range"
    t.check_constraint "osps_vm_05_01_status >= 0 AND osps_vm_05_01_status <= 3", name: "check_osps_vm_05_01_status_range"
    t.check_constraint "osps_vm_05_02_status >= 0 AND osps_vm_05_02_status <= 3", name: "check_osps_vm_05_02_status_range"
    t.check_constraint "osps_vm_05_03_status >= 0 AND osps_vm_05_03_status <= 3", name: "check_osps_vm_05_03_status_range"
    t.check_constraint "osps_vm_06_01_status >= 0 AND osps_vm_06_01_status <= 3", name: "check_osps_vm_06_01_status_range"
    t.check_constraint "osps_vm_06_02_status >= 0 AND osps_vm_06_02_status <= 3", name: "check_osps_vm_06_02_status_range"
    t.check_constraint "regression_tests_added50_status >= 0 AND regression_tests_added50_status <= 3", name: "check_regression_tests_added50_status_range"
    t.check_constraint "release_notes_status >= 0 AND release_notes_status <= 3", name: "check_release_notes_status_range"
    t.check_constraint "release_notes_vulns_status >= 0 AND release_notes_vulns_status <= 3", name: "check_release_notes_vulns_status_range"
    t.check_constraint "repo_distributed_status >= 0 AND repo_distributed_status <= 3", name: "check_repo_distributed_status_range"
    t.check_constraint "repo_interim_status >= 0 AND repo_interim_status <= 3", name: "check_repo_interim_status_range"
    t.check_constraint "repo_public_status >= 0 AND repo_public_status <= 3", name: "check_repo_public_status_range"
    t.check_constraint "repo_track_status >= 0 AND repo_track_status <= 3", name: "check_repo_track_status_range"
    t.check_constraint "report_archive_status >= 0 AND report_archive_status <= 3", name: "check_report_archive_status_range"
    t.check_constraint "report_process_status >= 0 AND report_process_status <= 3", name: "check_report_process_status_range"
    t.check_constraint "report_responses_status >= 0 AND report_responses_status <= 3", name: "check_report_responses_status_range"
    t.check_constraint "report_tracker_status >= 0 AND report_tracker_status <= 3", name: "check_report_tracker_status_range"
    t.check_constraint "roles_responsibilities_status >= 0 AND roles_responsibilities_status <= 3", name: "check_roles_responsibilities_status_range"
    t.check_constraint "security_review_status >= 0 AND security_review_status <= 3", name: "check_security_review_status_range"
    t.check_constraint "signed_releases_status >= 0 AND signed_releases_status <= 3", name: "check_signed_releases_status_range"
    t.check_constraint "sites_https_status >= 0 AND sites_https_status <= 3", name: "check_sites_https_status_range"
    t.check_constraint "sites_password_security_status >= 0 AND sites_password_security_status <= 3", name: "check_sites_password_security_status_range"
    t.check_constraint "small_tasks_status >= 0 AND small_tasks_status <= 3", name: "check_small_tasks_status_range"
    t.check_constraint "static_analysis_common_vulnerabilities_status >= 0 AND static_analysis_common_vulnerabilities_status <= 3", name: "check_static_analysis_common_vulnerabilities_status_range"
    t.check_constraint "static_analysis_fixed_status >= 0 AND static_analysis_fixed_status <= 3", name: "check_static_analysis_fixed_status_range"
    t.check_constraint "static_analysis_often_status >= 0 AND static_analysis_often_status <= 3", name: "check_static_analysis_often_status_range"
    t.check_constraint "static_analysis_status >= 0 AND static_analysis_status <= 3", name: "check_static_analysis_status_range"
    t.check_constraint "test_branch_coverage80_status >= 0 AND test_branch_coverage80_status <= 3", name: "check_test_branch_coverage80_status_range"
    t.check_constraint "test_continuous_integration_status >= 0 AND test_continuous_integration_status <= 3", name: "check_test_continuous_integration_status_range"
    t.check_constraint "test_invocation_status >= 0 AND test_invocation_status <= 3", name: "check_test_invocation_status_range"
    t.check_constraint "test_most_status >= 0 AND test_most_status <= 3", name: "check_test_most_status_range"
    t.check_constraint "test_policy_mandated_status >= 0 AND test_policy_mandated_status <= 3", name: "check_test_policy_mandated_status_range"
    t.check_constraint "test_policy_status >= 0 AND test_policy_status <= 3", name: "check_test_policy_status_range"
    t.check_constraint "test_statement_coverage80_status >= 0 AND test_statement_coverage80_status <= 3", name: "check_test_statement_coverage80_status_range"
    t.check_constraint "test_statement_coverage90_status >= 0 AND test_statement_coverage90_status <= 3", name: "check_test_statement_coverage90_status_range"
    t.check_constraint "test_status >= 0 AND test_status <= 3", name: "check_test_status_range"
    t.check_constraint "tests_are_added_status >= 0 AND tests_are_added_status <= 3", name: "check_tests_are_added_status_range"
    t.check_constraint "tests_documented_added_status >= 0 AND tests_documented_added_status <= 3", name: "check_tests_documented_added_status_range"
    t.check_constraint "two_person_review_status >= 0 AND two_person_review_status <= 3", name: "check_two_person_review_status_range"
    t.check_constraint "updateable_reused_components_status >= 0 AND updateable_reused_components_status <= 3", name: "check_updateable_reused_components_status_range"
    t.check_constraint "version_semver_status >= 0 AND version_semver_status <= 3", name: "check_version_semver_status_range"
    t.check_constraint "version_tags_signed_status >= 0 AND version_tags_signed_status <= 3", name: "check_version_tags_signed_status_range"
    t.check_constraint "version_tags_status >= 0 AND version_tags_status <= 3", name: "check_version_tags_status_range"
    t.check_constraint "version_unique_status >= 0 AND version_unique_status <= 3", name: "check_version_unique_status_range"
    t.check_constraint "vulnerabilities_critical_fixed_status >= 0 AND vulnerabilities_critical_fixed_status <= 3", name: "check_vulnerabilities_critical_fixed_status_range"
    t.check_constraint "vulnerabilities_fixed_60_days_status >= 0 AND vulnerabilities_fixed_60_days_status <= 3", name: "check_vulnerabilities_fixed_60_days_status_range"
    t.check_constraint "vulnerability_report_credit_status >= 0 AND vulnerability_report_credit_status <= 3", name: "check_vulnerability_report_credit_status_range"
    t.check_constraint "vulnerability_report_private_status >= 0 AND vulnerability_report_private_status <= 3", name: "check_vulnerability_report_private_status_range"
    t.check_constraint "vulnerability_report_process_status >= 0 AND vulnerability_report_process_status <= 3", name: "check_vulnerability_report_process_status_range"
    t.check_constraint "vulnerability_report_response_status >= 0 AND vulnerability_report_response_status <= 3", name: "check_vulnerability_report_response_status_range"
    t.check_constraint "vulnerability_response_process_status >= 0 AND vulnerability_response_process_status <= 3", name: "check_vulnerability_response_process_status_range"
    t.check_constraint "warnings_fixed_status >= 0 AND warnings_fixed_status <= 3", name: "check_warnings_fixed_status_range"
    t.check_constraint "warnings_status >= 0 AND warnings_status <= 3", name: "check_warnings_status_range"
    t.check_constraint "warnings_strict_status >= 0 AND warnings_strict_status <= 3", name: "check_warnings_strict_status_range"
  end

  create_table "solid_queue_blocked_executions", force: :cascade do |t|
    t.string "concurrency_key", null: false
    t.datetime "created_at", null: false
    t.datetime "expires_at", null: false
    t.bigint "job_id", null: false
    t.integer "priority", default: 0, null: false
    t.string "queue_name", null: false
    t.index ["concurrency_key", "priority", "job_id"], name: "index_solid_queue_blocked_executions_for_release"
    t.index ["expires_at", "concurrency_key"], name: "index_solid_queue_blocked_executions_for_maintenance"
    t.index ["job_id"], name: "index_solid_queue_blocked_executions_on_job_id", unique: true
  end

  create_table "solid_queue_claimed_executions", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "job_id", null: false
    t.bigint "process_id"
    t.index ["job_id"], name: "index_solid_queue_claimed_executions_on_job_id", unique: true
    t.index ["process_id", "job_id"], name: "index_solid_queue_claimed_executions_on_process_id_and_job_id"
  end

  create_table "solid_queue_failed_executions", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.text "error"
    t.bigint "job_id", null: false
    t.index ["job_id"], name: "index_solid_queue_failed_executions_on_job_id", unique: true
  end

  create_table "solid_queue_jobs", force: :cascade do |t|
    t.string "active_job_id"
    t.text "arguments"
    t.string "class_name", null: false
    t.string "concurrency_key"
    t.datetime "created_at", null: false
    t.datetime "finished_at"
    t.integer "priority", default: 0, null: false
    t.string "queue_name", null: false
    t.datetime "scheduled_at"
    t.datetime "updated_at", null: false
    t.index ["active_job_id"], name: "index_solid_queue_jobs_on_active_job_id"
    t.index ["class_name"], name: "index_solid_queue_jobs_on_class_name"
    t.index ["finished_at"], name: "index_solid_queue_jobs_on_finished_at"
    t.index ["queue_name", "finished_at"], name: "index_solid_queue_jobs_for_filtering"
    t.index ["scheduled_at", "finished_at"], name: "index_solid_queue_jobs_for_alerting"
  end

  create_table "solid_queue_pauses", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "queue_name", null: false
    t.index ["queue_name"], name: "index_solid_queue_pauses_on_queue_name", unique: true
  end

  create_table "solid_queue_processes", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "hostname"
    t.string "kind", null: false
    t.datetime "last_heartbeat_at", null: false
    t.text "metadata"
    t.string "name", null: false
    t.integer "pid", null: false
    t.bigint "supervisor_id"
    t.index ["last_heartbeat_at"], name: "index_solid_queue_processes_on_last_heartbeat_at"
    t.index ["name", "supervisor_id"], name: "index_solid_queue_processes_on_name_and_supervisor_id", unique: true
    t.index ["supervisor_id"], name: "index_solid_queue_processes_on_supervisor_id"
  end

  create_table "solid_queue_ready_executions", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "job_id", null: false
    t.integer "priority", default: 0, null: false
    t.string "queue_name", null: false
    t.index ["job_id"], name: "index_solid_queue_ready_executions_on_job_id", unique: true
    t.index ["priority", "job_id"], name: "index_solid_queue_poll_all"
    t.index ["queue_name", "priority", "job_id"], name: "index_solid_queue_poll_by_queue"
  end

  create_table "solid_queue_recurring_executions", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "job_id", null: false
    t.datetime "run_at", null: false
    t.string "task_key", null: false
    t.index ["job_id"], name: "index_solid_queue_recurring_executions_on_job_id", unique: true
    t.index ["task_key", "run_at"], name: "index_solid_queue_recurring_executions_on_task_key_and_run_at", unique: true
  end

  create_table "solid_queue_recurring_tasks", force: :cascade do |t|
    t.text "arguments"
    t.string "class_name"
    t.string "command", limit: 2048
    t.datetime "created_at", null: false
    t.text "description"
    t.string "key", null: false
    t.integer "priority", default: 0
    t.string "queue_name"
    t.string "schedule", null: false
    t.boolean "static", default: true, null: false
    t.datetime "updated_at", null: false
    t.index ["key"], name: "index_solid_queue_recurring_tasks_on_key", unique: true
    t.index ["static"], name: "index_solid_queue_recurring_tasks_on_static"
  end

  create_table "solid_queue_scheduled_executions", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "job_id", null: false
    t.integer "priority", default: 0, null: false
    t.string "queue_name", null: false
    t.datetime "scheduled_at", null: false
    t.index ["job_id"], name: "index_solid_queue_scheduled_executions_on_job_id", unique: true
    t.index ["scheduled_at", "priority", "job_id"], name: "index_solid_queue_dispatch_all"
  end

  create_table "solid_queue_semaphores", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.datetime "expires_at", null: false
    t.string "key", null: false
    t.datetime "updated_at", null: false
    t.integer "value", default: 1, null: false
    t.index ["expires_at"], name: "index_solid_queue_semaphores_on_expires_at"
    t.index ["key", "value"], name: "index_solid_queue_semaphores_on_key_and_value"
    t.index ["key"], name: "index_solid_queue_semaphores_on_key", unique: true
  end

  create_table "users", id: :serial, force: :cascade do |t|
    t.boolean "activated", default: false
    t.datetime "activated_at", precision: nil
    t.string "activation_digest"
    t.datetime "activation_email_sent_at"
    t.boolean "blocked", default: false, null: false
    t.text "blocked_rationale"
    t.datetime "can_login_starting_at", precision: nil
    t.datetime "created_at", precision: nil, null: false
    t.string "email_bidx", comment: "HMAC blind index for encrypted-email lookup without decrypting"
    t.string "encrypted_email", comment: "AES-256-GCM encrypted email address"
    t.string "encrypted_email_iv", comment: "Initialization vector (IV) for AES-256-GCM email encryption"
    t.boolean "important_notifications", default: true, null: false
    t.datetime "last_login_at", precision: nil
    t.string "name"
    t.string "nickname"
    t.boolean "notification_emails", default: true, null: false
    t.string "password_digest"
    t.string "preferred_locale", default: "en"
    t.string "provider", null: false, comment: "'local' for password-based accounts; OAuth provider name (e.g., 'github') for OAuth accounts"
    t.string "remember_digest"
    t.string "reset_digest"
    t.datetime "reset_sent_at", precision: nil
    t.string "role", comment: "'admin' for administrators; blank/nil for normal users"
    t.string "secret_token"
    t.string "uid", comment: "OAuth provider's unique user ID; blank for local (password-based) accounts"
    t.datetime "updated_at", precision: nil, null: false
    t.boolean "use_gravatar", default: false, null: false
    t.string "validation_code"
    t.index ["created_at"], name: "index_users_on_created_at_local", where: "((provider)::text = 'local'::text)"
    t.index ["email_bidx"], name: "email_local_unique_bidx", unique: true, where: "((provider)::text = 'local'::text)"
    t.index ["email_bidx"], name: "index_users_on_email_bidx"
    t.index ["last_login_at"], name: "index_users_on_last_login_at"
    t.index ["uid"], name: "index_users_on_uid"
  end

  create_table "versions", id: :serial, force: :cascade do |t|
    t.datetime "created_at", precision: nil
    t.string "event", null: false
    t.integer "item_id", null: false
    t.string "item_type", null: false
    t.jsonb "object"
    t.string "whodunnit"
    t.index ["item_type", "item_id"], name: "index_versions_on_item_type_and_item_id"
  end

  add_foreign_key "additional_rights", "projects"
  add_foreign_key "additional_rights", "users"
  add_foreign_key "projects", "users"
  add_foreign_key "solid_queue_blocked_executions", "solid_queue_jobs", column: "job_id", on_delete: :cascade
  add_foreign_key "solid_queue_claimed_executions", "solid_queue_jobs", column: "job_id", on_delete: :cascade
  add_foreign_key "solid_queue_failed_executions", "solid_queue_jobs", column: "job_id", on_delete: :cascade
  add_foreign_key "solid_queue_ready_executions", "solid_queue_jobs", column: "job_id", on_delete: :cascade
  add_foreign_key "solid_queue_recurring_executions", "solid_queue_jobs", column: "job_id", on_delete: :cascade
  add_foreign_key "solid_queue_scheduled_executions", "solid_queue_jobs", column: "job_id", on_delete: :cascade
end
