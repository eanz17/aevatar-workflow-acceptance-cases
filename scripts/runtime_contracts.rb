# frozen_string_literal: true

module RuntimeContracts
  CONTRACTS = {
    "01" => {
      probe_step: "seed_review_envelope",
      expected: {
        "case" => "release_readiness",
        "ready_for_review" => true,
        "side_effects" => false
      }
    },
    "02" => {
      probe_step: "extract_documents",
      expected: {
        "identity_present" => true,
        "experience_present" => true,
        "education_present" => true,
        "contact_present" => true,
        "consent_present" => true
      }
    },
    "03" => {
      probe_step: "list_email_approvals",
      expected: {
        "case" => "email_access_approval_audit",
        "success" => true,
        "instance_reachable" => true,
        "side_effects" => false
      }
    },
    "04" => {
      probe_step: "read_license_inventory",
      expected: {
        "case" => "saas_license_utilization",
        "feature_ok" => true,
        "live_base_reads_ok" => true,
        "side_effects" => false
      }
    },
    "05" => {
      probe_step: "route_mode",
      expected: {
        "case" => "asset_inventory_attestation",
        "mode" => "preview",
        "mutation_executed" => false
      },
      side_effect_expected: {
        "case" => "asset_inventory_attestation",
        "mode" => "submit",
        "mutation_executed" => true,
        "accepted" => true
      }
    },
    "06" => {
      probe_step: "create_approval",
      expected: {
        "case" => "project_shared_mailbox_approval",
        "success" => true
      }
    },
    "07" => {
      probe_step: "route_mode",
      expected: {
        "case" => "quarterly_access_review_reminder",
        "mode" => "preview",
        "message_sent" => false,
        "period" => "2026-Q3"
      },
      side_effect_expected: {
        "case" => "quarterly_access_review_reminder",
        "mode" => "submit",
        "message_sent" => true,
        "period" => "2026-Q3"
      }
    },
    "08" => {
      probe_step: "read_license_inventory",
      expected: {
        "case" => "saas_license_optimization_digest",
        "mode" => "preview",
        "all_sources_ok" => true,
        "message_sent" => false
      },
      side_effect_expected: {
        "case" => "saas_license_optimization_digest",
        "mode" => "submit",
        "success" => true,
        "message_sent" => true
      }
    },
    "09" => {
      probe_step: "extract_documents",
      expected: {
        "case" => "contractor_access_package_approval",
        "mode" => "preview",
        "success" => true,
        "complete" => true,
        "approval_created" => false
      },
      side_effect_expected: {
        "case" => "contractor_access_package_approval",
        "mode" => "submit",
        "success" => true,
        "history_checked" => true
      }
    },
    "10" => {
      probe_step: "normalize_context",
      expected: {
        "case" => "monthly_access_certification",
        "mode" => "preview",
        "success" => true,
        "approval_created" => false,
        "message_sent" => false
      },
      side_effect_expected: {
        "case" => "monthly_access_certification",
        "mode" => "submit",
        "success" => true,
        "message_sent" => true
      }
    },
    "11" => {
      probe_step: "execute_probe",
      expected: {
        "case" => "complex_codex_exec_validation",
        "success" => true,
        "output" => "CODEX_EXEC_READY",
        "parallel_check_count" => 5,
        "side_effects" => false
      }
    },
    "12" => {
      probe_step: "calculate_settlement",
      expected: {
        "case" => "safe_code_execute_validation",
        "success" => true,
        "structured_receipt" => true,
        "total_cents" => 16_623,
        "side_effects" => false
      }
    },
    "13" => {
      probe_step: "extract_document",
      expected: {
        "case" => "invoice_ocr_policy_review",
        "success" => true,
        "ocr_media_input" => true,
        "extraction_ok" => true,
        "normalization_ok" => true,
        "history_api_reachable" => true,
        "exact_invoice_number_matches" => 1,
        "same_vendor_matches" => 2,
        "manual_review_required" => true,
        "side_effects" => false
      }
    },
    "14" => {
      probe_step: "resolve_contact",
      expected: {
        "case" => "lark_contact_batch_resolution",
        "success" => true,
        "contact_api_reachable" => true,
        "resolved_count" => 1,
        "identifiers_redacted" => true,
        "side_effects" => false
      }
    },
    "15" => {
      probe_step: "read_compute_actual_source",
      expected: {
        "case" => "weekly_budget_variance_digest",
        "success" => true,
        "live_base_reads_ok" => true,
        "weekly_actual" => 2_340,
        "weekly_budget" => 2_400,
        "monthly_projected_actual" => 9_360,
        "monthly_budget" => 9_600,
        "over_count" => 1,
        "watch_count" => 1,
        "side_effects" => false
      }
    },
    "16" => {
      probe_step: "read_base_records",
      expected: {
        "case" => "nyxid_read_receipt_probe",
        "success" => true,
        "provider_response_verified" => true,
        "side_effects" => false
      }
    },
    "17" => {
      probe_step: "search_base_records",
      expected: {
        "case" => "lark_post_search_approval_probe",
        "success" => true,
        "approval_resumed" => true,
        "side_effects" => false
      }
    },
    "18" => {
      probe_step: "replay_control_order",
      expected: {
        "case" => "supplier_control_attestation_review",
        "attested" => true,
        "control_count" => 3,
        "leading_control" => "breach_notice",
        "replay_iterations" => 3,
        "side_effects" => false
      }
    },
    "19" => {
      probe_step: "extract_uploaded_file",
      expected: {
        "case" => "lark_bot_file_upload_validation",
        "success" => true,
        "execution_mode" => "preview",
        "file_ref_registered" => true,
        "document_extract_succeeded" => true,
        "content_contract_matches" => true,
        "lark_bot_ingress_validated" => false,
        "identifiers_redacted" => true,
        "side_effects" => false
      }
    },
    "20" => {
      probe_step: "aggregate_risk_tiers",
      expected: {
        "case" => "supplier_risk_tier_aggregation",
        "aggregated" => true,
        "mapped_tier_count" => 3,
        "merged_line_count" => 5,
        "cache_hit_returned_first_value" => true,
        "side_effects" => false
      }
    },
    "21" => {
      probe_step: "list_legacy_window",
      expected: {
        "case" => "approval_window_integrity_audit",
        "success" => true,
        "reads_ok" => true,
        "legacy_window_expired" => true,
        "active_window_covers_now" => true,
        "side_effects" => false
      }
    },
    "22" => {
      probe_step: "read_license_inventory",
      expected: {
        "case" => "acceptance_fixture_drift_attestation",
        "success" => true,
        "reads_completed" => true,
        "fixtures_intact" => true,
        "side_effects" => false
      }
    },
    "23" => {
      probe_step: "search_with_attested_risk",
      expected: {
        "case" => "readonly_attested_post_probe",
        "success" => true,
        "attested_readonly_executed" => true,
        "side_effects" => false
      }
    },
    "24" => {
      probe_step: "create_probe_record",
      expected: {
        "case" => "runtime_tool_approval_write_probe",
        "success" => true,
        "mutation_executed" => true,
        "record_created" => true,
        "side_effects" => true
      }
    },
    "25" => {
      probe_step: "create_first_probe_record",
      expected: {
        "case" => "sequential_tool_approval_write_probe",
        "success" => true,
        "first_mutation_executed" => true,
        "second_mutation_executed" => true,
        "sequential_mutations" => 2,
        "side_effects" => true
      }
    }
  }.freeze

  module_function

  def for(case_id, side_effect: false)
    contract = CONTRACTS.fetch(case_id)
    expected_key = side_effect && contract[:side_effect_expected] ? :side_effect_expected : :expected
    {
      probe_step: contract.fetch(:probe_step),
      expected: contract.fetch(expected_key)
    }
  end

  def mismatch(case_id, artifact, side_effect: false)
    expected = self.for(case_id, side_effect: side_effect).fetch(:expected)
    actual = expected.keys.to_h { |key| [key, artifact.is_a?(Hash) ? artifact[key] : nil] }
    return nil if actual == expected

    { expected: expected, actual: actual }
  end
end
