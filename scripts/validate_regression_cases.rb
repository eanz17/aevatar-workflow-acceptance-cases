#!/usr/bin/env ruby

require "json"
require "yaml"

ROOT = File.expand_path("..", __dir__)
CASE_PATH = File.join(ROOT, "regression-cases", "01-lark-init-actor-activation-recovery.case.yaml")
EVIDENCE_PATH = File.join(ROOT, "validation", "regression-validation-2026-08-06.json")
EXPECTED_COMMIT = "f5e51e99f"
EXPECTED_ANCESTORS = %w[db72f22c9 a452d4917 330bfa74f 9f67c5281 b3784feef].freeze
FORBIDDEN_KEYS = %w[
  runId actorId messageId approvalRequestId toolRequestId toolCallId senderId accessToken
  run_id actor_id message_id approval_request_id tool_request_id tool_call_id sender_id access_token
].freeze

def fail_validation(message)
  warn "Regression case validation failed: #{message}"
  exit 1
end

def find_forbidden_key(value, path = "root")
  case value
  when Hash
    value.each do |key, nested|
      return "#{path}.#{key}" if FORBIDDEN_KEYS.include?(key)

      found = find_forbidden_key(nested, "#{path}.#{key}")
      return found if found
    end
  when Array
    value.each_with_index do |nested, index|
      found = find_forbidden_key(nested, "#{path}[#{index}]")
      return found if found
    end
  end
  nil
end

paths = Dir[File.join(ROOT, "regression-cases", "*.case.yaml")].sort
fail_validation("unexpected regression case file set") unless paths == [CASE_PATH]

spec = YAML.safe_load(File.read(CASE_PATH), aliases: false)
fail_validation("schema or identity drift") unless
  spec["schema_version"] == "1.0" && spec["case"] == "R01" &&
  spec["name"] == "lark_init_actor_activation_recovery" && spec["issue"] == "#3210"
fail_validation("status must be passed after production proof") unless spec["status"] == "passed"
fail_validation("surface contract drift") unless
  spec["surfaces"] == %w[orleans_integration lark_private_bot]
fail_validation("deployment ancestry drift") unless
  spec.dig("target", "required_deployment_commit") == EXPECTED_COMMIT &&
  spec.dig("target", "required_ancestor_commits") == EXPECTED_ANCESTORS
fail_validation("regression test contract drift") unless
  spec.dig("regression_test", "project") ==
    "test/Aevatar.Integration.Tests/Aevatar.Integration.Tests.csproj" &&
  spec.dig("regression_test", "name") ==
    "CheckpointRecovery_ShouldRetainActivationContext_AfterDurableCredentialResolution" &&
  spec.dig("regression_test", "fault_injection") == {
    "tool_completion_checkpoint_append_failures" => 1,
    "durable_credential_resolution_yields_to_thread_pool" => true
  } &&
  spec.dig("regression_test", "required_assertions") == {
    "provider_call_count" => 2,
    "tool_call_count" => 1,
    "injected_failure_count" => 1,
    "terminal_completion_success" => true
  }
fail_validation("production /init probe drift") unless
  spec.dig("production_probe", "command") == "/init" &&
  spec.dig("production_probe", "expected_visible_reply_count") == 1 &&
  spec.dig("production_probe", "expected_duplicate_reply_count") == 0 &&
  spec.dig("production_probe", "forbidden_log_signatures") == [
    "Activation access violation",
    "CommittedStatePublicationException"
  ]

expected_evidence = {
  "local_build_passed" => true,
  "local_regression_test_passed" => true,
  "architecture_guards_passed" => true,
  "workflow_binding_guard_passed" => true,
  "test_stability_guard_passed" => true,
  "solution_split_guards_passed" => true,
  "ready_production_workload_traceable" => true,
  "lark_init_inbound_observed" => true,
  "lark_init_reply_relay_observed" => true,
  "visible_reply_count" => 1,
  "duplicate_reply_count" => 0,
  "activation_access_violation_observed" => false,
  "committed_state_publication_exception_observed" => false,
  "raw_identifiers_persisted" => false
}
fail_validation("case evidence does not match production proof") unless
  spec["required_evidence"] == expected_evidence

evidence = JSON.parse(File.read(EVIDENCE_PATH))
fail_validation("evidence summary drift") unless evidence == {
  "schemaVersion" => "1.0",
  "summary" => {
    "total" => 1,
    "localPassed" => 1,
    "productionPassed" => 1,
    "pendingDeployment" => 0
  },
  "results" => [
    {
      "case" => "R01",
      "name" => "lark_init_actor_activation_recovery",
      "status" => "passed",
      "requiredDeploymentCommit" => EXPECTED_COMMIT,
      "localRegressionPassed" => true,
      "readyProductionWorkloadTraceable" => true,
      "observedAtUtc" => "2026-08-06T19:02:20Z",
      "deploymentImage" => "docker.io/aelfdevops/aevatar-console-backend:4c0596c7",
      "deploymentDigest" => "sha256:7cdca8d5038e2593c5583eba28d77e8bc4398baad4f10e77cd4a814ab04494e6",
      "larkInitInboundObserved" => true,
      "larkInitReplyRelayObserved" => true,
      "visibleReplyCount" => 1,
      "duplicateReplyCount" => 0,
      "activationAccessViolationObserved" => false,
      "committedStatePublicationExceptionObserved" => false,
      "rawIdentifiersPersisted" => false,
      "result" => "Local fault-injection and fresh production Lark /init recovery proof passed"
    }
  ]
}

forbidden = find_forbidden_key({ "spec" => spec, "evidence" => evidence })
fail_validation("raw identity field found at #{forbidden}") if forbidden
raw_text = File.read(CASE_PATH) + File.read(EVIDENCE_PATH)
fail_validation("UUID found in public regression evidence") if
  raw_text.match?(/\b[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}\b/i)

puts "Regression cases passed: total=1 local=1 production=1 pending-deployment=0"
