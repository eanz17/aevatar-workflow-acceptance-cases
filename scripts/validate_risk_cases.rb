#!/usr/bin/env ruby

require "json"
require "time"
require "yaml"

require_relative "runtime_contracts"

ROOT = File.expand_path("..", __dir__)
CASE_DIR = File.join(ROOT, "risk-cases")
EVIDENCE_PATH = File.join(ROOT, "validation", "risk-validation-2026-08-06.json")
CASE_29_EVIDENCE_PATH = File.join(ROOT, "validation", "production-validation-2026-08-07-case-29.json")
SOURCE_COMMIT = "6df43b83a5e2b502eebcd9c01e687dbaf6321bff"
EXPECTED = {
  "23" => ["23-lark-workflow-runtime-tool-approval-rejected.case.yaml", "lark_workflow_runtime_tool_approval_rejected", "lark_private_bot"],
  "24" => ["24-lark-attachment-catalog-start.case.yaml", "lark_attachment_catalog_start", "lark_private_bot"],
  "25" => ["25-lark-sender-service-scope-authorized.case.yaml", "lark_sender_service_scope_authorized", "lark_private_bot"],
  "26" => ["26-assistant-safe-code-execute-authorized.case.yaml", "assistant_safe_code_execute_authorized", "api_chat"],
  "27" => ["27-ornn-public-catalog-complete.case.yaml", "ornn_public_catalog_complete", "ornn_public_catalog"],
  "28" => ["28-source-p1-v5-submit-false-current.case.yaml", "source_p1_v5_submit_false_current", "workflow_direct_source_definition"],
  "29" => ["29-source-p2-schema-preserving-no-send.case.yaml", "source_p2_schema_preserving_no_send", "workflow_direct_source_definition"],
  "30" => ["30-source-no-send-durable-schedule-cleanup.case.yaml", "source_no_send_durable_schedule_cleanup", "workflow_schedule_source_definition"],
  "31" => ["31-direct-runtime-artifact-contract-complete.case.yaml", "direct_runtime_artifact_contract_complete", "local_acceptance_guard"],
  "32" => ["32-report-evidence-consistency.case.yaml", "report_evidence_consistency", "local_acceptance_guard"],
  "33" => ["33-admission-missing-capability-provision-rejected.case.yaml", "admission_missing_capability_provision_rejected", "workflow_admission_guard"],
  "34" => ["34-admission-path-slot-contract.case.yaml", "admission_path_slot_contract", "workflow_admission_guard"],
  "35" => ["35-admission-n8n-export-rejected.case.yaml", "admission_n8n_export_rejected", "workflow_admission_guard"],
  "36" => ["36-admission-durable-write-fail-closed.case.yaml", "admission_durable_write_fail_closed", "workflow_admission_guard"],
  "37" => ["37-workflow-call-inline-definition-resolution.case.yaml", "workflow_call_inline_definition_resolution", "workflow_runtime_capability"],
  "38" => ["38-parallel-fanout-deterministic-runtime.case.yaml", "parallel_fanout_deterministic_runtime", "workflow_runtime_capability"],
  "39" => ["39-race-deterministic-runtime.case.yaml", "race_deterministic_runtime", "workflow_runtime_capability"],
  "40" => ["40-source-p2-send-disposable-target.case.yaml", "source_p2_send_disposable_target", "workflow_direct_source_definition"],
  "41" => ["41-source-p1-v6-synthetic-submit.case.yaml", "source_p1_v6_synthetic_submit", "workflow_direct_source_definition"],
  "42" => ["42-source-p1-v2-legacy-isolation.case.yaml", "source_p1_v2_legacy_isolation", "workflow_direct_source_definition"],
  "43" => ["43-materialized-workflow-output-isolation.case.yaml", "materialized_workflow_output_isolation", "local_acceptance_guard"]
}.freeze
ALLOWED_STATUSES = %w[passed blocked failed pending-execution not-configured skipped-expired].freeze
FORBIDDEN_KEYS = %w[
  runId actorId messageId approvalRequestId toolRequestId toolCallId senderId
  registrationScopeId conversationKey callbackCredential replyToken accessToken
  run_id actor_id message_id approval_request_id tool_request_id tool_call_id sender_id
  registration_scope_id conversation_key callback_credential reply_token access_token
].freeze
RAW_ID_PATTERNS = [
  /\b[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}\b/i,
  /\b(?:ou|oc|om)_[A-Za-z0-9_-]{8,}\b/,
  /\b(?:agent-run|workflow-run|actor|message|approval-request|tool-call|tool-request)-[A-Za-z0-9_-]{8,}\b/i,
  # 与 validate_workflows.rb 对 workflow 的同类判定保持一致：Lark table/record/view ID
  # 短于常规长标识阈值，必须显式列为原始身份。
  /\b(?:tbl|rec|vew)[A-Za-z0-9]{8,}\b/
].freeze

def fail_validation(message)
  warn "风险案例验证失败：#{message}"
  exit 1
end

def load_yaml(path)
  YAML.safe_load(File.read(path), aliases: false)
rescue Psych::Exception => e
  fail_validation("#{File.basename(path)} YAML 无法解析：#{e.message}")
end

def find_forbidden_key(value, path = "riskAcceptance")
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

def find_raw_identity(value, path = "riskAcceptance")
  case value
  when Hash
    value.each do |key, nested|
      found = find_raw_identity(nested, "#{path}.#{key}")
      return found if found
    end
  when Array
    value.each_with_index do |nested, index|
      found = find_raw_identity(nested, "#{path}[#{index}]")
      return found if found
    end
  when String
    return path if RAW_ID_PATTERNS.any? { |pattern| value.match?(pattern) }
  end
  nil
end

paths = Dir[File.join(CASE_DIR, "*.case.yaml")].sort
expected_paths = EXPECTED.values.map { |file, _name, _surface| File.join(CASE_DIR, file) }.sort
fail_validation("案例文件集合不完整") unless paths == expected_paths

cases = paths.to_h { |path| [load_yaml(path).fetch("case"), load_yaml(path)] }
fail_validation("案例编号不完整") unless cases.keys == EXPECTED.keys

cases.each do |case_id, spec|
  expected_file, expected_name, expected_surface = EXPECTED.fetch(case_id)
  path = paths.find { |candidate| File.basename(candidate) == expected_file }
  fail_validation("案例 #{case_id} 文件名漂移") unless path
  fail_validation("案例 #{case_id} schema_version 必须为 1.0") unless spec["schema_version"] == "1.0"
  fail_validation("案例 #{case_id} 名称漂移") unless spec["name"] == expected_name
  fail_validation("案例 #{case_id} 标题必须为中文") unless spec.fetch("title").match?(/[\p{Han}]/)
  fail_validation("案例 #{case_id} surface 漂移") unless spec["surface"] == expected_surface
  fail_validation("案例 #{case_id} 状态无效") unless ALLOWED_STATUSES.include?(spec["status"])
  fail_validation("案例 #{case_id} source commit 漂移") unless spec.dig("target", "source_commit") == SOURCE_COMMIT
  fail_validation("案例 #{case_id} 缺少 required_evidence") unless spec["required_evidence"].is_a?(Hash)
  fail_validation("案例 #{case_id} 允许持久化原始身份") unless
    spec.dig("safety", "raw_identifiers_persisted") == false &&
    spec.dig("required_evidence", "raw_identifiers_persisted") == false
end

fail_validation("案例 23 必须验证 workflow 运行期拒绝") unless
  cases.dig("23", "trigger", "decision") == "rejected" &&
  cases.dig("23", "required_evidence", "downstream_tool_executed") == false
fail_validation("案例 24 fixture 契约漂移") unless cases.dig("24", "fixture") == {
  "name" => "lark-bot-upload-manifest.json",
  "media_type" => "application/json",
  "size_bytes" => 114,
  "sha256" => "5a3cdce7117c7ef1e07ad02d9621b701d300974806da142e579415fb70cb61fb",
  "synthetic" => true
}
fail_validation("案例 25 未禁止历史 sender scope blocker") unless
  cases.dig("25", "required_evidence", "forbidden_failure_codes_absent") ==
    %w[NYXID_PROXY_SERVICE_SCOPE_FORBIDDEN NYXID_PROXY_UNAUTHORIZED]
fail_validation("案例 26 code_execute artifact 漂移") unless
  cases.dig("26", "required_evidence", "final_artifact") == RuntimeContracts.for("12").fetch(:expected)
expected_workflow_case_ids = RuntimeContracts::CONTRACTS.keys
expected_workflow_count = expected_workflow_case_ids.length
fail_validation("案例 27 public catalog 数量必须为 #{expected_workflow_count}") unless
  cases.dig("27", "target", "expected_skill_count") == expected_workflow_count &&
  cases.dig("27", "required_evidence", "public_skill_count") == expected_workflow_count
fail_validation("案例 29 不能接受 shared Base 语义替代") unless
  cases.dig("29", "required_evidence", "source_row_counts") == {
    "core_actual" => 3,
    "core_budget" => 2,
    "aelf_actual" => 1,
    "aelf_budget" => 2
  }
fail_validation("案例 30 缺少 schedule cleanup 闭环") unless
  cases.dig("30", "required_evidence", "delete_receipt_accepted") == true &&
  cases.dig("30", "required_evidence", "run_count_unchanged_after_next_fire_window") == true
fail_validation("案例 33 必须验证 provision 阶段准入拒绝") unless
  cases.dig("33", "required_evidence", "provision_rejected") == true &&
  cases.dig("33", "required_evidence", "external_writes") == false
# 平台契约把 path 拆成静态 selector path_template + 运行时槽位值；槽位值允许来自
# workflow 表达式（#2984 方案 C、PR #2996、#3071）。案例 34 必须钉住这一口径，
# 不能退回"模板化取值即拒绝"的 #2944 修复前期望。
fail_validation("案例 34 必须保持 path 槽位契约期望") unless
  cases.dig("34", "required_evidence", "templated_slot_value_admitted") == true &&
  cases.dig("34", "required_evidence", "downstream_failure_only_after_admitted_route") == true &&
  cases.dig("34", "required_evidence", "external_writes") == false
fail_validation("案例 35 必须验证 n8n 导出 preview 拒绝") unless
  cases.dig("35", "required_evidence", "preview_rejected") == true &&
  cases.dig("35", "required_evidence", "stable_error_unsupported_root_field") == true
fail_validation("案例 36 必须验证 durable 写准入 fail-closed 及 interactive 对照") unless
  cases.dig("36", "required_evidence", "durable_preview_rejected") == true &&
  cases.dig("36", "required_evidence", "interactive_counterpart_admitted") == true
fail_validation("案例 37 必须要求 inline 子工作流解析和 committed completion") unless
  cases.dig("37", "required_evidence", "inline_workflow_yamls_bound") == true &&
  cases.dig("37", "required_evidence", "child_definition_resolved") == true &&
  cases.dig("37", "required_evidence", "terminal_status") == "completed"
fail_validation("案例 38/39 必须要求确定性 worker probe") unless
  %w[38 39].all? { |case_id| cases.dig(case_id, "required_evidence", "deterministic_worker_step_supported") == true }
fail_validation("案例 40 必须要求一次性接收目标与显式副作用授权") unless
  cases.dig("40", "required_evidence", "disposable_recipient_configured") == true &&
  cases.dig("40", "required_evidence", "explicit_side_effect_authorization_recorded") == true
fail_validation("案例 41 必须要求安全合成提交目标与清理闭环") unless
  cases.dig("41", "required_evidence", "synthetic_submit_target_configured") == true &&
  cases.dig("41", "required_evidence", "cleanup_completed") == true
fail_validation("案例 42 缺少可追溯 retirement 与严格通过的 replacement") unless
  cases.dig("42", "status") == "skipped-expired" &&
  cases.dig("42", "retirement", "retired_on") == "2026-08-07" &&
  cases.dig("42", "retirement", "replacement_workflow_case") == "29" &&
  cases.dig("42", "retirement", "replacement_workflow") == "invoice_approval_routing_preview" &&
  cases.dig("42", "historical_required_evidence", "legacy_integration_semantics_isolated") == true &&
  cases.dig("42", "required_evidence", "replacement_terminal_status") == "completed" &&
  cases.dig("42", "required_evidence", "replacement_artifact_verified") == true &&
  cases.dig("42", "required_evidence", "replacement_ornn_public") == true &&
  cases.dig("42", "required_evidence", "external_writes") == false
fail_validation("案例 43 必须隔离 materialized workflow 输出目录") unless
  cases.dig("43", "required_evidence", "materializer_accepts_output_dir") == true &&
  cases.dig("43", "required_evidence", "production_validator_accepts_workflow_dir") == true &&
  cases.dig("43", "required_evidence", "example_and_local_outputs_isolated") == true

workflow_case_ids = Dir[File.join(ROOT, "workflows", "*.workflow.yaml")]
  .map { |path| File.basename(path)[0, 2] }
  .sort
fail_validation("direct workflow 未全部注册严格 contract") unless
  workflow_case_ids == expected_workflow_case_ids

evidence = JSON.parse(File.read(EVIDENCE_PATH))
fail_validation("机器证据 schemaVersion 漂移") unless evidence["schemaVersion"] == "1.0"
fail_validation("机器证据目标提交漂移") unless evidence.dig("targetSource", "commit") == SOURCE_COMMIT
production_deployment = evidence.fetch("productionDeployment")
fail_validation("生产部署未证明包含目标提交") unless
  production_deployment["requiredSourceCommitPresent"] == true &&
  production_deployment["readyReplicas"] == "1/1" &&
  production_deployment["commit"].to_s.match?(/\A[0-9a-f]{40}\z/) &&
  production_deployment["image"].to_s.end_with?(production_deployment["commit"][0, 8])
forbidden_key_path = find_forbidden_key(evidence)
fail_validation("机器证据包含原始身份字段：#{forbidden_key_path}") if forbidden_key_path
raw_identity_path = find_raw_identity(evidence)
fail_validation("机器证据包含疑似原始身份：#{raw_identity_path}") if raw_identity_path

# validation/ 下的全部机器证据都必须过同一道脱敏门禁，不能只扫风险证据文件。
Dir[File.join(ROOT, "validation", "*.json")].sort.each do |path|
  next if path == EVIDENCE_PATH

  document = JSON.parse(File.read(path))
  label = File.basename(path)
  key_path = find_forbidden_key(document, label)
  fail_validation("#{label} 包含原始身份字段：#{key_path}") if key_path
  identity_path = find_raw_identity(document, label)
  fail_validation("#{label} 包含疑似原始身份：#{identity_path}") if identity_path
rescue JSON::ParserError => e
  fail_validation("#{File.basename(path)} 不是有效 JSON：#{e.message}")
end

results = evidence.fetch("results")
fail_validation("机器证据案例编号不完整") unless results.map { |item| item.fetch("case") } == EXPECTED.keys
counts = results.each_with_object(Hash.new(0)) { |item, memo| memo[item.fetch("status")] += 1 }
expected_summary = {
  "total" => results.length,
  "passed" => counts["passed"],
  "blocked" => counts["blocked"],
  "failed" => counts["failed"],
  "pendingExecution" => counts["pending-execution"],
  "notConfigured" => counts["not-configured"],
  "skippedExpired" => counts["skipped-expired"]
}
fail_validation("机器证据汇总与逐案例状态不一致") unless evidence.fetch("summary") == expected_summary

probe_validation = evidence.fetch("newWorkflowProbeValidation")
probe_results = probe_validation.fetch("results")
fail_validation("新增 workflow probe 编号不完整") unless
  probe_results.map { |item| item.fetch("case") } == %w[21 22 23 24 25]
fail_validation("新增 workflow probe 汇总漂移") unless probe_validation.fetch("summary") == {
  "total" => 5,
  "previewPassed" => 5,
  "directRuntimePassed" => 5,
  "sideEffectRunsApproved" => 2,
  "sideEffectRecordsCreated" => 9
}
fail_validation("新增 workflow probe 保存了原始身份") unless
  probe_validation["rawIdentifiersPersisted"] == false

# 21-23 曾在一次 fresh revision 上以 NYXID_PROXY_HTTP_400 failed，根因是 build/workflows
# 被并行验收用 config.example.yaml 重新 materialize（见覆盖报告"判定口径与覆盖边界"一节），
# 不是平台回归：用 config.local.yaml 干净 materialize 后重跑，三者均 committed completed
# 且 artifact 精确命中。因此门禁按只读案例的正常契约钉住，不再要求保存 HTTP 400。
probe_results.first(3).each do |item|
  case_id = item.fetch("case")
  fail_validation("workflow Case #{case_id} 未取得 committed completed") unless
    item["terminalStatus"] == "completed" && item["completedSteps"] == item["totalSteps"]
  mismatch = RuntimeContracts.mismatch(case_id, item.fetch("finalArtifact"))
  fail_validation("workflow Case #{case_id} artifact 契约不匹配：#{mismatch.inspect}") if mismatch
end
probe_results.last(2).each do |item|
  case_id = item.fetch("case")
  fail_validation("workflow Case #{case_id} 未取得 committed completed") unless
    item["terminalStatus"] == "completed" && item["completedSteps"] == item["totalSteps"]
  mismatch = RuntimeContracts.mismatch(case_id, item.fetch("finalArtifact"))
  fail_validation("workflow Case #{case_id} artifact 契约不匹配：#{mismatch.inspect}") if mismatch
end
fail_validation("workflow Case 21-23 产生了副作用") unless
  probe_results.first(3).all? { |item| item["sideEffectsPerformed"] == false }
fail_validation("workflow Case 24/25 未保存 typed approval 与副作用实证") unless
  probe_results.last(2).map { |item| item["approvalResumeCount"] } == [1, 2] &&
  probe_results.last(2).all? do |item|
    item["previewRisk"] == "write" && item["approvalRequired"] == true &&
      item["approvalEnforcement"] == "bind_time_confirmation_and_run_time_tool_approval" &&
      item["approvalPendingObserved"] == true && item["typedApprovalIdentityPresent"] == true &&
      item["sideEffectsPerformed"] == true
  end

results.each do |item|
  case_id = item.fetch("case")
  spec = cases.fetch(case_id)
  fail_validation("案例 #{case_id} 名称或状态未同步") unless
    item["name"] == spec["name"] && item["status"] == spec["status"]
  fail_validation("案例 #{case_id} 保存了原始身份") unless item["rawIdentifiersPersisted"] == false

  case item.fetch("status")
  when "passed", "skipped-expired"
    begin
      Time.iso8601(item.fetch("observedAtUtc"))
    rescue ArgumentError, KeyError
      fail_validation("案例 #{case_id} observedAtUtc 无效")
    end
    fail_validation("案例 #{case_id} #{item.fetch('status')} 但未满足 required evidence") unless
      item["requiredEvidenceMet"] == true &&
      item["actualEvidence"] == spec["required_evidence"] &&
      item["stableErrorCode"].nil?
  when "blocked", "failed", "not-configured"
    begin
      Time.iso8601(item.fetch("observedAtUtc"))
    rescue ArgumentError, KeyError
      fail_validation("案例 #{case_id} observedAtUtc 无效")
    end
    fail_validation("案例 #{case_id} 缺少稳定错误码") if item["stableErrorCode"].to_s.empty?
    fail_validation("案例 #{case_id} 不应满足 required evidence") unless item["requiredEvidenceMet"] == false
    fail_validation("案例 #{case_id} 缺少诊断证据") unless item["actualEvidence"].is_a?(Hash)
  when "pending-execution"
    fail_validation("案例 #{case_id} 待执行时伪造了运行证据") unless
      item["observedAtUtc"].nil? && item["stableErrorCode"].nil? &&
      item["requiredEvidenceMet"] == false && item["actualEvidence"].nil?
  end
  fail_validation("案例 #{case_id} 缺少结果说明") if item["result"].to_s.empty?
end

result_by_case = results.to_h { |item| [item.fetch("case"), item] }
fail_validation("案例 23 缺少 fresh workflow 运行期拒绝 typed 证据") unless
  result_by_case.dig("23", "status") == "passed" &&
  result_by_case.dig("23", "stableErrorCode").nil? &&
  result_by_case.dig("23", "runHash").to_s.match?(/\A[0-9a-f]{12}\z/) &&
  result_by_case.dig("23", "stateVersion") == 17 &&
  result_by_case.dig("23", "completedSteps") == 1 &&
  result_by_case.dig("23", "totalSteps") == 1 &&
  result_by_case.dig("23", "actualEvidence") == cases.dig("23", "required_evidence") &&
  result_by_case.dig("23", "actualEvidence", "stable_error_code") == "approval_denied" &&
  result_by_case.dig("23", "actualEvidence", "downstream_tool_executed") == false
fail_validation("案例 24 缺少唯一 fresh Lark run 与换行归一化证据") unless
  result_by_case.dig("24", "status") == "passed" &&
  result_by_case.dig("24", "actualEvidence") == cases.dig("24", "required_evidence") &&
  result_by_case.dig("24", "actualEvidence", "workflow_run_hash") == "03c3f4ded68e" &&
  result_by_case.dig("24", "actualEvidence", "baseline_target_run_count") == 6 &&
  result_by_case.dig("24", "actualEvidence", "new_workflow_run_count") == 1 &&
  result_by_case.dig("24", "actualEvidence", "file_upload_card_size_bytes") == 114 &&
  result_by_case.dig("24", "actualEvidence", "committed_descriptor_size_bytes") == 113 &&
  result_by_case.dig("24", "actualEvidence", "trailing_lf_normalized") == true
fail_validation("案例 25 缺少同 sender 的精确 grant、批准恢复和 committed artifact") unless
  result_by_case.dig("25", "status") == "passed" &&
  result_by_case.dig("25", "actualEvidence") == cases.dig("25", "required_evidence")
case26 = result_by_case.fetch("26")
case26_evidence = case26.fetch("actualEvidence")
fail_validation("案例 26 缺少当前 api/chat/direct/UserService 三层严格成功") unless
  case26["status"] == "passed" &&
  case26["stableErrorCode"].nil? &&
  case26["requiredEvidenceMet"] == true &&
  case26_evidence["chat_completed"] == true &&
  case26_evidence["ornn_search_confirmed"] == true &&
  case26_evidence["exact_skill_resolved"] == true &&
  case26_evidence["workflow_start_calls"] == 1 &&
  case26_evidence["committed_terminal_observed"] == true &&
  case26_evidence["terminal_status"] == "completed" &&
  case26_evidence["run_hash"].to_s.match?(/\A[0-9a-f]{12}\z/) &&
  case26_evidence["direct_run_hash"].to_s.match?(/\A[0-9a-f]{12}\z/) &&
  case26_evidence["direct_same_success"] == true &&
  case26_evidence["sandbox_health_healthy"] == true &&
  case26_evidence["sandbox_execute_success"] == true &&
  case26_evidence["sandbox_execute_exit_code"] == 0 &&
  case26_evidence["sandbox_execute_output_verified"] == true &&
  case26_evidence["forbidden_failure_codes_absent"] == ["NYXID_PROXY_UNAUTHORIZED"] &&
  case26_evidence["final_artifact_present"] == true &&
  RuntimeContracts.mismatch("12", case26_evidence["final_artifact"]).nil? &&
  case26_evidence["side_effects"] == false &&
  case26_evidence["raw_identifiers_persisted"] == false
fail_validation("案例 27 public catalog 聚合证据漂移") unless
  result_by_case.dig("27", "status") == "passed" &&
  result_by_case.dig("27", "actualEvidence") == cases.dig("27", "required_evidence")
# 34 的两条负例（模板化 selector、槽位值越出单段）已于 2026-08-06T09:14:57Z 实测：
# 前者在 preview 被 NYXID_OPERATION_SELECTION_REQUIRED 拒绝，后者在调用 provider 前被
# NYXID_OPERATION_PATH_PARAMETER_INVALID 拦下。证据必须逐条在案，且不得再残留
# notMeasuredInThisRun，避免"已验证受限"与"未测量"互相冒充。
fail_validation("案例 34 必须实测两条槽位负例，不得只保留正例") unless
  result_by_case.dig("34", "actualEvidence", "templated_selector_rejected") == true &&
  result_by_case.dig("34", "actualEvidence", "slot_escape_rejected") == true
fail_validation("案例 34 已实测的负例不得再标记为未测量") if
  result_by_case.dig("34", "notMeasuredInThisRun")
case37 = result_by_case.fetch("37")
case37_evidence = case37.fetch("actualEvidence")
fail_validation("案例 37 缺少 fresh inline workflow committed 证据") unless
  case37["status"] == "passed" && case37["stableErrorCode"].nil? &&
  case37["requiredEvidenceMet"] == true &&
  case37["runHash"].to_s.match?(/\A[0-9a-f]{12}\z/) &&
  case37["stateVersion"] == 44 &&
  case37["completedSteps"] == 5 && case37["totalSteps"] == 5 &&
  case37_evidence["inline_workflow_yamls_bound"] == true &&
  case37_evidence["child_definition_resolved"] == true &&
  case37_evidence["child_workflow_started"] == true &&
  case37_evidence["terminal_status"] == "completed" &&
  case37_evidence["final_artifact_verified"] == true && case37_evidence["side_effects"] == false

case38 = result_by_case.fetch("38")
case38_evidence = case38.fetch("actualEvidence")
fail_validation("案例 38 缺少 fresh deterministic parallel committed 证据") unless
  case38["status"] == "passed" && case38["stableErrorCode"].nil? &&
  case38["requiredEvidenceMet"] == true &&
  case38["runHash"].to_s.match?(/\A[0-9a-f]{12}\z/) &&
  case38["stateVersion"] == 86 &&
  case38["completedSteps"] == 14 && case38["totalSteps"] == 14 &&
  case38_evidence["deterministic_worker_step_supported"] == true &&
  case38_evidence["worker_count"] == 3 &&
  case38_evidence["all_worker_receipts_observed"] == true &&
  case38_evidence["merged_output_order_verified"] == true &&
  case38_evidence["terminal_status"] == "completed" &&
  case38_evidence["side_effects"] == false

case39 = result_by_case.fetch("39")
case39_evidence = case39.fetch("actualEvidence")
fail_validation("案例 39 缺少 fresh deterministic race committed 证据") unless
  case39["status"] == "passed" && case39["stableErrorCode"].nil? &&
  case39["requiredEvidenceMet"] == true &&
  case39["runHash"].to_s.match?(/\A[0-9a-f]{12}\z/) &&
  case39["stateVersion"] == 38 &&
  case39["completedSteps"] == 6 && case39["totalSteps"] == 6 &&
  case39_evidence["deterministic_worker_step_supported"] == true &&
  case39_evidence["first_success_selected"] == true &&
  case39_evidence["later_completions_ignored"] == true &&
  case39_evidence["terminal_status"] == "completed" &&
  case39_evidence["side_effects"] == false

case42 = result_by_case.fetch("42")
case42_evidence = case42.fetch("actualEvidence")
replacement_summary = JSON.parse(File.read(CASE_29_EVIDENCE_PATH))
replacement = replacement_summary.fetch("results").fetch(0)
fail_validation("案例 42 retirement 未与 Case 29 严格证据闭环") unless
  case42["status"] == "skipped-expired" && case42["stableErrorCode"].nil? &&
  case42["requiredEvidenceMet"] == true && case42_evidence == cases.dig("42", "required_evidence") &&
  replacement_summary.dig("retiredRiskCase", "case") == "42" &&
  replacement_summary.dig("retiredRiskCase", "status") == "skipped-expired" &&
  replacement["case"] == "29" && replacement["previewPassed"] == true &&
  replacement["terminalStatus"] == "completed" && replacement["terminalSuccess"] == true &&
  replacement["completedSteps"] == 11 && replacement["totalSteps"] == 11 &&
  replacement["sideEffectsPerformed"] == false &&
  replacement.dig("ornnSkill", "serverFormatValid") == true &&
  replacement.dig("ornnSkill", "public") == true &&
  RuntimeContracts.mismatch("29", replacement.fetch("finalArtifact")).nil?
fail_validation("案例 40-41 未保存安全配置缺口") unless
  result_by_case.dig("40", "stableErrorCode") == "DISPOSABLE_SEND_TARGET_NOT_CONFIGURED" &&
  result_by_case.dig("41", "stableErrorCode") == "SYNTHETIC_SUBMIT_TARGET_NOT_CONFIGURED" &&
  %w[40 41].all? { |case_id| result_by_case.dig(case_id, "actualEvidence", "productionRunExecuted") == false }
fail_validation("案例 43 未保存隔离输出目录的完整证据") unless
  result_by_case.dig("43", "status") == "passed" &&
  result_by_case.dig("43", "actualEvidence") == cases.dig("43", "required_evidence")

workflow_count = Dir[File.join(ROOT, "workflows", "*.workflow.yaml")].length
skill_count = Dir[File.join(ROOT, "skills", "*")].count { |path| File.directory?(path) }
readme = File.read(File.join(ROOT, "README.md"))
report = File.read(File.join(ROOT, "report", "2026-08-05-workflow-coverage-report.md"))
html = File.read(File.join(ROOT, "report", "index.html"))
stale_claim_patterns = [
  /19\/19 个 (?:公开 )?workflow/,
  /19\/19 个 Ornn skill/,
  /19 个公开 workflow/,
  /19 个直接 workflow/,
  /19 workflows 之外/,
  /19 个 Ornn skills?/
]
stale_claim_count = [readme, report, html].sum do |document|
  stale_claim_patterns.sum { |pattern| document.scan(pattern).length }
end
computed_report_evidence = {
  "workflow_files" => workflow_count,
  "skill_directories" => skill_count,
  "runtime_contracts" => RuntimeContracts::CONTRACTS.length,
  "readme_workflow_count" => readme.include?("#{workflow_count} 个 workflow") ? workflow_count : 0,
  "report_workflow_count" => report.include?("#{workflow_count}/#{workflow_count} 个公开 workflow") ? workflow_count : 0,
  "machine_summary_workflow_count" => workflow_count,
  "stale_19_of_19_claims" => stale_claim_count,
  "raw_identifiers_persisted" => false
}
fail_validation("案例 32 未真实反映仓库与报告数量：#{computed_report_evidence.inspect}") unless
  result_by_case.dig("32", "actualEvidence") == computed_report_evidence

raw_case_text = paths.map { |path| File.read(path) }.join("\n")
fail_validation("案例定义中出现 UUID") if raw_case_text.match?(
  /\b[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}\b/i
)

puts "通过 风险案例=#{results.length} passed=#{counts['passed']} blocked=#{counts['blocked']} " \
     "failed=#{counts['failed']} pending-execution=#{counts['pending-execution']} " \
     "not-configured=#{counts['not-configured']} skipped-expired=#{counts['skipped-expired']}"
