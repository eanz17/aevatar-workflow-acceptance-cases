#!/usr/bin/env ruby

require "json"
require "yaml"

require_relative "runtime_contracts"

ROOT = File.expand_path("..", __dir__)
EXPECTED_CASES = (1..20).map { |number| format("%02d", number) }.freeze
EXPECTED_WORKFLOW_CASES = RuntimeContracts::CONTRACTS.keys.freeze
EXPECTED_NEW_WORKFLOW_CASES = (21..25).map { |number| format("%02d", number) }.freeze
EXPECTED_COMPOSITION_WORKFLOW_CASES = (26..28).map { |number| format("%02d", number) }.freeze
EXPECTED_INTEGRATION_WORKFLOW_CASES = ["29"].freeze
EXPECTED_RISK_CASES = (23..43).map(&:to_s).freeze
EXPECTED_BLOCKED = %w[11].freeze
EXPECTED_CONTRACT_REGRESSIONS = [].freeze
EXPECTED_UNVERIFIED = [].freeze
EXPECTED_ISSUE_3161_AUTHOR_HISTORY = [2411, 2412, 2447, 2944, 2958, 2999, 3000, 3001, 3061, 3086, 3087].freeze
REPORT_DATE = "2026-08-05"
CURRENT_DATE = "2026-08-06"

def fail_validation(message)
  warn "报告验证失败：#{message}"
  exit 1
end

summary_path = File.join(ROOT, "validation", "production-validation-#{REPORT_DATE}.json")
summary = JSON.parse(File.read(summary_path))
runtime = summary.fetch("runtime")

fail_validation("静态验证摘要不是 20/20") unless summary.dig("staticValidation", "passed") == 20
fail_validation("production preview 已验证数不是 20/20") unless summary.dig("productionPreview", "passed") == 20 &&
  summary.dig("productionPreview", "unverified") == 0
fail_validation("production runtime 案例数不是 20") unless runtime.length == 20
fail_validation("production runtime 案例编号不完整") unless runtime.map { |item| item.fetch("case") } == EXPECTED_CASES
fail_validation("直接 runtime 严格通过数不是 19") unless summary.dig("directRuntimeSummary", "passed") == 19
fail_validation("直接 runtime 平台阻塞数不是 1") unless summary.dig("directRuntimeSummary", "platformBlocked") == 1
fail_validation("直接 runtime 契约回归数不是 0") unless summary.dig("directRuntimeSummary", "contractRegressions") == 0
fail_validation("直接 runtime completed 数不是 19") unless summary.dig("directRuntimeSummary", "terminalCompleted") == 19
fail_validation("直接 runtime failed 数不是 1") unless summary.dig("directRuntimeSummary", "terminalFailed") == 1
fail_validation("直接 runtime 待验证数不是 0") unless summary.dig("directRuntimeSummary", "unverified") == 0

runtime.each do |item|
  case_id = item.fetch("case")
  fail_validation("案例 #{case_id} 缺少机器断言") if item["assertion"].to_s.strip.empty?
  if EXPECTED_UNVERIFIED.include?(case_id)
    fail_validation("案例 #{case_id} 未标记待验证") unless item["result"] == "待验证"
    fail_validation("案例 #{case_id} 不应伪造终态") unless item["terminalStatus"].nil?
    fail_validation("案例 #{case_id} 不应伪造 stateVersion") unless item["stateVersion"].nil?
  elsif EXPECTED_BLOCKED.include?(case_id)
    fail_validation("案例 #{case_id} 未标记平台阻塞") unless item["result"] == "平台阻塞"
    fail_validation("案例 #{case_id} 不是 committed failed") unless item["terminalStatus"] == "failed"
    fail_validation("案例 #{case_id} 缺少 blockerCode") if item["blockerCode"].to_s.strip.empty?
    fail_validation("案例 #{case_id} 缺少 stateVersion") unless item["stateVersion"].is_a?(Integer)
  elsif EXPECTED_CONTRACT_REGRESSIONS.include?(case_id)
    fail_validation("案例 #{case_id} 未标记契约回归") unless item["result"] == "契约回归"
    fail_validation("案例 #{case_id} 不是 completed") unless item["terminalStatus"] == "completed"
    fail_validation("案例 #{case_id} 未记录 terminal success") unless item["terminalSuccess"] == true
    fail_validation("案例 #{case_id} 缺少 blockerCode") if item["blockerCode"].to_s.strip.empty?
    fail_validation("案例 #{case_id} 缺少 stateVersion") unless item["stateVersion"].is_a?(Integer)
  else
    fail_validation("案例 #{case_id} 未通过") unless item["result"] == "通过"
    fail_validation("案例 #{case_id} 不是 completed") unless item["terminalStatus"] == "completed"
    fail_validation("案例 #{case_id} 缺少 stateVersion") unless item["stateVersion"].is_a?(Integer)
  end
end

new_summary_path = File.join(ROOT, "validation", "production-validation-#{CURRENT_DATE}-cases-21-25.json")
risk_summary_path = File.join(ROOT, "validation", "risk-validation-#{CURRENT_DATE}.json")
new_summary = JSON.parse(File.read(new_summary_path))
risk_summary = JSON.parse(File.read(risk_summary_path))
composition_summary_path = File.join(ROOT, "validation", "production-validation-2026-08-07-cases-26-28.json")
composition_summary = JSON.parse(File.read(composition_summary_path))
integration_summary_path = File.join(ROOT, "validation", "production-validation-2026-08-07-case-29.json")
integration_summary = JSON.parse(File.read(integration_summary_path))
current_schedule_summary_path = File.join(ROOT, "validation", "production-validation-2026-08-07-schedule.json")
current_schedule_summary = JSON.parse(File.read(current_schedule_summary_path))

fail_validation("21-25 机器证据 schemaVersion 漂移") unless new_summary["schemaVersion"] == "1.0"
fail_validation("风险机器证据 schemaVersion 漂移") unless risk_summary["schemaVersion"] == "1.0"
fail_validation("26-28 机器证据 schemaVersion 漂移") unless composition_summary["schemaVersion"] == "1.0"
fail_validation("Case 29 机器证据 schemaVersion 漂移") unless integration_summary["schemaVersion"] == "1.0"
fail_validation("当前 Durable schedule 机器证据 schemaVersion 漂移") unless
  current_schedule_summary["schemaVersion"] == "1.0"
fail_validation("21-25 与风险证据的目标基线或 Ready 部署语义不一致") unless
  new_summary.dig("targetSource", "commit") == risk_summary.dig("targetSource", "commit") &&
  new_summary.dig("productionDeployment", "commit") == new_summary.dig("targetSource", "commit") &&
  new_summary.dig("productionDeployment", "readyReplicas") == "1/1" &&
  risk_summary.dig("productionDeployment", "readyReplicas") == "1/1" &&
  risk_summary.dig("productionDeployment", "requiredSourceCommitPresent") == true

probe_validation = risk_summary.fetch("newWorkflowProbeValidation")
probe_results = probe_validation.fetch("results")
fail_validation("新增 workflow probe 编号不完整") unless
  probe_results.map { |item| item.fetch("case") } == EXPECTED_NEW_WORKFLOW_CASES
fail_validation("新增 workflow probe 汇总不是当前 5/5") unless probe_validation.fetch("summary") == {
  "total" => 5,
  "previewPassed" => 5,
  "directRuntimePassed" => 5,
  "sideEffectRunsApproved" => 2,
  "sideEffectRecordsCreated" => 9
}
# 21-23 的 HTTP 400 已定位为 build/workflows materialize 竞争，不是平台回归；
# 干净重跑后三者均 committed completed，门禁按只读正常契约钉住。
probe_results.first(3).each do |item|
  case_id = item.fetch("case")
  fail_validation("新增 workflow #{case_id} 不是 committed completed") unless
    item["terminalStatus"] == "completed" && item["completedSteps"] == item["totalSteps"]
  mismatch = RuntimeContracts.mismatch(case_id, item.fetch("finalArtifact"))
  fail_validation("新增 workflow #{case_id} artifact 契约漂移：#{mismatch.inspect}") if mismatch
end
probe_results.last(2).each do |item|
  case_id = item.fetch("case")
  fail_validation("新增 workflow #{case_id} 不是 committed completed") unless
    item["terminalStatus"] == "completed" && item["completedSteps"] == item["totalSteps"]
  mismatch = RuntimeContracts.mismatch(case_id, item.fetch("finalArtifact"))
  fail_validation("新增 workflow #{case_id} artifact 契约漂移：#{mismatch.inspect}") if mismatch
end
fail_validation("新增只读 workflow 产生了副作用") unless
  probe_results.first(3).all? { |item| item["sideEffectsPerformed"] == false }
fail_validation("新增写入 workflow 未记录 1 次与 2 次 typed approval resume") unless
  probe_results.last(2).map { |item| item["approvalResumeCount"] } == [1, 2] &&
  probe_results.last(2).all? { |item| item["typedApprovalIdentityPresent"] == true }

new_read_only_results = new_summary.dig("readOnlyRuns", "validatorOutput", "results")
new_side_effect_results = new_summary.dig("sideEffectRuns", "results")
new_production_results = Array(new_read_only_results) + Array(new_side_effect_results)
fail_validation("21-25 独立生产摘要案例编号不完整") unless
  new_production_results.map { |item| item.fetch("case") } == EXPECTED_NEW_WORKFLOW_CASES
new_production_results.each do |item|
  case_id = item.fetch("case")
  artifact = item["finalOutput"] || item["finalArtifact"]
  fail_validation("21-25 独立生产摘要案例 #{case_id} 未完成") unless
    item["terminalStatus"] == "completed" && item["completedSteps"] == item["totalSteps"]
  mismatch = RuntimeContracts.mismatch(case_id, artifact)
  fail_validation("21-25 独立生产摘要案例 #{case_id} artifact 漂移：#{mismatch.inspect}") if mismatch
end

composition_results = composition_summary.fetch("results")
fail_validation("26-28 独立生产摘要案例编号不完整") unless
  composition_results.map { |item| item.fetch("case") } == EXPECTED_COMPOSITION_WORKFLOW_CASES
fail_validation("26-28 独立生产摘要部署证据不完整") unless
  composition_summary.dig("productionDeployment", "commit") ==
    "4c0596c764b45abc36d00e27577cd5a949796f79" &&
  composition_summary.dig("productionDeployment", "readyReplicas") == "1/1" &&
  risk_summary.dig("productionDeployment", "commit") ==
    "6558db8db00bcc43d38d3c3e3781246d8079d5cc" &&
  risk_summary.dig("productionDeployment", "readyReplicas") == "1/1"
composition_results.each do |item|
  case_id = item.fetch("case")
  fail_validation("26-28 独立生产摘要案例 #{case_id} 未完成") unless
    item["previewPassed"] == true && item["callSiteCount"] == 0 &&
    item["terminalStatus"] == "completed" && item["terminalSuccess"] == true &&
    item["completedSteps"] == item["totalSteps"] && item["sideEffectsPerformed"] == false &&
    item["runHash"].to_s.match?(/\A[0-9a-f]{12}\z/)
  mismatch = RuntimeContracts.mismatch(case_id, item.fetch("finalArtifact"))
  fail_validation("26-28 独立生产摘要案例 #{case_id} artifact 漂移：#{mismatch.inspect}") if mismatch
end

integration_results = integration_summary.fetch("results")
fail_validation("Case 29 独立生产摘要案例编号不完整") unless
  integration_results.map { |item| item.fetch("case") } == EXPECTED_INTEGRATION_WORKFLOW_CASES
case29 = integration_results.fetch(0)
expected_case29_call_sites = [
  {
    "method" => "get",
    "pathTemplate" => "/open-apis/approval/v4/instances",
    "effectiveRisk" => "read_only",
    "approvalRequired" => false,
    "approvalEnforcement" => "none",
    "allowedExecutionModes" => ["interactive"]
  },
  {
    "method" => "post",
    "pathTemplate" => "/open-apis/contact/v3/users/batch_get_id",
    "effectiveRisk" => "read_only",
    "approvalRequired" => false,
    "approvalEnforcement" => "none",
    "allowedExecutionModes" => ["interactive"]
  }
]
fail_validation("Case 29 preview/runtime/Ornn 严格证据不完整") unless
  integration_summary.dig("productionDeployment", "commit") ==
    "6a656d7593c655ba565565824431802c85e2de46" &&
  integration_summary.dig("productionDeployment", "readyReplicas") == "1/1" &&
  integration_summary.dig("productionDeployment", "podRestarts") == 0 &&
  case29["previewPassed"] == true && case29["callSiteCount"] == 2 &&
  case29["callSites"] == expected_case29_call_sites &&
  case29["runHash"].to_s.match?(/\A[0-9a-f]{12}\z/) &&
  case29["terminalStatus"] == "completed" && case29["terminalSuccess"] == true &&
  case29["stateVersion"] == 77 && case29["completedSteps"] == 11 && case29["totalSteps"] == 11 &&
  case29["approvalPendingObserved"] == false && case29["approvalResumeCount"] == 0 &&
  case29["sideEffectsPerformed"] == false &&
  case29.dig("ornnSkill", "name") == "invoice-approval-routing-preview" &&
  case29.dig("ornnSkill", "version") == "1.0" &&
  case29.dig("ornnSkill", "serverFormatValid") == true &&
  case29.dig("ornnSkill", "public") == true &&
  RuntimeContracts.mismatch("29", case29.fetch("finalArtifact")).nil?
fail_validation("Case 29 未声明 Risk 42 retirement 关系") unless
  integration_summary["retiredRiskCase"] == {
    "case" => "42",
    "status" => "skipped-expired",
    "sourceDefinitionPreserved" => true,
    "sourceSha256Verified" => true,
    "replacementCase" => "29"
  }

invalid_materialization_control = {
  "deploymentCommit" => risk_summary.dig("targetSource", "commit"),
  "cases" => %w[21 22 23],
  "stableErrorCode" => "NYXID_PROXY_HTTP_400",
  "cause" => "shared build/workflows overwritten by config.example.yaml materialization",
  "supersededByCleanMaterializationRun" => true
}
fail_validation("无效 materialization 负面对照漂移") unless
  new_summary["invalidMaterializationControl"] == invalid_materialization_control &&
  probe_validation["invalidMaterializationControl"] == invalid_materialization_control

risk_results = risk_summary.fetch("results")
fail_validation("风险案例编号不完整") unless risk_results.map { |item| item.fetch("case") } == EXPECTED_RISK_CASES
risk_status_counts = risk_results.each_with_object(Hash.new(0)) do |item, counts|
  counts[item.fetch("status")] += 1
end
fail_validation("风险案例汇总漂移") unless risk_summary.fetch("summary") == {
  "total" => 21,
  "passed" => 16,
  "blocked" => 0,
  "failed" => 0,
  "pendingExecution" => 0,
  "notConfigured" => 4,
  "skippedExpired" => 1
} && risk_status_counts == {
  "passed" => 16,
  "not-configured" => 4,
  "skipped-expired" => 1
}

risk42 = risk_results.find { |item| item.fetch("case") == "42" }
fail_validation("风险案例 42 retirement 与 Case 29 replacement 不一致") unless
  risk42["status"] == "skipped-expired" && risk42["stableErrorCode"].nil? &&
  risk42["requiredEvidenceMet"] == true &&
  risk42.dig("actualEvidence", "replacement_workflow_case") == "29" &&
  risk42.dig("actualEvidence", "replacement_terminal_status") == "completed" &&
  risk42.dig("actualEvidence", "replacement_artifact_verified") == true &&
  risk42.dig("actualEvidence", "replacement_ornn_public") == true &&
  risk42.dig("actualEvidence", "external_writes") == false

risk26 = risk_results.find { |item| item.fetch("case") == "26" }
fail_validation("风险案例 26 当前严格成功与 Case 12 不一致") unless
  risk26["status"] == "passed" &&
  risk26["stableErrorCode"].nil? &&
  risk26["requiredEvidenceMet"] == true &&
  risk26.dig("actualEvidence", "run_hash") == "6fa89cd62b15" &&
  risk26.dig("actualEvidence", "direct_run_hash") == "6659aabee079" &&
  risk26.dig("actualEvidence", "direct_same_success") == true &&
  risk26.dig("actualEvidence", "sandbox_health_healthy") == true &&
  risk26.dig("actualEvidence", "sandbox_execute_success") == true &&
  risk26.dig("actualEvidence", "sandbox_execute_exit_code") == 0 &&
  risk26.dig("actualEvidence", "sandbox_execute_output_verified") == true &&
  risk26.dig("actualEvidence", "forbidden_failure_codes_absent") == ["NYXID_PROXY_UNAUTHORIZED"] &&
  risk26.dig("actualEvidence", "final_artifact_present") == true &&
  RuntimeContracts.mismatch("12", risk26.dig("actualEvidence", "final_artifact")).nil? &&
  risk26.dig("actualEvidence", "side_effects") == false

source_p1_current = risk_results.find { |item| item.fetch("case") == "28" }
source_p1_evidence = source_p1_current.fetch("actualEvidence")
fail_validation("风险案例 28 缺少当前精确源 P1 submit=false 证据") unless
  source_p1_current["status"] == "passed" &&
  source_p1_current["requiredEvidenceMet"] == true &&
  source_p1_evidence["exact_source_previewed"] == true &&
  source_p1_evidence["sanitized_attachment_verified"] == true &&
  source_p1_evidence["binding_ready"] == true &&
  source_p1_evidence["preview_call_site_count"] == 5 &&
  source_p1_evidence["preview_read_only_call_site_count"] == 4 &&
  source_p1_evidence["preview_write_call_site_count"] == 1 &&
  source_p1_evidence["invoke_count"] == 1 &&
  source_p1_evidence["terminal_status"] == "completed" &&
  source_p1_evidence["last_success"] == true &&
  source_p1_evidence["completed_steps"] == 14 &&
  source_p1_evidence["total_steps"] == 14 &&
  source_p1_evidence["final_output_present"] == true &&
  source_p1_evidence["write_call_site_executed"] == false &&
  source_p1_evidence["approval_created"] == false &&
  source_p1_evidence["lark_writes"] == false &&
  source_p1_evidence["typed_error_classes"] == []

workflow_case_ids = Dir[File.join(ROOT, "workflows", "*.workflow.yaml")]
  .map { |path| File.basename(path)[0, 2] }
  .sort
skill_count = Dir[File.join(ROOT, "skills", "*")].count { |path| File.directory?(path) }
fail_validation("workflow、skill 或 strict runtime contract 数量不一致") unless
  workflow_case_ids == EXPECTED_WORKFLOW_CASES &&
  skill_count == EXPECTED_WORKFLOW_CASES.length &&
  RuntimeContracts::CONTRACTS.keys == EXPECTED_WORKFLOW_CASES

case14 = summary.fetch("case14Validation")
fail_validation("案例 14 preview 不是受批准保护的单次 POST") unless
  case14.dig("preview", "callSiteCount") == 1 &&
  case14.dig("preview", "method") == "post" &&
  case14.dig("preview", "effectiveRisk") == "write" &&
  case14.dig("preview", "approvalRequired") == true
fail_validation("案例 14 不是 committed completed") unless
  case14["terminalStatus"] == "completed" && case14["terminalSuccess"] == true &&
  case14["acceptanceStatus"] == "contract-regression" && case14["stateVersion"] == 25
fail_validation("案例 14 步骤或 artifact 证据不完整") unless
  case14["completedSteps"] == 3 && case14["totalSteps"] == 3 &&
  case14["toolCallSteps"] == 1 && case14["firstToolStepOutputPresent"] == true &&
  case14["typedApprovalIdentityPresent"] == false && case14["approvalPendingObserved"] == false &&
  case14["approvalResumeAccepted"] == false &&
  case14["contractFailureCode"] == "TOOL_APPROVAL_IDENTITY_NOT_OBSERVED" &&
  case14["finalArtifactVerified"] == true &&
  case14["readOnlyApprovalAuthorized"] == true
fail_validation("案例 14 最终 artifact 断言失败") unless case14.fetch("finalArtifact") == {
  "case" => "lark_contact_batch_resolution",
  "success" => true,
  "contact_api_reachable" => true,
  "resolved_count" => 1,
  "identifiers_redacted" => true,
  "side_effects" => false
}
fail_validation("案例 14 run hash 格式错误") unless case14["runIdHash"].to_s.match?(/\A[0-9a-f]{12}\z/)
case14_previous = case14.fetch("previousApprovedPathEvidence")
fail_validation("案例 14 历史批准路径证据缺失") unless
  case14_previous["deploymentImage"].to_s.end_with?("8cf280e2") &&
  case14_previous["runIdHash"].to_s.match?(/\A[0-9a-f]{12}\z/) &&
  case14_previous["stateVersion"] == 28 &&
  case14_previous["typedApprovalIdentityPresent"] == true

case16 = summary.fetch("case16Validation")
fail_validation("案例 16 preview 调用点不是单次只读 GET") unless
  case16.dig("preview", "callSiteCount") == 1 &&
  case16.dig("preview", "method") == "get" &&
  case16.dig("preview", "effectiveRisk") == "read_only" &&
  case16.dig("preview", "approvalRequired") == false
fail_validation("案例 16 不是 committed completed") unless
  case16["terminalStatus"] == "completed" && case16["stateVersion"].is_a?(Integer)
fail_validation("案例 16 步骤或首步输出证据不完整") unless
  case16["completedSteps"] == 4 && case16["totalSteps"] == 4 &&
  case16["toolCallSteps"] == 1 && case16["firstToolStepOutputPresent"] == true
fail_validation("案例 16 最终 artifact 断言失败") unless case16.fetch("finalArtifact") == {
  "success" => true,
  "provider_response_verified" => true,
  "side_effects" => false
}
fail_validation("案例 16 run hash 格式错误") unless case16["runIdHash"].to_s.match?(/\A[0-9a-f]{12}\z/)

case17 = summary.fetch("case17Validation")
fail_validation("案例 17 preview 不是受批准保护的单次 POST") unless
  case17.dig("preview", "callSiteCount") == 1 &&
  case17.dig("preview", "method") == "post" &&
  case17.dig("preview", "effectiveRisk") == "write" &&
  case17.dig("preview", "approvalRequired") == true
fail_validation("案例 17 不是 committed completed") unless
  case17["terminalStatus"] == "completed" && case17["terminalSuccess"] == true &&
  case17["acceptanceStatus"] == "contract-regression" && case17["stateVersion"] == 31
fail_validation("案例 17 步骤或契约回归证据不完整") unless
  case17["completedSteps"] == 4 && case17["totalSteps"] == 4 &&
  case17["toolCallSteps"] == 1 && case17["firstToolStepOutputPresent"] == true &&
  case17["typedApprovalIdentityPresent"] == false && case17["approvalPendingObserved"] == false &&
  case17["approvalResumeAccepted"] == false &&
  case17["contractFailureCode"] == "TOOL_APPROVAL_IDENTITY_NOT_OBSERVED"
fail_validation("案例 17 最终 artifact 断言失败") unless case17.fetch("finalArtifact") == {
  "case" => "lark_post_search_approval_probe",
  "success" => true,
  "approval_resumed" => true,
  "response_item_count" => 0,
  "side_effects" => false
}
fail_validation("案例 17 run hash 格式错误") unless case17["runIdHash"].to_s.match?(/\A[0-9a-f]{12}\z/)
case17_previous = case17.fetch("previousApprovedPathEvidence")
fail_validation("案例 17 历史批准路径证据缺失") unless
  case17_previous["runIdHash"].to_s.match?(/\A[0-9a-f]{12}\z/) &&
  case17_previous["stateVersion"] == 34 &&
  case17_previous["typedApprovalIdentityPresent"] == true
fail_validation("案例 17 缺少负向与 durable 边界") unless
  case17["remainingBranches"] == %w[approval_rejected durable_preview approved_path_revalidation]

case19 = summary.fetch("case19Validation")
fail_validation("案例 19 public skill 1.1 回读证据缺失") unless
  case19.dig("publicSkill", "name") == "lark-bot-file-upload-validation" &&
  case19.dig("publicSkill", "version") == "1.1" &&
  case19.dig("publicSkill", "publicReadback") == true
fail_validation("案例 19 preview 证据不完整") unless
  case19.dig("preview", "passed") == true &&
  case19.dig("preview", "callSiteCount") == 0 &&
  case19.dig("preview", "executionMode") == "interactive"
case19_fixture = case19.fetch("fixture")
fail_validation("案例 19 fixture 契约漂移") unless
  case19_fixture == {
    "name" => "lark-bot-upload-manifest.json",
    "mediaType" => "application/json",
    "sizeBytes" => 114,
    "sha256" => "5a3cdce7117c7ef1e07ad02d9621b701d300974806da142e579415fb70cb61fb",
    "synthetic" => true
  }
case19_direct = case19.fetch("directRun")
fail_validation("案例 19 direct committed 证据不完整") unless
  case19_direct["runIdHash"].to_s.match?(/\A[0-9a-f]{12}\z/) &&
  case19_direct["terminalStatus"] == "completed" && case19_direct["terminalSuccess"] == true &&
  case19_direct["stateVersion"] == 30 &&
  case19_direct["completedSteps"] == 4 && case19_direct["totalSteps"] == 4
fail_validation("案例 19 direct artifact 断言失败") unless case19_direct.fetch("finalArtifact") == {
  "case" => "lark_bot_file_upload_validation",
  "success" => true,
  "execution_mode" => "preview",
  "file_ref_registered" => true,
  "document_extract_succeeded" => true,
  "content_contract_matches" => true,
  "lark_bot_ingress_validated" => false,
  "identifiers_redacted" => true,
  "side_effects" => false,
  "observed_extracted_chars" => 114,
  "observed_size_bytes" => 114,
  "file_name_matches" => true,
  "text_contract_matches" => true,
  "sha256_matches" => true
}
case19_lark = case19.fetch("larkBotCanary")
fail_validation("案例 19 Lark canary committed 证据不完整") unless
  case19_lark["fileUploadCardObserved"] == true &&
  case19_lark["fileUploadCardSizeBytes"] == 114 &&
  case19_lark["inboundFileContentParsed"] == true &&
  case19_lark["replyRelayObserved"] == true &&
  case19_lark["workflowStartAttempts"] == 1 &&
  case19_lark["workflowValidationStatus"] == "validated" &&
  case19_lark["stableErrorCode"].nil? &&
  case19_lark["baselineTargetRunCount"] == 6 &&
  case19_lark["newWorkflowRunCount"] == 1 &&
  case19_lark["runIdHash"] == "03c3f4ded68e" &&
  case19_lark["committedTerminalObserved"] == true &&
  case19_lark["terminalStatus"] == "completed" && case19_lark["terminalSuccess"] == true &&
  case19_lark["stateVersion"] == 32 &&
  case19_lark["completedSteps"] == 4 && case19_lark["totalSteps"] == 4 &&
  case19_lark["committedDescriptorSizeBytes"] == 113 &&
  case19_lark["trailingLfNormalized"] == true &&
  case19_lark["larkBotIngressValidated"] == true &&
  case19_lark["rawIdentifiersPersisted"] == false &&
  case19_lark["sideEffects"] == false
fail_validation("案例 19 Lark canary typed artifact 漂移") unless case19_lark.fetch("finalArtifact") == {
  "case" => "lark_bot_file_upload_validation",
  "success" => true,
  "execution_mode" => "preview",
  "file_ref_registered" => true,
  "document_extract_succeeded" => true,
  "content_contract_matches" => true,
  "lark_bot_ingress_validated" => true,
  "identifiers_redacted" => true,
  "side_effects" => false,
  "observed_extracted_chars" => 113,
  "observed_size_bytes" => 113,
  "file_name_matches" => true,
  "text_contract_matches" => true,
  "sha256_matches" => true
}

latest_regression = summary.fetch("latestFullRegression")
fail_validation("最新全量回归摘要不完整") unless
  latest_regression["deploymentImage"].to_s.end_with?("0c4ff023") &&
  latest_regression["transport"] == "nyxid proxy request aevatar" &&
  latest_regression["previewPassed"] == 17 && latest_regression["realRunCases"] == 17 &&
  latest_regression["strictAccepted"] == 14 && latest_regression["runtimeBlocked"] == 1 &&
  latest_regression["contractRegressions"] == 2 && latest_regression["sideEffectCases"] == ["06"]

case11_regression = summary.fetch("case11Regression")
fail_validation("案例 11 历史 managed readiness 与失败证据不完整") unless
  case11_regression["deploymentImage"].to_s.end_with?("0c4ff023") &&
  case11_regression["previewPassed"] == true &&
  case11_regression["canonicalManagedPayloadMatched"] == true &&
  case11_regression.dig("managedCredentialReadiness", "executionReady") == true &&
  case11_regression.dig("managedCredentialReadiness", "reason") == "ready" &&
  case11_regression["failedStep"] == "execute_probe" &&
  case11_regression["stableErrorCode"] == "codex_execution_admission_denied" &&
  case11_regression["attempts"].length == 2 &&
  case11_regression["attempts"].all? do |attempt|
    attempt["terminalStatus"] == "failed" && attempt["stateVersion"] == 31
  end

case11_recovery = summary.fetch("case11RecoveryValidation")
fail_validation("案例 11 managed codex_exec 恢复证据不完整") unless
  case11_recovery["deploymentImage"].to_s.end_with?("f7f543c5") &&
  case11_recovery["fixCommit"] == "f7f543c51" &&
  case11_recovery["entryPoint"] == "scripts/production_validate.rb" &&
  case11_recovery["transport"] == "nyxid proxy request aevatar" &&
  case11_recovery["previewPassed"] == true &&
  case11_recovery["canonicalManagedPayloadMatched"] == true &&
  case11_recovery["nyxIdAuthenticationHeader"] == "X-API-Key" &&
  case11_recovery["authorizationHeaderPresent"] == false &&
  case11_recovery["runIdHash"].to_s.match?(/\A[0-9a-f]{12}\z/) &&
  case11_recovery["terminalStatus"] == "completed" &&
  case11_recovery["terminalSuccess"] == true &&
  case11_recovery["stateVersion"] == 179 &&
  case11_recovery["completedSteps"] == 30 && case11_recovery["totalSteps"] == 30 &&
  case11_recovery["output"] == "CODEX_EXEC_READY" &&
  case11_recovery["checks"] == {
    "status" => true,
    "target" => true,
    "output" => true,
    "exitCode" => true,
    "diagnosticId" => "已脱敏"
  } &&
  case11_recovery["parallelCheckCount"] == 5 && case11_recovery["sideEffects"] == false

case11_current = summary.fetch("case11CurrentValidation")
fail_validation("案例 11 当前 capacity blocker 证据不完整") unless
  case11_current["deploymentImage"].to_s.end_with?("eead35c0") &&
  case11_current["deployedCommit"] == "eead35c089758b26f7b0fd4c277dbbe71815b0cc" &&
  case11_current["entryPoint"] == "scripts/production_validate.rb" &&
  case11_current["transport"] == "nyxid proxy request aevatar" &&
  case11_current["previewPassed"] == true &&
  case11_current["canonicalManagedPayloadMatched"] == true &&
  case11_current["delegationPolicy"] == {
    "forwardAccessToken" => true,
    "injectDelegationToken" => true,
    "delegationTokenScope" => "proxy:*"
  } &&
  case11_current["attempts"].map { |attempt| attempt["runIdHash"] } == ["106ecf7b750a"] &&
  case11_current["attempts"].all? { |attempt|
    attempt["terminalStatus"] == "failed" && attempt["terminalSuccess"] == false &&
      attempt["stateVersion"] == 31 && attempt["completedSteps"] == 4 && attempt["totalSteps"] == 4
  } &&
  case11_current["failedStep"] == "execute_probe" &&
  case11_current["stableErrorCode"] == "codex_execution_capacity_unavailable" &&
  case11_current["currentDiagnosticBoundary"] == {
    "allowlistedUpstreamCodeObserved" => false,
    "targetedStdoutLogMatches" => 0,
    "tenMinuteStdoutLineCount" => 10,
    "healthCheck" => {
      "status" => "healthy",
      "opensandboxConnected" => true,
      "executeCapacityProven" => false
    }
  } &&
  case11_current["lastCapacityBoundary"] == {
    "observedAtUtc" => "2026-08-06T22:00:31Z",
    "deploymentImage" => "docker.io/aelfdevops/aevatar-console-backend:6a656d75",
    "runIdHashes" => %w[705a69901de5 4caa726585f6],
    "transportErrorCode" => "managed_proxy_unavailable",
    "downstreamHttpStatus" => 502,
    "healthCheck" => {
      "status" => "healthy",
      "opensandboxConnected" => true,
      "executeCapacityProven" => false
    }
  } &&
  case11_current["finalArtifactPresent"] == false &&
  case11_current["approvalPendingObserved"] == false &&
  case11_current["sideEffects"] == false && case11_current["status"] == "blocked"

case12 = summary.fetch("case12RecoveryValidation")
fail_validation("案例 12 历史恢复证据不完整") unless
  case12["deploymentImage"].to_s.end_with?("0c4ff023") &&
  case12["relatedCommit"] == "03389d0ae" && case12["attempts"].length == 2 &&
  case12["attempts"].all? { |run_hash| run_hash.match?(/\A[0-9a-f]{12}\z/) } &&
  case12["terminalStatus"] == "completed" && case12["stateVersion"] == 31 &&
  case12["completedSteps"] == 4 && case12["totalSteps"] == 4 &&
  case12["finalArtifact"] == {
    "case" => "safe_code_execute_validation",
    "success" => true,
    "structured_receipt" => true,
    "total_cents" => 16_623,
    "side_effects" => false
  }

case12_current = summary.fetch("case12CurrentValidation")
fail_validation("案例 12 当前恢复证据不完整") unless
  case12_current["deploymentImage"].to_s.end_with?("6558db8d") &&
  case12_current["deployedCommit"] == "6558db8db00bcc43d38d3c3e3781246d8079d5cc" &&
  case12_current["entryPoint"] == "scripts/production_validate.rb" &&
  case12_current["transport"] == "nyxid proxy request aevatar" &&
  case12_current["previewPassed"] == true &&
  case12_current["directRun"] == {
    "runIdHash" => "6659aabee079",
    "terminalStatus" => "completed",
    "terminalSuccess" => true,
    "stateVersion" => 31,
    "completedSteps" => 4,
    "totalSteps" => 4,
    "finalArtifact" => {
      "case" => "safe_code_execute_validation",
      "success" => true,
      "structured_receipt" => true,
      "total_cents" => 16_623,
      "side_effects" => false
    },
    "finalArtifactPresent" => true,
    "sideEffects" => false
  } &&
  case12_current["transientAttempt"] == {
    "runIdHash" => "c257460dc47a",
    "terminalStatus" => "failed",
    "stateVersion" => 12,
    "completedSteps" => 1,
    "totalSteps" => 1,
    "stableErrorCode" => "NYXID_PROXY_HTTP_524",
    "sideEffects" => false
  } &&
  case12_current["sandboxUserServiceProbe"] == {
    "userServiceIdHash" => "872833a52fc1",
    "forwardAccessToken" => true,
    "injectDelegationToken" => true,
    "delegationTokenScope" => "proxy:*",
    "healthStatus" => "healthy",
    "opensandboxConnected" => true,
    "executeSuccess" => true,
    "executeExitCode" => 0,
    "executeOutputVerified" => true,
    "elapsedSeconds" => 6
  } &&
  case12_current["approvalPendingObserved"] == false &&
  case12_current["sideEffects"] == false && case12_current["status"] == "passed"

ornn = summary.fetch("ornnPublication")
fail_validation("本地 Ornn skill 数不是 20") unless ornn.fetch("localSkillCount") == 19
%w[skillCount serverFormatValidated publishedPublic nameReadbackPassed].each do |field|
  fail_validation("Ornn #{field} 不是 15") unless ornn.fetch(field) == 15
end

ornn_current = summary.fetch("ornnCurrentValidation")
fail_validation("Ornn 当前 29/29 verify-only 证据不完整") unless
  ornn_current["service"] == "ornn-api" &&
  ornn_current["verificationMode"] == "verify-only" &&
  %w[localPackages serverFormatValidated exactNameReadback publicSkills].all? do |field|
    ornn_current[field] == 29
  end &&
  ornn_current["missingSkills"] == [] && ornn_current["privateSkills"] == [] &&
  ornn_current["versionMismatches"] == [] &&
  ornn_current["uploadsPerformed"] == false &&
  ornn_current["permissionsChanged"] == false && ornn_current["status"] == "passed"

assistant = summary.fetch("assistantNaturalLanguage")
fail_validation("/api/chat 案例数不是 5") unless assistant.fetch("cases") == 5
fail_validation("/api/chat completed 数不是 5") unless assistant.fetch("chatCompleted") == 5
fail_validation("/api/chat validated 数不是 5") unless assistant.fetch("workflowValidated") == 5
fail_validation("/api/chat typed failure 数不是 0") unless assistant.fetch("workflowTypedFailures") == 0
fail_validation("/api/chat 案例编号漂移") unless assistant.fetch("results").map { |item| item.fetch("case") } == %w[01 12 13 14 15]
fail_validation("/api/chat 未全部搜索 Ornn") unless assistant.fetch("results").all? { |item| item["ornnSearch"] == true }
fail_validation("/api/chat 未全部加载 skill") unless assistant.fetch("results").all? { |item| item["skillLoaded"] == true }
fail_validation("/api/chat 未全部启动 workflow") unless assistant.fetch("results").all? { |item| item["workflowStarted"] == true }
fail_validation("/api/chat fresh committed 终态或脱敏 run hash 不完整") unless
  assistant.fetch("results").all? do |item|
    item["workflowValidationStatus"] == "validated" &&
      item["terminalStatus"] == "completed" &&
      item["runIdHash"].to_s.match?(/\A[0-9a-f]{12}\z/)
  end
case12_assistant = assistant.fetch("results").find { |item| item["case"] == "12" }
case14_assistant = assistant.fetch("results").find { |item| item["case"] == "14" }
fail_validation("/api/chat 12/14 陈旧文案与 committed artifact 边界未保留") unless
  [case12_assistant, case14_assistant].all? do |item|
    item && item["assistantTextStale"] == true && item["committedArtifactAuthoritative"] == true
  end &&
  case12_assistant["stateVersion"] == 31 && case12_assistant["completedSteps"] == 4 &&
  case12_assistant["totalSteps"] == 4 && case12_assistant["runIdHash"] == "317024f71039" &&
  case14_assistant["stateVersion"] == 28 && case14_assistant["completedSteps"] == 3 &&
  case14_assistant["totalSteps"] == 3 && case14_assistant["runIdHash"] == "7fdd2a0932c0"

assistant_current = summary.fetch("assistantCurrentValidation")
current_case01, current_case12 = assistant_current.fetch("results")
fail_validation("/api/chat 当前代表对照证据不完整") unless
  assistant_current["deploymentCommit"] == "6558db8db00bcc43d38d3c3e3781246d8079d5cc" &&
  assistant_current["ingress"] == "nyxid proxy request aevatar /api/chat" &&
  assistant_current["representativeCases"] == 2 &&
  assistant_current["chatCompleted"] == 2 &&
  assistant_current["ornnSearchConfirmed"] == 2 &&
  assistant_current["exactSkillResolved"] == 2 &&
  assistant_current["workflowStarted"] == 2 &&
  assistant_current["workflowValidated"] == 2 &&
  assistant_current["workflowTypedFailures"] == 0 &&
  current_case01 == {
    "case" => "01",
    "runIdHash" => "535e9029486f",
    "workflowValidationStatus" => "validated",
    "terminalStatus" => "completed",
    "stateVersion" => 80,
    "completedSteps" => 13,
    "totalSteps" => 13,
    "artifactContractVerified" => true,
    "assertion" => "ready_for_review=true、side_effects=false"
  } &&
  current_case12 == {
    "case" => "12",
    "runIdHash" => "6fa89cd62b15",
    "workflowValidationStatus" => "validated",
    "terminalStatus" => "completed",
    "stateVersion" => 31,
    "completedSteps" => 4,
    "totalSteps" => 4,
    "artifactContractVerified" => true,
    "assertion" => "Ornn search、精确 skill mount、workflow start 与 committed artifact 全部通过；total_cents=16623、side_effects=false"
  }

case15_artifact = summary.fetch("case15ArtifactResolutionValidation")
fail_validation("案例 15 artifact identity 修复镜像证据缺失") unless
  case15_artifact["deploymentImage"].to_s.end_with?("d7844b5e")
fail_validation("案例 15 artifact identity 回归未 validated") unless
  case15_artifact["chatCompleted"] == true &&
  case15_artifact["workflowValidationStatus"] == "validated" &&
  case15_artifact["terminalStatus"] == "completed" &&
  case15_artifact["stateVersion"] == 73 &&
  case15_artifact["completedSteps"] == 11 &&
  case15_artifact["totalSteps"] == 11 &&
  case15_artifact["assistantReportedCommittedArtifact"] == true &&
  case15_artifact["artifactPendingReportedAsFinal"] == false &&
  case15_artifact["typedFailureCodes"] == []
fail_validation("案例 15 artifact identity 调用链证据不完整") unless
  case15_artifact["ornnSearchCalls"] == 1 &&
  case15_artifact["useSkillCalls"] == 3 &&
  case15_artifact["useSkillApprovalAccepted"] == true &&
  case15_artifact["workflowStartCalls"] == 1 &&
  case15_artifact["artifactReads"] == 4 &&
  case15_artifact["runIdHash"].to_s.match?(/\A[0-9a-f]{12}\z/) &&
  case15_artifact["finalOutputSha256"].to_s.match?(/\A[0-9a-f]{16}\z/)
case15_assistant = assistant.fetch("results").find { |item| item["case"] == "15" }
fail_validation("案例 15 /api/chat 汇总未同步 artifact identity 回归") unless
  case15_assistant &&
  case15_assistant["artifactReads"] == 4 &&
  case15_assistant["runIdHash"] == "5ceb3d4f5fbc" &&
  case15_assistant["assistantReportedCommittedArtifact"] == true &&
  case15_assistant["artifactPendingReportedAsFinal"] == false

current_deployment = summary.fetch("currentDeployment")
fail_validation("当前部署证据不完整") unless
  summary["updatedAtUtc"] == "2026-08-07T06:55:52Z" &&
  summary["deployedCommit"] == "eead35c089758b26f7b0fd4c277dbbe71815b0cc" &&
  summary["deploymentImage"].to_s.end_with?("eead35c0") &&
  current_deployment["observedAtUtc"] == "2026-08-07T06:29:00Z" &&
  current_deployment["deployedCommit"] == "eead35c089758b26f7b0fd4c277dbbe71815b0cc" &&
  current_deployment["healthyReplicas"] == "1/1" &&
  current_deployment["podRestarts"] == 0 &&
  current_deployment["containsFixCommits"] ==
    %w[03389d0ae 71a38ff59 7ad633e6f e30fdd94a 53e20f9ba 748f98e7d f7f543c51 7a7781067 b010ba614 5a0b545d8 e1aedcae7 20d9ba410 19b5906bb 4c0596c76 a44f849e0 6a656d759 4389ecd31 e1a1d3f36 b8a9d6908 6558db8db 49cb76e4a 5f51f6d0e 61a1f8c6e eead35c08] &&
  current_deployment["productionVerificationWindowUtc"] == {
    "startedAt" => "2026-08-06T21:49:00Z",
    "completedAt" => "2026-08-07T06:36:00Z"
  } &&
  current_deployment["postDeploymentLogCountersSampled"] == false &&
  current_deployment["targetedFailureLogsSampled"] == true

fail_validation("当前 Durable schedule 生产目标与部署证据不完整") unless
  current_schedule_summary["case"] == "15" &&
  current_schedule_summary["feature"] == "durable schedule" &&
  current_schedule_summary["result"] == "passed" &&
  current_schedule_summary["ingress"] == "nyxid proxy request aevatar" &&
  current_schedule_summary.dig("targetSource", "branch") == "origin/feature/integrate" &&
  current_schedule_summary.dig("targetSource", "commit") == "4c0596c764b45abc36d00e27577cd5a949796f79" &&
  current_schedule_summary.dig("productionDeployment", "image").to_s.end_with?("4c0596c7") &&
  current_schedule_summary.dig("productionDeployment", "digest") ==
    "sha256:7cdca8d5038e2593c5583eba28d77e8bc4398baad4f10e77cd4a814ab04494e6" &&
  current_schedule_summary.dig("productionDeployment", "generation") == 2721 &&
  current_schedule_summary.dig("productionDeployment", "observedGeneration") == 2721 &&
  current_schedule_summary.dig("productionDeployment", "readyReplicas") == "1/1" &&
  current_schedule_summary.dig("productionDeployment", "podRestarts") == 0

current_schedule_round = current_schedule_summary.fetch("successfulRound")
current_schedule_confirmation = current_schedule_round.fetch("confirmation")
fail_validation("当前 Durable schedule confirmation 证据不完整") unless
  current_schedule_round["startedAtUtc"] == "2026-08-06T19:34:33Z" &&
  current_schedule_round["completedAtUtc"] == "2026-08-06T19:36:20Z" &&
  current_schedule_round["endpoint"] == "/api/workflow/skills/{guid}/schedule" &&
  current_schedule_confirmation == {
    "status" => "confirmation_required",
    "httpStatusByDeployedRouteContract" => 200,
    "httpStatusObservedDirectly" => false,
    "typedBodyObserved" => true,
    "workflowCount" => 1,
    "explicitRequestCount" => 6,
    "allRequestsGet" => true,
    "allRequestsReadOnly" => true,
    "allRequestsAllowDurable" => true,
    "runtimeApprovalRequired" => false,
    "confirmationTokenPresent" => true,
    "confirmationTokenPersisted" => false
  }

current_schedule_admission = current_schedule_round.fetch("admissionReceipt")
fail_validation("当前 Durable schedule typed admission receipt 不完整") unless
  current_schedule_admission["httpStatusByDeployedRouteContract"] == 202 &&
  current_schedule_admission["httpStatusObservedDirectly"] == false &&
  current_schedule_admission["typedBodyObserved"] == true &&
  current_schedule_admission["bindingStatus"] == "accepted" &&
  current_schedule_admission["scheduleProvisioningStatus"] == "pending_binding" &&
  current_schedule_admission["scheduleIdPresent"] == false &&
  current_schedule_admission.values_at("memberIdHash", "bindingRunIdHash", "scheduleProvisioningIdHash") ==
    %w[973e89ab5a5d cc23d56d43b4 9df1921559a5]

current_schedule_member = current_schedule_round.fetch("memberReadModel")
fail_validation("当前 Durable schedule committed provisioning 证据不完整") unless
  current_schedule_member == {
    "bindingStatus" => "succeeded",
    "bindingStateVersion" => 7,
    "provisioningStatus" => "succeeded",
    "provisioningStateVersion" => 11,
    "attemptCount" => 2,
    "scheduleIdPresent" => true,
    "operationIdPresent" => true,
    "scheduleIdHash" => "4265fedf27e5",
    "operationIdHash" => "47e80cd8aa06"
  }
current_schedule_read = current_schedule_round.fetch("scheduleRead")
fail_validation("当前 Durable schedule owner-scoped 回读证据不完整") unless
  current_schedule_read == {
    "readModel" => "owner-scoped detail",
    "found" => true,
    "enabled" => true,
    "cronExpression" => "* * * * *",
    "timezone" => "Asia/Singapore",
    "deleted" => false
  }
current_schedule_fire = current_schedule_round.fetch("cronFire")
fail_validation("当前 Durable schedule 真实 cron 证据不完整") unless
  current_schedule_fire == {
    "manual" => false,
    "fireCountBeforeDelete" => 1,
    "failureCount" => 0,
    "observedRunCount" => 1,
    "allObservedRunsCompleted" => true
  }

current_schedule_terminal = current_schedule_round.fetch("workflowTerminal")
fail_validation("当前 Durable schedule workflow committed terminal 不完整") unless
  current_schedule_terminal["runIdHash"] == "b9859494e2a9" &&
  current_schedule_terminal["terminalStatus"] == "completed" &&
  current_schedule_terminal["success"] == true &&
  current_schedule_terminal["completedSteps"] == 11 &&
  current_schedule_terminal["totalSteps"] == 11 &&
  current_schedule_terminal["stateVersion"] == 73
current_schedule_mismatch = RuntimeContracts.mismatch("15", current_schedule_terminal.fetch("finalArtifact"))
fail_validation("当前 Durable schedule artifact 契约漂移：#{current_schedule_mismatch.inspect}") if
  current_schedule_mismatch

current_schedule_cleanup = current_schedule_round.fetch("cleanup")
fail_validation("当前 Durable schedule typed DELETE 与静默窗口不完整") unless
  current_schedule_cleanup["method"] == "DELETE" &&
  current_schedule_cleanup["httpStatusByDeployedRouteContract"] == 202 &&
  current_schedule_cleanup["httpStatusObservedDirectly"] == false &&
  current_schedule_cleanup["typedBodyObserved"] == true &&
  current_schedule_cleanup["typedReceiptAccepted"] == true &&
  current_schedule_cleanup["receiptStatus"] == "pending" &&
  current_schedule_cleanup["scheduleIdMatched"] == true &&
  current_schedule_cleanup["operationIdHash"] == "36486344f818" &&
  current_schedule_cleanup["commandIdHash"] == "fe5c1f31ec94" &&
  current_schedule_cleanup["detailAbsentAfterDelete"] == true &&
  current_schedule_cleanup["ownerListCountAfterDelete"] == 0 &&
  current_schedule_cleanup["crossedNextMinute"] == true &&
  current_schedule_cleanup["runCountBeforeDelete"] == 1 &&
  current_schedule_cleanup["runCountAfterNextMinute"] == 1 &&
  current_schedule_cleanup["runCountUnchanged"] == true

current_schedule_diagnostics = current_schedule_summary.fetch("diagnosticAttempts")
fail_validation("当前 Durable schedule 失败批次或清理证据遗失") unless
  current_schedule_diagnostics.map { |attempt| attempt["attempt"] } == [1, 2, 3] &&
  current_schedule_diagnostics.map { |attempt| attempt["result"] } == [
    "acceptance-query-path-failed",
    "acceptance-list-visibility-failed",
    "acceptance-extra-assertion-failed"
  ] &&
  current_schedule_diagnostics.map { |attempt| attempt["scheduleIdHash"] } ==
    %w[52207df9684e ac04dd243c51 9d6017f48fdc] &&
  current_schedule_diagnostics.map { |attempt| attempt["runCountBeforeDelete"] } == [3, 2, 0] &&
  current_schedule_diagnostics.map { |attempt| attempt["runCountAfterNextMinute"] } == [3, 2, 0] &&
  current_schedule_diagnostics.all? { |attempt|
    attempt["platformProvisioningSucceeded"] == true &&
      attempt["typedCleanupAccepted"] == true &&
      attempt["ownerListCountAfterDelete"] == 0 &&
      attempt["runCountUnchanged"] == true
  }

current_schedule_safety = current_schedule_summary.fetch("safety")
fail_validation("当前 Durable schedule 副作用与脱敏边界不完整") unless
  current_schedule_safety == {
    "confirmedMutationCountInSuccessfulRound" => 1,
    "diagnosticScheduleCount" => 3,
    "diagnosticCleanupCount" => 3,
    "allCreatedSchedulesDeleted" => true,
    "allCleanupWindowsCrossedNextMinute" => true,
    "rawIdentifiersPersisted" => false,
    "confirmationTokensPersisted" => false,
    "responseHeadersCaptured" => false,
    "businessPayloadsPersisted" => false
  }

current_schedule_keys = []
current_schedule_stack = [current_schedule_summary]
until current_schedule_stack.empty?
  value = current_schedule_stack.pop
  case value
  when Hash
    current_schedule_keys.concat(value.keys)
    current_schedule_stack.concat(value.values)
  when Array
    current_schedule_stack.concat(value)
  end
end
forbidden_current_schedule_keys = %w[memberId bindingRunId scheduleProvisioningId scheduleId operationId commandId]
fail_validation("当前 Durable schedule 机器证据保存了原始身份字段") unless
  (current_schedule_keys & forbidden_current_schedule_keys).empty?
fail_validation("当前 Durable schedule 机器证据包含 UUID") if
  JSON.generate(current_schedule_summary).match?(/[0-9a-f]{8}(?:-[0-9a-f]{4}){3}-[0-9a-f]{12}/i)

schedule = summary.fetch("scheduleValidation")
fail_validation("Durable schedule 最新生产复验摘要漂移") unless
  schedule["case"] == "15" &&
  schedule["endpoint"] == "/api/workflow/skills/{guid}/schedule" &&
  schedule["result"] == "生产端到端通过" &&
  schedule["historicalHttpStatus"] == 502 &&
  schedule["confirmationHttpStatus"] == 200 && schedule["admissionHttpStatus"] == 202 &&
  schedule["receiptCreated"] == true && schedule["scheduleCreated"] == true &&
  schedule["currentDeploymentCommit"] == "b010ba614e0171c09391dba86f30cb89fddb6bc4" &&
  schedule["currentDeploymentImage"].to_s.end_with?("b010ba61") &&
  schedule["currentDeploymentHealthyReplicas"] == "1/1" &&
  schedule["currentDeploymentRetested"] == true &&
  schedule["currentDeploymentContainsActorOwnedRepair"] == true
schedule_production = schedule.fetch("productionRetest")
fail_validation("Durable schedule 生产 confirmation/admission 证据不完整") unless
  schedule_production["startedAtUtc"] == "2026-08-06T02:20:06Z" &&
  schedule_production["completedAtUtc"] == "2026-08-06T02:36:49Z" &&
  schedule_production["ingress"] == "nyxid proxy request aevatar" &&
  schedule_production["confirmationStatus"] == "confirmation_required" &&
  schedule_production["explicitRequestCount"] == 6 &&
  schedule_production["allExplicitRequestsReadOnly"] == true &&
  schedule_production["allExplicitRequestsAllowDurable"] == true &&
  schedule_production["confirmationTokenPersisted"] == false &&
  schedule_production["confirmedMutationCount"] == 1
schedule_interactive = schedule_production.fetch("interactiveRun")
fail_validation("Durable schedule 前置 interactive run 证据不完整") unless
  schedule_interactive["runIdHash"] == "01a6c4d2a69b" &&
  schedule_interactive["terminalStatus"] == "completed" && schedule_interactive["success"] == true &&
  schedule_interactive["completedSteps"] == 11 && schedule_interactive["totalSteps"] == 11 &&
  schedule_interactive["stateVersion"] == 73 && schedule_interactive["explicitRequestCount"] == 6
schedule_admission = schedule_production.fetch("admissionReceipt")
fail_validation("Durable schedule typed provisioning receipt 不完整或包含未脱敏 ID") unless
  schedule_admission["bindingStatus"] == "accepted" &&
  schedule_admission["scheduleProvisioningStatus"] == "pending_binding" &&
  schedule_admission["scheduleIdPresent"] == false &&
  schedule_admission["bindingRunIdPresent"] == true &&
  schedule_admission["scheduleProvisioningIdPresent"] == true &&
  schedule_admission["responseHeadersCaptured"] == false &&
  schedule_admission.values_at("memberIdHash", "bindingRunIdHash", "scheduleProvisioningIdHash") ==
    %w[48ee435b5f0f b0c51ab26438 cb9e24aaa335] &&
  %w[memberIdHash bindingRunIdHash scheduleProvisioningIdHash]
    .all? { |field| schedule_admission[field].to_s.match?(/\A[0-9a-f]{12}\z/) }
schedule_member = schedule_production.fetch("memberReadModel")
fail_validation("Durable schedule provisioning committed terminal 证据不完整") unless
  schedule_member["bindingStatus"] == "succeeded" && schedule_member["bindingStateVersion"] == 7 &&
  schedule_member["provisioningStatus"] == "succeeded" && schedule_member["provisioningStateVersion"] == 11 &&
  schedule_member["attemptCount"] == 2 &&
  schedule_member["scheduleIdPresent"] == true && schedule_member["operationIdPresent"] == true &&
  schedule_member["scheduleIdHash"] == "c0a961c44045" &&
  schedule_member["operationIdHash"] == "13307937df98"
schedule_read = schedule_production.fetch("scheduleRead")
fail_validation("Durable schedule 回读证据不完整") unless
  schedule_read == {
    "found" => true,
    "enabled" => true,
    "cronExpression" => "* * * * *",
    "timezone" => "Asia/Singapore"
  }
schedule_fire = schedule_production.fetch("cronFire")
fail_validation("Durable schedule 真实 cron 触发证据不完整") unless
  schedule_fire["manual"] == false && schedule_fire["fireCountBeforeDelete"] == 6 &&
  schedule_fire["failureCount"] == 0 && schedule_fire["observedRunCount"] == 6 &&
  schedule_fire["allObservedRunsCompleted"] == true
schedule_terminal = schedule_production.fetch("workflowTerminal")
fail_validation("Durable schedule workflow committed terminal 不完整") unless
  schedule_terminal["runIdHash"] == "25ce474426de" &&
  schedule_terminal["terminalStatus"] == "completed" && schedule_terminal["success"] == true &&
  schedule_terminal["completedSteps"] == 11 && schedule_terminal["totalSteps"] == 11 &&
  schedule_terminal["stateVersion"] == 73 &&
  schedule_terminal["finalArtifact"] == {
    "case" => "weekly_budget_variance_digest",
    "success" => true,
    "live_base_reads_ok" => true,
    "weekly_actual" => 2340,
    "weekly_budget" => 2400,
    "monthly_projected_actual" => 9360,
    "monthly_budget" => 9600,
    "over_count" => 1,
    "watch_count" => 1,
    "side_effects" => false
  }
schedule_cleanup = schedule_production.fetch("cleanup")
fail_validation("Durable schedule DELETE 清理闭环不完整") unless
  schedule_cleanup["method"] == "DELETE" && schedule_cleanup["typedReceiptAccepted"] == true &&
  schedule_cleanup["receiptStatus"] == "pending" && schedule_cleanup["scheduleIdMatched"] == true &&
  schedule_cleanup["operationIdPresent"] == true && schedule_cleanup["commandIdPresent"] == true &&
  schedule_cleanup["listCountAfterDelete"] == 0 && schedule_cleanup["crossedNextMinute"] == true &&
  schedule_cleanup["runCountBeforeDelete"] == 6 && schedule_cleanup["runCountAfterNextMinute"] == 6 &&
  schedule_cleanup["runCountUnchanged"] == true
schedule_request = schedule_production.fetch("requestEvidence")
schedule_history = schedule.fetch("historicalRegression")
fail_validation("Durable schedule 请求或历史回归证据不完整") unless
  schedule_request["confirmationRequestCompletedWith"] == 200 &&
  schedule_request["confirmedRequestCompletedWith"] == 202 &&
  schedule_request["deleteRequestCompletedWith"] == 202 &&
  schedule_request["blindMutationRetryPerformed"] == false &&
  schedule_history["deploymentCommit"] == "f7f543c51" &&
  schedule_history["deploymentImage"].to_s.end_with?("f7f543c5") &&
  schedule_history["provisioningStatus"] == "failed" &&
  schedule_history["failureCode"] == "NyxIdOperationAuthorityContractUnavailable" &&
  schedule_history["fallbackProvider"] == "UnavailableNyxIdScheduledOperationAuthorizationPort" &&
  schedule_history["fallbackDecision"] == "AuthorityContractUnavailable"
schedule_source_repair = schedule.fetch("sourceRepair")
fail_validation("Durable schedule 只读源码窄修复生产证据不完整") unless
  schedule_source_repair["commit"] == "7a7781067" &&
  schedule_source_repair["branch"] == "origin/feature/integrate" &&
  schedule_source_repair["pushed"] == true &&
  schedule_source_repair["deployed"] == true &&
  schedule_source_repair["currentProductionImage"].to_s.end_with?("b010ba61") &&
  schedule_source_repair["policy"].include?("binder-attested READ_ONLY GET/HEAD/OPTIONS") &&
  schedule_source_repair["policy"].include?("NyxID") &&
  schedule_source_repair["case15Applicable"] == true &&
  schedule_source_repair["case15Methods"] == ["get"] &&
  schedule_source_repair["case15CallSiteCount"] == 6 &&
  schedule_source_repair["writeAndDestructiveRemainFailClosed"] == true &&
  schedule_source_repair["productionProofValidated"] == [
    "provisioning committed succeeded",
    "scheduleId 与 operationId 非空",
    "schedule 可读取",
    "真实 cron 触发并取得 workflow committed terminal",
    "DELETE typed receipt、list 消失且跨下一分钟 run count 不增长"
  ]
schedule_build_repair = schedule.fetch("deploymentBuildRepair")
fail_validation("当前部署编译与镜像修复证据不完整") unless
  schedule_build_repair["commit"] == "b010ba614e0171c09391dba86f30cb89fddb6bc4" &&
  schedule_build_repair["branch"] == "origin/feature/integrate" &&
  %w[pushed deployed releasePublishPassed dockerBuildPassed architectureGuardsPassed
     testStabilityGuardsPassed solutionTestsPassed].all? { |field| schedule_build_repair[field] == true } &&
  schedule_build_repair["image"].to_s.end_with?("b010ba61") &&
  schedule_build_repair["imagePlatform"] == "linux/amd64" &&
  schedule_build_repair["runtime"] == ".NET 10.0.10 linux-x64" &&
  schedule_build_repair.dig("environmentExcludedTests", "count") == 3 &&
  schedule_build_repair.dig("environmentExcludedTests", "requiredRedisVersion") == "7.2.3" &&
  schedule_build_repair.dig("environmentExcludedTests", "localRedisVersion") == "8.6.2"
schedule_repair = schedule.fetch("localRepair")
fail_validation("Durable schedule 提交、推送与部署状态不完整") unless
  schedule_repair["branch"] == "fix/2026-08-05_schedule-audit-artifact" &&
  schedule_repair["baseCommit"] == "b3784feef" &&
  schedule_repair["commit"] == "748f98e7d" &&
  %w[committed pushed deployed nyxidProductionRetested]
    .all? { |field| schedule_repair[field] == true } &&
  schedule_repair["fullBuildAndGuardsPassed"] == true &&
  schedule_repair["latestTargetedTestsRetested"] == true
schedule_endpoint_contract = schedule_repair.fetch("skillScheduleEndpointContract")
fail_validation("Durable schedule 真实入口契约记录不完整") unless
  schedule_endpoint_contract["endpoint"] == "/api/workflow/skills/{guid}/schedule" &&
  schedule_endpoint_contract["implementedContract"] == [
    "nullable scheduleId",
    "scopeId",
    "scheduleProvisioningId",
    "scheduleProvisioningStatus",
    "bindingRunId",
    "pending 时 HTTP 202",
    "pending 时 member read model Location",
    "schedule 可见时 schedule Location"
  ]
schedule_tests = schedule_repair.fetch("testEvidence")
fail_validation("Durable schedule 本地测试证据不完整") unless
  schedule_tests["capabilitiesTargeted"] == "23/23 passed" &&
  schedule_tests["studio"] == "1730/1730 passed" &&
  schedule_tests["studioProvisioningTool"] == "152/152 passed" &&
  schedule_tests["mainnetComposition"] == "1/1 passed" &&
  schedule_tests["studioDependencyInjectionAndExecutor"] == "11/11 passed" &&
  schedule_tests["solutionBuildPassed"] == true &&
  schedule_tests["testStabilityGuardPassed"] == true &&
  schedule_tests["slowTestGuardPassed"] == true &&
  schedule_tests["diffCheckPassed"] == true &&
  schedule_tests["completedGuards"] == [
    "architecture",
    "workflow binding boundary",
    "query projection priming",
    "projection state version",
    "projection state mirror current state",
    "projection route mapping",
    "test stability",
    "solution split",
    "test solution ownership",
    "slow test",
    "docs lint"
  ] &&
  schedule_tests["remainingChecks"] == [] &&
  schedule_tests.dig("capabilitiesProject", "passed") == 642 &&
  schedule_tests.dig("capabilitiesProject", "failed") == 0 &&
  schedule_tests.dig("capabilitiesProject", "environmentalFailures") == false &&
  schedule_tests.dig("fullSolutionRun", "passed") == true &&
  schedule_tests.dig("fullSolutionRun", "secondFullRunPassed") == true &&
  schedule_tests.dig("fullSolutionRun", "isolatedRetryPassed") == true &&
  schedule_tests.dig("fullSolutionRun", "localFixesPrepared")&.length == 3 &&
  schedule_tests.dig("fullSolutionRun", "verificationWorktreeContainsUncommittedFixes") == true &&
  schedule_tests.dig("fullSolutionRun", "verificationWorktreeUncommittedFileCount") == 4 &&
  schedule_tests.dig("fullSolutionRun", "redisVersionUsed") == "7.2.3"
schedule_boundary = summary.fetch("knownBoundaries").find { |item| item["capability"] == "durable schedule" }
fail_validation("Durable schedule known boundary 未同步生产恢复") unless
  schedule_boundary &&
  schedule_boundary["status"] == "已恢复" &&
  schedule_boundary["reason"].include?("200 confirmation_required -> 202 typed pending_binding receipt") &&
  schedule_boundary["reason"].include?("fireCount=6") &&
  schedule_boundary["reason"].include?("11/11 committed completed") &&
  schedule_boundary["reason"].include?("DELETE typed accepted") &&
  schedule_boundary["reason"].include?("run count 保持 6") &&
  schedule_boundary["reason"].include?("NyxIdOperationAuthorityContractUnavailable") &&
  schedule_boundary["reason"].include?("b010ba614") &&
  schedule_boundary["reason"].include?("f7f543c5")

financial = summary.fetch("sourceFinancialAcceptance")
p2_no_send = financial.fetch("p2NoSend")
fail_validation("源 P2 no-send preview 不是 6 个唯一只读 GET") unless
  p2_no_send["sourceDefinition"] == "P2-budget-monitor/budget_monitor_weekly.shared-base.nosend.yaml" &&
  p2_no_send.dig("preview", "exactSource") == true &&
  p2_no_send.dig("preview", "callSiteCount") == 6 &&
  p2_no_send.dig("preview", "uniqueCallSiteCount") == 6 &&
  p2_no_send.dig("preview", "methods") == ["get"] &&
  p2_no_send.dig("preview", "effectiveRisks") == ["read_only"] &&
  p2_no_send.dig("preview", "approvalRequired") == false
fail_validation("源 P2 no-send binding/contract 证据不完整") unless
  p2_no_send.dig("binding", "status") == "succeeded" &&
  p2_no_send.dig("binding", "contractReady") == true &&
  p2_no_send.dig("binding", "revisionConsistent") == true
fail_validation("源 P2 no-send 未严格单次 completed") unless
  p2_no_send.dig("runtime", "invokeCount") == 1 &&
  p2_no_send.dig("runtime", "runCatalogIncrease") == 1 &&
  p2_no_send.dig("runtime", "terminalStatus") == "completed" &&
  p2_no_send.dig("runtime", "lastSuccess") == true &&
  p2_no_send.dig("runtime", "completedSteps") == 8 &&
  p2_no_send.dig("runtime", "totalSteps") == 8 &&
  p2_no_send.dig("runtime", "firstBaseStepOutputPresent") == true &&
  p2_no_send.dig("runtime", "finalOutputPresent") == true &&
  p2_no_send.dig("runtime", "typedErrorClasses") == [] &&
  p2_no_send["messagesSent"] == false && p2_no_send["scheduleCreated"] == false

p1_v5 = financial.fetch("p1V5SubmitFalse")
fail_validation("源 P1 v5 preview 或输入边界漂移") unless
  p1_v5["sourceDefinition"] == "P1-invoice-approval/invoice_file_chain.v5.workflow.json" &&
  p1_v5.dig("preview", "exactSource") == true &&
  p1_v5.dig("preview", "callSiteCount") == 5 &&
  p1_v5.dig("preview", "uniqueCallSiteCount") == 5 &&
  p1_v5.dig("preview", "getCallSiteCount") == 3 &&
  p1_v5.dig("preview", "postCallSiteCount") == 2 &&
  p1_v5.dig("preview", "readOnlyCallSiteCount") == 4 &&
  p1_v5.dig("preview", "writeCallSiteCount") == 1 &&
  p1_v5.dig("preview", "approvalRequiredCallSiteCount") == 1 &&
  p1_v5.dig("input", "sanitizedPngFixtureVerified") == true &&
  p1_v5.dig("input", "submit") == false
fail_validation("源 P1 v5 瞬时失败诊断不支持单次证据化重跑") unless
  p1_v5.dig("transientFailureDiagnosis", "errorClass") == "HTTP_524" &&
  p1_v5.dig("transientFailureDiagnosis", "requestBytesLessThan") == 1024 &&
  p1_v5.dig("transientFailureDiagnosis", "elapsedSecondsLessThan") == 2 &&
  p1_v5.dig("transientFailureDiagnosis", "readContextOnlyProbeCompleted") == true &&
  p1_v5.dig("transientFailureDiagnosis", "evidenceBasedRetryCount") == 1
fail_validation("源 P1 v5 submit=false 未 committed 完成或产生了写入") unless
  p1_v5.dig("binding", "status") == "succeeded" &&
  p1_v5.dig("binding", "contractReady") == true &&
  p1_v5.dig("binding", "revisionConsistent") == true &&
  p1_v5.dig("runtime", "terminalStatus") == "completed" &&
  p1_v5.dig("runtime", "lastSuccess") == true &&
  p1_v5.dig("runtime", "completedSteps") == 14 &&
  p1_v5.dig("runtime", "totalExecutedSteps") == 14 &&
  p1_v5.dig("runtime", "imageAttachmentExtracted") == true &&
  p1_v5.dig("runtime", "readOnlyLookupCompleted") == true &&
  p1_v5.dig("runtime", "previewPresentationCompleted") == true &&
  p1_v5.dig("runtime", "finalOutputPresent") == true &&
  p1_v5.dig("runtime", "submitStepsExecuted") == false &&
  p1_v5.dig("runtime", "approvalCreated") == false &&
  p1_v5.dig("runtime", "typedErrorClasses") == [] &&
  p1_v5["larkWrites"] == false

pdf_probe = financial.fetch("pdfAttachmentProbe")
fail_validation("源 PDF attachment probe 未 committed 完成") unless
  pdf_probe["sideEffects"] == false && pdf_probe["runCatalogIncrease"] == 1 &&
  pdf_probe["terminalStatus"] == "completed" && pdf_probe["lastSuccess"] == true &&
  pdf_probe["completedSteps"] == 2 && pdf_probe["totalSteps"] == 2 &&
  pdf_probe["extractOutputPresent"] == true && pdf_probe["finalOutputPresent"] == true &&
  pdf_probe["typedErrorClasses"] == []

continuity = financial.fetch("currentContinuityIncident")
fail_validation("#3290 源迁移连续性事件缺少可追溯边界") unless
  continuity["evidenceSource"] == "https://github.com/aevatarAI/aevatar/issues/3290" &&
  continuity["evidenceKind"] == "external_issue_report" &&
  continuity["independentlyRerunByAcceptanceRepository"] == false &&
  continuity["status"] == "regression-blocked" &&
  continuity["historicalSuccessRetained"] == true &&
  continuity["currentAvailabilityProven"] == false &&
  continuity["sideEffectsPerformedByThisUpdate"] == false
fail_validation("#3290 P2 成功后 runtime/admission 回归证据不完整") unless
  continuity.dig("p2", "sameMemberBindingAndDefinition") == true &&
  continuity.dig("p2", "businessReconciliationMatchedCurrentSystem") == true &&
  continuity.dig("p2", "runSequence").map { |item| item.fetch("terminalStatus") } == %w[failed completed failed] &&
  continuity.dig("p2", "runSequence", 1, "completedSteps") == 14 &&
  continuity.dig("p2", "runSequence", 1, "totalSteps") == 14 &&
  continuity.dig("p2", "runSequence", 2, "stableErrorCode") == "NYXID_PROXY_HTTP_502" &&
  continuity.dig("p2", "admission", "identicalRequestBody") == true &&
  continuity.dig("p2", "admission", "failedAttempts") == 5 &&
  continuity.dig("p2", "admission", "stableErrorCode") == "NYXID_ADMISSION_SOURCE_CREDENTIAL_REQUIRED"
fail_validation("#3290 P1 forwarding 与健康对照证据不完整") unless
  continuity.dig("p1", "sourceWorkflowSteps") == 27 &&
  continuity.dig("p1", "completedSteps") == 0 &&
  continuity.dig("p1", "failedStepOrdinal") == 1 &&
  continuity.dig("p1", "errorTextPrefix") == "Forwarding failed" &&
  continuity.dig("p1", "workflowCodeExecuted") == false &&
  continuity.dig("controls", "sandboxDirectViaNyxIdHttpStatus") == 200 &&
  continuity.dig("controls", "nyxIdProxyHealthy") == true &&
  continuity.dig("controls", "callerTokenValid") == true &&
  continuity.dig("controls", "controlsProveWorkflowContinuity") == false
fail_validation("当前 pod 证据被错误外推为 silo 稳定") unless
  continuity.dig("currentClusterObservation", "deploymentImage") == "eead35c0" &&
  continuity.dig("currentClusterObservation", "readyReplicas") == "1/1" &&
  continuity.dig("currentClusterObservation", "podRestarts") == 0 &&
  continuity.dig("currentClusterObservation", "boundedStdoutLines") == 10 &&
  continuity.dig("currentClusterObservation", "matchingIncidentLogLines") == 0 &&
  continuity.dig("currentClusterObservation", "coversIncidentWindow") == false &&
  continuity.dig("currentClusterObservation", "siloStabilityProven") == false
fail_validation("#3290 时间连续性 case gap 未记录") unless
  continuity.dig("coverageGap", "existingRiskCasesCoverTemporalContinuity") == false &&
  continuity.dig("coverageGap", "requiredFutureEvidence").is_a?(Array) &&
  continuity.dig("coverageGap", "requiredFutureEvidence").length == 5

fail_validation("财务源 workflow 未运行清单漂移") unless
  financial.fetch("notRun").map { |item| item.fetch("workflow") } == [
    "P2 send workflow", "P1 v6", "durable/weekly schedule", "P1 v2 legacy definition"
  ]
lark_channel_canary = financial.fetch("larkChannelCanary")
fail_validation("Lark channel canary 摘要与 committed Case 19 证据不一致") unless
  lark_channel_canary["status"] == "validated" &&
  lark_channel_canary["issue"] == "#3087" &&
  lark_channel_canary["runIdHash"] == case19_lark["runIdHash"] &&
  lark_channel_canary["committedTerminalObserved"] == case19_lark["committedTerminalObserved"] &&
  lark_channel_canary["terminalStatus"] == case19_lark["terminalStatus"] &&
  lark_channel_canary["terminalSuccess"] == case19_lark["terminalSuccess"] &&
  lark_channel_canary["larkBotIngressValidated"] == case19_lark["larkBotIngressValidated"] &&
  lark_channel_canary["rawIdentifiersPersisted"] == case19_lark["rawIdentifiersPersisted"]

lark_bot = summary.fetch("larkBotTransportValidation")
fail_validation("Lark Bot 应记录 Aevatar 生产版本") unless
  lark_bot["app"] == "Aevatar" && lark_bot["productionVersion"] == "1.0.10" &&
  lark_bot["releaseStatus"] == "Released" && lark_bot["botEnabled"] == true &&
  lark_bot["availability"] == "All"
fail_validation("Lark Bot 配置证据不完整") unless
  lark_bot["p2pAndGroupReceiveScopesAdded"] == true &&
  lark_bot["integratedMessageScopeAdded"] == true &&
  lark_bot["sendAsBotScopeAdded"] == true &&
  lark_bot["receiveEventTargetsNyxidWebhook"] == true &&
  lark_bot["defaultPrivateConversationRouteActive"] == true &&
  lark_bot["channelBotVerifyCommandSucceeded"] == true
fail_validation("Lark Bot transport 证据不完整") unless
  lark_bot["nyxidBotStatus"] == "active" &&
  lark_bot["webhookRegistered"] == true &&
  lark_bot["webPrivateChatComposerPresent"] == true &&
  lark_bot["inboundEventObserved"] == true &&
  lark_bot["senderBindingResolved"] == true &&
  lark_bot["channelAgentRunStarted"] == true &&
  lark_bot["ornnSearchObserved"] == true &&
  lark_bot["skillLoadAttempted"] == true &&
  lark_bot["replyRelayObserved"] == true &&
  lark_bot["conversationTurnCompleted"] == true &&
  lark_bot["fileUploadCardObserved"] == true &&
  lark_bot["fileContentParseObserved"] == true &&
  lark_bot["fileReplyRelayObserved"] == true
fail_validation("Lark Bot 不得把 transport 成功外推为 workflow 成功") unless
  lark_bot["workflowValidationStatus"] == "typed-failure" &&
  lark_bot["workflowFailureClasses"] == [
    "Skill workflow mounting failed",
    "AgentNotFound",
    "WorkflowExternalCapabilityAdmissionException"
  ] &&
  lark_bot["result"] == "transport 已验证，workflow typed failure"

current_lark_case12 = lark_bot.fetch("currentCase12Canary")
fail_validation("当前 Lark Case 12 canary 缺少严格 committed 证据") unless
  current_lark_case12["deploymentImage"].to_s.end_with?("49cb76e4") &&
  current_lark_case12["deployedCommit"] == "49cb76e4acea8c65b74922e1dcd0949712213903" &&
  current_lark_case12["entryPoint"] == "Lark Aevatar Agent private chat" &&
  current_lark_case12["case"] == "12" &&
  current_lark_case12["workflow"] == "safe_code_execute_validation" &&
  current_lark_case12["syntheticNoSideEffects"] == true &&
  current_lark_case12["catalogBaselineCount"] == 10 &&
  current_lark_case12["catalogDelta"] == 1 &&
  current_lark_case12["ornnSearchObserved"] == true &&
  current_lark_case12["exactSkillMounted"] == true &&
  current_lark_case12["useSkillApprovalCount"] == 1 &&
  current_lark_case12["destructiveApprovalCount"] == 0 &&
  current_lark_case12["workflowStartCount"] == 1 &&
  current_lark_case12["runIdHash"] == "ebe0e10241f0" &&
  current_lark_case12["committedTerminalObserved"] == true &&
  current_lark_case12["terminalStatus"] == "completed" &&
  current_lark_case12["terminalSuccess"] == true &&
  current_lark_case12["stateVersion"] == 33 &&
  current_lark_case12["completedSteps"] == 4 &&
  current_lark_case12["totalSteps"] == 4 &&
  current_lark_case12["firstToolOutputPresent"] == true &&
  RuntimeContracts.mismatch("12", current_lark_case12.fetch("finalArtifact")).nil? &&
  current_lark_case12["botReplyRelayObserved"] == true &&
  current_lark_case12["successJudgedFromCommittedDetail"] == true &&
  current_lark_case12["rawIdentifiersPersisted"] == false &&
  current_lark_case12["sideEffects"] == false &&
  current_lark_case12["workflowValidationStatus"] == "validated"

channel_e2e = summary.fetch("channelE2EAcceptance")
fail_validation("Lark channel E2E 机器证据摘要漂移") unless
  channel_e2e["schemaVersion"] == "1.0" &&
  channel_e2e["requiredDeploymentCommit"] == "de801ca70a37db624b27155c1870d0c99ad93b7c" &&
  channel_e2e["summary"] == {
    "total" => 3,
    "passed" => 3,
    "failed" => 0,
    "pendingDeployment" => 0,
    "pendingExecution" => 0
  }
channel_results = channel_e2e.fetch("results")
fail_validation("Lark channel E2E 案例编号不完整") unless
  channel_results.map { |item| item["case"] } == %w[20 21 22]
channel_case_20 = channel_results.fetch(0)
fail_validation("Lark channel E2E Case 20 缺少首次 mount 批准与 committed 证据") unless
  channel_case_20["status"] == "passed" &&
  channel_case_20["requiredDeploymentCommit"] == "de801ca70a37db624b27155c1870d0c99ad93b7c" &&
  channel_case_20["requiredAncestorsPresent"] == true &&
  channel_case_20["readyProductionWorkloadTraceable"] == true &&
  channel_case_20["mountApprovalCardCount"] == 1 &&
  channel_case_20["mountApprovalDecisionDispatchCount"] == 1 &&
  channel_case_20["mountApprovalIdentityMatched"] == true &&
  channel_case_20["sameAgentRunResolved"] == true &&
  channel_case_20["sameAgentRunResumed"] == true &&
  channel_case_20["useSkillReceiptStatus"] == "Completed" &&
  channel_case_20["mountExecuted"] == true &&
  channel_case_20["workflowStartCalls"] == 1 &&
  channel_case_20["newWorkflowRunCount"] == 1 &&
  channel_case_20["workflowApprovalCardCount"] == 1 &&
  channel_case_20["workflowApprovalDecisionDispatchCount"] == 1 &&
  channel_case_20["sameWorkflowRunResumed"] == true &&
  channel_case_20["terminalStatus"] == "completed" &&
  channel_case_20["workflowTerminalResultCount"] == 1 &&
  channel_case_20["workflowRunHash"] == "e18081f2211b" &&
  channel_case_20["committedStateVersion"] == 30 &&
  channel_case_20["completedSteps"] == 3 && channel_case_20["totalSteps"] == 3 &&
  channel_case_20["requestParametersRedacted"] == true &&
  channel_case_20["outputPreviewIdentifiersRedacted"] == true &&
  channel_case_20["timelineIdentifiersRedacted"] == true &&
  channel_case_20["rawIdentifiersPersisted"] == false
channel_case_21 = channel_results.fetch(1)
fail_validation("Lark channel E2E Case 21 缺少首次 mount 拒绝证据") unless
  channel_case_21["status"] == "passed" &&
  channel_case_21["requiredDeploymentCommit"] == "de801ca70a37db624b27155c1870d0c99ad93b7c" &&
  channel_case_21["requiredAncestorsPresent"] == true &&
  channel_case_21["readyProductionWorkloadTraceable"] == true &&
  channel_case_21["mountApprovalCardCount"] == 1 &&
  channel_case_21["mountApprovalDecisionDispatchCount"] == 1 &&
  channel_case_21["mountApprovalIdentityMatched"] == true &&
  channel_case_21["sameAgentRunResolved"] == true &&
  channel_case_21["sameAgentRunResumed"] == false &&
  channel_case_21["useSkillReceiptStatus"] == "Denied" &&
  channel_case_21["stableErrorCode"] == "approval_denied" &&
  channel_case_21["mountExecuted"] == false &&
  channel_case_21["workflowApprovalCardCount"] == 0 &&
  channel_case_21["workflowStartCalls"] == 0 &&
  channel_case_21["newWorkflowRunCount"] == 0 &&
  channel_case_21["committedTerminalObserved"] == false &&
  channel_case_21["finalArtifact"].nil? &&
  channel_case_21["rawIdentifiersPersisted"] == false
channel_history = channel_e2e.fetch("history")
fail_validation("Lark channel E2E 未保留旧提示词失败历史") unless
  channel_history.length == 1 &&
  channel_history.first["deploymentCommit"] == "ee031038b3d498648d90283b55f6e30a1fa2549f" &&
  channel_history.first["cases"] == %w[20 21] &&
  channel_history.first["stableErrorCode"] == "InvalidWorkflowYaml" &&
  channel_history.first["workflowRunDelta"] == 0 &&
  channel_history.first["supersededByDeploymentCommit"] == "de801ca70a37db624b27155c1870d0c99ad93b7c"
channel_case_22 = channel_results.fetch(2)
fail_validation("Lark channel E2E Case 22 缺少新 run、审批恢复或脱敏 committed 证据") unless
  channel_case_22["status"] == "passed" &&
  channel_case_22["requiredDeploymentCommit"] == "3f62ff62bcb32f7fb7c97aea8a7920aadd29d398" &&
  channel_case_22["requiredAncestorsPresent"] == true &&
  channel_case_22["readyProductionWorkloadTraceable"] == true &&
  channel_case_22["workflowStartCalls"] == 1 &&
  channel_case_22["newWorkflowRunCount"] == 1 &&
  channel_case_22["workflowRunStartedAfterInbound"] == true &&
  channel_case_22["workflowApprovalCardCount"] == 1 &&
  channel_case_22["workflowApprovalDecisionDispatchCount"] == 1 &&
  channel_case_22["ordinaryAgentRunVisibleReplyCount"] == 0 &&
  channel_case_22["awaitingToolApprovalVisibleTextCount"] == 0 &&
  channel_case_22["sameWorkflowRunResumed"] == true &&
  channel_case_22["terminalStatus"] == "completed" &&
  channel_case_22["workflowTerminalResultCount"] == 1 &&
  channel_case_22["workflowRunHash"] == "08cdd96d61dd" &&
  channel_case_22["committedStateVersion"] == 30 &&
  channel_case_22["completedSteps"] == 3 && channel_case_22["totalSteps"] == 3 &&
  channel_case_22["requestParametersRedacted"] == true &&
  channel_case_22["outputPreviewIdentifiersRedacted"] == true &&
  channel_case_22["timelineIdentifiersRedacted"] == true &&
  channel_case_22["rawIdentifiersPersisted"] == false

case14_recovery = summary.fetch("case14PostFailureRecovery")
fail_validation("案例 14 修复后镜像证据缺失") unless
  case14_recovery["deploymentImage"].to_s.end_with?("8cf280e2")
%w[directRun apiChatRun].each do |run_kind|
  run = case14_recovery.fetch(run_kind)
  fail_validation("案例 14 #{run_kind} 修复后未 committed 通过") unless
    run["terminalStatus"] == "completed" && run["success"] == true &&
    run["stateVersion"] == 28 && run["completedSteps"] == 3 && run["totalSteps"] == 3
  fail_validation("案例 14 #{run_kind} run hash 格式错误") unless
    run["runIdHash"].to_s.match?(/\A[0-9a-f]{12}\z/)
end
fail_validation("案例 14 /api/chat 修复后缺少 Ornn mount 证据") unless
  case14_recovery.dig("apiChatRun", "conversationStatus") == "succeeded" &&
  case14_recovery.dig("apiChatRun", "ornnSearchCalls") == 1 &&
  case14_recovery.dig("apiChatRun", "useSkillCalls") == 3 &&
  case14_recovery.dig("apiChatRun", "workflowStartCalls") == 1 &&
  case14_recovery.dig("apiChatRun", "artifactReads") == 2 &&
  case14_recovery.dig("apiChatRun", "toolFailureCodes") == [] &&
  case14_recovery.dig("apiChatRun", "ornnMountSucceeded") == true
lark_retry = case14_recovery.fetch("larkBotRetry")
fail_validation("案例 14 Lark Bot 重试缺少 committed scope blocker") unless
  lark_retry["runIdHash"].to_s.match?(/\A[0-9a-f]{12}\z/) &&
  lark_retry["initialTerminalStatus"] == "awaiting_tool_approval" &&
  lark_retry["initialStateVersion"] == 10 &&
  lark_retry["approvalResumeAccepted"] == true &&
  lark_retry["terminalStatus"] == "failed" &&
  lark_retry["stateVersion"] == 18 &&
  lark_retry["failedStep"] == "resolve_contact" &&
  lark_retry["stableErrorCode"] == "NYXID_PROXY_SERVICE_SCOPE_FORBIDDEN" &&
  lark_retry["success"] == false &&
  lark_retry["resolvedCount"].nil? &&
  lark_retry["identifiersRedacted"] == true
fail_validation("案例 14 Lark Bot 发送者 consent 诊断不完整") unless
  lark_retry["senderConsentAllowAllServices"] == false &&
  lark_retry["senderConsentAllowedServiceSlugs"] ==
    %w[aevatar chrono-llm-public ornn-api chrono-sandbox] &&
  lark_retry["larkUserServicePresent"] == false
fail_validation("案例 14 Lark Bot 辅助工具 receipt 缺陷未保留") unless
  lark_retry["toolReceiptDefects"] == [
    "Skill workflow mounting failed",
    "scope_workflows_get outcome unverified",
    "scope_workflows_list outcome unverified"
  ]
second_lark_retry = case14_recovery.fetch("larkBotRetryAfterServiceReview")
fail_validation("案例 14 第二次 Lark Bot 重试缺少 committed scope blocker") unless
  second_lark_retry["runIdHash"].to_s.match?(/\A[0-9a-f]{12}\z/) &&
  second_lark_retry["initialTerminalStatus"] == "awaiting_tool_approval" &&
  second_lark_retry["initialStateVersion"] == 10 &&
  second_lark_retry["approvalResumeAccepted"] == true &&
  second_lark_retry["terminalStatus"] == "failed" &&
  second_lark_retry["stateVersion"] == 17 &&
  second_lark_retry["failedStep"] == "resolve_contact" &&
  second_lark_retry["stableErrorCode"] == "NYXID_PROXY_SERVICE_SCOPE_FORBIDDEN" &&
  second_lark_retry["success"] == false &&
  second_lark_retry["resolvedCount"].nil? &&
  second_lark_retry["identifiersRedacted"] == true &&
  second_lark_retry["senderConsentGrantedAt"] == "2026-08-05T10:28:25.968Z" &&
  second_lark_retry["senderBindingCreatedAt"] == "2026-08-05T10:28:27.600Z" &&
  second_lark_retry["larkUserServiceIdHash"].to_s.match?(/\A[0-9a-f]{12}\z/) &&
  second_lark_retry["ornnWorkflowUserServiceIdHash"] == second_lark_retry["larkUserServiceIdHash"] &&
  second_lark_retry["consentContainsMatchingLarkUserServiceId"] == true &&
  second_lark_retry["bindingStillProducedServiceScopeForbidden"] == true
default_repair = case14_recovery.fetch("developerAppDefaultServiceRepair")
fail_validation("案例 14 Developer App 默认 service 修复未回读") unless
  default_repair["clientName"] == "aevatar" &&
  default_repair["clientActive"] == true &&
  default_repair["brokerCapabilityEnabled"] == true &&
  default_repair["previousDefaultServiceCatalogSlugs"] ==
    %w[chrono-llm-public aevatar chrono-sandbox ornn-api] &&
  default_repair["currentDefaultServiceCatalogSlugs"] ==
    %w[chrono-llm-public aevatar chrono-sandbox ornn-api api-lark-bot] &&
  default_repair["larkDefaultPresent"] == true &&
  default_repair["requiresFreshInit"] == true &&
  default_repair["postRepairFreshInitObserved"] == true &&
  default_repair["postRepairCase14RunObserved"] == true &&
  default_repair["defaultRepairSufficient"] == false
fresh_binding = case14_recovery.fetch("freshInitBinding")
fail_validation("案例 14 fresh /init binding 证据不完整") unless
  fresh_binding["consentGrantedAt"] == "2026-08-05T11:34:40.784Z" &&
  fresh_binding["bindingCreatedAt"] == "2026-08-05T11:34:42.242Z" &&
  fresh_binding["consentAllowAllServices"] == true &&
  fresh_binding["consentAllowedServiceCount"] == 0 &&
  fresh_binding["bindingLastUsedAt"] == "2026-08-05T13:36:45.455Z"
fresh_retry = case14_recovery.fetch("larkBotRetryAfterFreshInit")
fail_validation("案例 14 fresh /init 后缺少 committed scope blocker") unless
  fresh_retry["deploymentImage"].to_s.end_with?("e30fdd94") &&
  fresh_retry["runIdHash"].to_s.match?(/\A[0-9a-f]{12}\z/) &&
  fresh_retry["terminalStatus"] == "failed" &&
  fresh_retry["stateVersion"] == 14 &&
  fresh_retry["failedStep"] == "resolve_contact" &&
  fresh_retry["stableErrorCode"] == "NYXID_PROXY_SERVICE_SCOPE_FORBIDDEN" &&
  fresh_retry["success"] == false &&
  fresh_retry["resolvedCount"].nil? &&
  fresh_retry["identifiersRedacted"] == true
resource_diagnosis = case14_recovery.fetch("oauthResourceNarrowingDiagnosis")
fail_validation("案例 14 OAuth resource narrowing 诊断不完整") unless
  resource_diagnosis["evidenceType"] == "production-readback-plus-source-contract" &&
  resource_diagnosis["aevatarAuthorizeIncludesExplicitCoreResources"] == true &&
  resource_diagnosis["aevatarAuthorizeIncludesLarkResource"] == false &&
  resource_diagnosis["nyxidNarrowsAllowAllAuthorizationCodeToExplicitResources"] == true &&
  resource_diagnosis["developerAppDefaultsAffectConsentHintsOnly"] == true &&
  resource_diagnosis["freshInitCanRepairCurrentBinding"] == false
fail_validation("案例 14 fresh /init 后 channel receipt 缺陷未保留") unless
  case14_recovery["freshInitChannelReceiptDefects"] == [
    "Skill workflow mounting failed",
    "aevatar_start_workflow InvalidWorkflowYaml"
  ]

readme = File.read(File.join(ROOT, "README.md"))
current_status_report = File.read(File.join(ROOT, "report", "2026-08-07-current-status-report.md"))
full_revalidation = JSON.parse(File.read(File.join(ROOT, "validation", "full-revalidation-2026-08-07.json")))
continuity_observation = full_revalidation.dig("postSnapshotBoundary", "observations").find do |item|
  item["surface"] == "source-migration-continuity"
end
fail_validation("full revalidation 缺少 #3290 窗口后连续性观测") unless
  continuity_observation &&
  continuity_observation["evidenceSource"] == continuity["evidenceSource"] &&
  continuity_observation["evidenceKind"] == "external_issue_report" &&
  continuity_observation["independentlyRerunByAcceptanceRepository"] == false &&
  continuity_observation["status"] == "regression-blocked" &&
  continuity_observation["p2CompletedSteps"] == 14 &&
  continuity_observation["p2TotalSteps"] == 14 &&
  continuity_observation["p2RuntimeStableErrorCode"] == "NYXID_PROXY_HTTP_502" &&
  continuity_observation["identicalDefinitionAdmissionFailureCount"] == 5 &&
  continuity_observation["admissionStableErrorCode"] == "NYXID_ADMISSION_SOURCE_CREDENTIAL_REQUIRED" &&
  continuity_observation["p1CompletedSteps"] == 0 &&
  continuity_observation["p1TotalSteps"] == 27 &&
  continuity_observation["currentPodCoversIncidentWindow"] == false &&
  continuity_observation["siloStabilityProven"] == false &&
  continuity_observation["existingRiskCasesCoverTemporalContinuity"] == false &&
  continuity_observation["changesFullSnapshotSummary"] == false
EXPECTED_WORKFLOW_CASES.each do |case_id|
  workflow_path = Dir[File.join(ROOT, "workflows", "#{case_id}-*.workflow.yaml")].first
  fail_validation("缺少案例 #{case_id} 的 workflow") unless workflow_path

  workflow = YAML.safe_load(File.read(workflow_path), aliases: false)
  row = readme.lines.find { |line| line.start_with?("| #{case_id} |") }
  fail_validation("README 缺少案例 #{case_id}") unless row

  cells = row.split("|").map(&:strip)
  fail_validation("README 案例 #{case_id} 名称漂移") unless cells[2] == "`#{workflow.fetch('name')}`"
  fail_validation("README 案例 #{case_id} 步骤数漂移") unless cells[3].to_i == workflow.fetch("steps").length
end

html = File.read(File.join(ROOT, "report", "index.html"))
html_case_ids = html.scan(/<tr data-result="(?:passed|blocked|regression|unverified)"[^>]*><td class="case-id">(\d{2})<\/td>/).flatten
fail_validation("分析页历史基线案例编号不完整") unless html_case_ids == EXPECTED_CASES

runtime.each do |item|
  result = case item.fetch("result")
           when "通过" then "passed"
           when "平台阻塞" then "blocked"
           when "契约回归" then "regression"
           when "待验证" then "unverified"
           end
  row_pattern = /<tr data-result="#{result}"[^>]*><td class="case-id">#{item.fetch('case')}<\/td>.*?<\/tr>/m
  row = html.match(row_pattern)&.to_s
  fail_validation("分析页案例 #{item.fetch('case')} 结果与机器摘要不一致") unless row
  next unless item["stateVersion"]

  evidence_pattern = /<td class="number">#{item.fetch('completedSteps')}<\/td><td class="number">#{item.fetch('stateVersion')}<\/td>/
  fail_validation("分析页案例 #{item.fetch('case')} 步骤或 stateVersion 漂移") unless row.match?(evidence_pattern)
end

all_new_workflow_results = probe_results + composition_results + integration_results
html_probe_rows = html.scan(/<tr data-risk-workflow-case="(\d{2})" data-risk-workflow-status="([^"]+)">/)
fail_validation("分析页 21-29 可靠性 workflow 不完整") unless
  html_probe_rows == all_new_workflow_results.map do |item|
    [item.fetch("case"), item.fetch("terminalStatus") == "completed" ? "passed" : "failed"]
  end
all_new_workflow_results.each do |item|
  case_id = item.fetch("case")
  row = html.match(/<tr data-risk-workflow-case="#{case_id}"[^>]*>.*?<\/tr>/m)&.to_s
  if item["terminalStatus"] == "completed"
    fail_validation("分析页缺少新增 workflow #{case_id} 的严格通过状态") unless
      row&.include?('<span class="status status-passed">通过</span>') &&
      row.include?("#{item.fetch('completedSteps')}/#{item.fetch('totalSteps')} completed")
  else
    fail_validation("分析页缺少新增 workflow #{case_id} 的最新失败状态") unless
      row&.include?('<span class="status status-blocked">失败</span>') &&
      row.include?(item.fetch("failingStep")) && row.include?("failed")
  end
end

html_risk_rows = html.scan(/<tr data-risk-case="(\d{2})" data-risk-status="([^"]+)">/)
expected_html_risk_rows = risk_results.map { |item| [item.fetch("case"), item.fetch("status")] }
fail_validation("分析页 Risk 23-43 状态与机器摘要不一致") unless html_risk_rows == expected_html_risk_rows

assistant.fetch("results").each do |item|
  case_id = item.fetch("case")
  status = item.fetch("workflowValidationStatus")
  row_pattern = /<tr data-chat-case="#{Regexp.escape(case_id)}">.*?<span class="status [^"]+">#{Regexp.escape(status)}<\/span>.*?<\/tr>/m
  row = html.match(row_pattern)&.to_s
  fail_validation("分析页 /api/chat 案例 #{case_id} 状态与机器摘要不一致") unless row

  inline_fallback = item["inlineFallback"].to_s
  next if inline_fallback.empty?

  fail_validation("分析页 /api/chat 案例 #{case_id} 缺少 inline fallback 证据") unless row.include?(inline_fallback)
end

expected_html_counts = {
  "源版本族" => [/<tr data-source-family=/, 7],
  "能力矩阵" => [/<tr data-family=/, 19],
  "历史直接证据" => [/<tr data-result=/, 20],
  "新增可靠性 workflow" => [/<tr data-risk-workflow-case=/, 9],
  "风险案例" => [/<tr data-risk-case=/, 21],
  "自然语言证据" => [/<tr data-chat-case=/, 5],
  "Lark channel E2E 证据" => [/<tr data-channel-case=/, 3],
  "阻塞项" => [/<div class="gap-row">/, 3],
  "修复记录" => [/<div class="repair-item">/, 13]
}
expected_html_counts.each do |label, (pattern, expected)|
  actual = html.scan(pattern).length
  fail_validation("分析页#{label}数量为 #{actual}，预期 #{expected}") unless actual == expected
end

report = File.read(File.join(ROOT, "report", "#{REPORT_DATE}-workflow-coverage-report.md"))
fail_validation("README 缺少 29 workflows + 3 channel + 21 risk cases 口径") unless
  readme.include?("29 个 workflow + 3 个 Lark channel E2E case + 21 个风险验收 case") &&
  readme.include?("3/3 个 Lark channel E2E case 已严格通过") &&
  readme.include?("`de801ca70`") && readme.include?("`InvalidWorkflowYaml`")
fail_validation("文字报告缺少 #3210 的 mount 与 workflow 运行期审批 channel cases") unless
  report.include?("## Lark channel E2E 案例（#3210）") &&
  report.include?("Case 20") && report.include?("Case 21") && report.include?("Case 22") &&
  report.include?("`approval_denied`") && report.include?("`awaiting_tool_approval`") &&
  report.include?("`InvalidWorkflowYaml`") && report.include?("`e18081f2211b`") &&
  report.include?("`08cdd96d61dd`")
channel_html_rows = html.scan(/<tr data-channel-case="(?:20|21|22)"[^>]*>.*?<\/tr>/m)
fail_validation("分析页缺少 3/3 Lark channel E2E 严格通过状态") unless
  html.include?("3 / 3") && html.include?("Lark channel E2E 严格通过") &&
  channel_html_rows.length == 3 &&
  channel_html_rows.all? do |row|
    row.include?('data-channel-status="passed"') &&
      row.include?('<span class="status status-passed">validated</span>') &&
      !row.include?("status-pending")
  end &&
  html.include?("e18081f2211b") && html.include?("approval_denied")
fail_validation("文字报告缺少案例 11 managed codex_exec 修复闭环") unless
  report.include?("## Managed codex_exec 修复与生产复验") &&
  report.include?("`Authorization: Bearer`") && report.include?("`forward_access_token=true`") &&
  report.include?("提交 `f7f543c51` 增加 bounded `X-API-Key` 代理入口") &&
  report.include?("`NyxIdApiClientBoundedProxyTests` 3/3") &&
  report.include?("`NyxIdManagedCodexChronoTransportTests` 16/16") &&
  report.include?("run hash `fa77c0c49035`") && report.include?("state 179、30/30 步") &&
  report.include?("`parallel_check_count=5`") && report.include?("`side_effects=false`") &&
  report.include?("`6558db8db`") && report.include?("`eead35c0`") &&
  report.include?("`106ecf7b750a`") && report.include?("`39a374f8815a`") &&
  report.include?("`705a69901de5`") &&
  report.include?("`4caa726585f6`") && report.include?("`codex_execution_capacity_unavailable`") &&
  report.include?("HTTP 502") && report.include?("Case 11 已验证阻塞")
fail_validation("分析页缺少案例 11 managed codex_exec 修复闭环") unless
  html.include?("Managed codex_exec 当前 capacity 阻塞") &&
  html.include?("两次 <code>codex_execution_admission_denied</code>") &&
  html.include?("<code>f7f543c51</code>") &&
  html.include?("committed <code>completed</code>（state 179，30/30）") &&
  html.include?("<code>CODEX_EXEC_READY</code>") &&
  html.include?("<code>6558db8db</code>") && html.include?("<code>eead35c0</code>") &&
  html.include?("<code>106ecf7b750a</code>") && html.include?("<code>39a374f8815a</code>") &&
  html.include?("<code>705a69901de5</code>") &&
  html.include?("<code>4caa726585f6</code>") && html.include?("HTTP 502") &&
  html.include?("<code>codex_execution_capacity_unavailable</code>") &&
  html.include?("<span class=\"status status-blocked\">已验证阻塞</span>")
fail_validation("文字报告缺少 41 个非 n8n 定义口径") unless report.include?("只比较其余 41 个定义")
fail_validation("文字报告缺少 #3182 证据边界") unless report.include?("`#3182`")
fail_validation("文字报告缺少 #3161 定向回归边界") unless report.include?("`#3161`")
fail_validation("文字报告缺少 #3184 定向回归边界") unless report.include?("`#3184`")
fail_validation("文字报告缺少 /api/chat 与 Lark Bot 区分") unless report.include?("`/api/chat` 与 Lark Bot")
fail_validation("README 缺少案例 15 artifact identity 回归证据") unless readme.include?("`d7844b5e`")
fail_validation("文字报告缺少案例 15 artifact identity 回归证据") unless report.include?("`d7844b5e`")
fail_validation("分析页缺少案例 15 artifact identity 回归证据") unless html.include?("d7844b5e")
fail_validation("分析页缺少实际路径口径") unless html.include?("~/Code/workflows") && html.include?("~/workflows")
fail_validation("分析页缺少当前 2/2 与历史 5/5 自然语言边界") unless
  html.include?('<span class="metric-value">2 / 2</span><span class="metric-label">当前 /api/chat 代表对照</span>') &&
  html.include?("历史基线") && html.include?("5/5 validated") &&
  html.scan(/<tr data-current-chat-case="(?:01|12)" data-current-chat-status="validated">/).length == 2 &&
  html.include?("6fa89cd62b15") && html.include?("total_cents=16623")
fail_validation("README 缺少财务源 workflow post-fix 验收") unless
  readme.include?("财务源工作流 post-fix 验收") && readme.include?("单步 `code_execute` probe") &&
  readme.include?("8/8 completed") &&
  readme.include?("14/14 实际步骤") && readme.include?("2/2 completed")
fail_validation("文字报告缺少财务源 workflow post-fix 验收") unless
  report.include?("财务源工作流 post-fix 验收") && report.include?("单步 `code_execute` probe") &&
  report.include?("8/8 completed") && report.include?("14/14 实际步骤 completed") &&
  report.include?("2/2 completed")
fail_validation("分析页缺少四项历史成功和一项当前连续性阻塞证据") unless
  html.scan(/<tr data-finance-result="passed">/).length == 4 &&
  html.scan(/<tr data-finance-result="blocked">/).length == 1 &&
  html.include?("data-source-financial-acceptance=\"historical-validated-current-blocked\"")
fail_validation("报告把安全限制未运行的财务分支伪报为成功") unless
  [readme, report, html].all? { |document| document.include?("P2 send") && document.include?("P1 v6") }
fail_validation("README/Markdown/HTML 未同步 #3290 当前连续性阻塞") unless
  [readme, report, html, current_status_report].all? do |document|
    document.include?("#3290") &&
      document.include?("NYXID_ADMISSION_SOURCE_CREDENTIAL_REQUIRED") &&
      document.include?("NYXID_PROXY_HTTP_502") &&
      document.include?("Forwarding failed") &&
      document.include?("regression-blocked")
  end
fail_validation("报告未明确现有 case 的时间/silo 连续性缺口") unless
  [readme, report, html, current_status_report].all? do |document|
    document.include?("Risk 28") && document.include?("Risk 29") &&
      document.include?("Risk 40") && document.include?("Risk 41")
  end &&
  current_status_report.include?("cluster silo stability 仍未证明")
fail_validation("README 缺少 Durable schedule 生产闭环") unless
  readme.include?("Durable schedule 已在 Ready `4c0596c7` fresh 重跑完整闭环") &&
  readme.include?("run hash `b9859494e2a9`") &&
  readme.include?("binding committed `succeeded`（state 7）") &&
  readme.include?("provisioning committed `succeeded`（state 11，attempt 2）") &&
  readme.include?("Typed DELETE 返回 `accepted/pending`") &&
  readme.include?("owner list 为 0") && readme.include?("run count 保持 `1 -> 1`") &&
  readme.include?("相关修复提交 `748f98e7d`、`7a7781067` 和 `b010ba614`") &&
  readme.include?("HTTP 200 `confirmation_required`") &&
  readme.include?("HTTP 202 typed `pending_binding` receipt") &&
  readme.include?("`NyxIdOperationAuthorityContractUnavailable`") &&
  readme.include?("`fireCount=6`") && readme.include?("`failureCount=0`") &&
  readme.include?("`6 -> 6`") &&
  readme.include?("编译修复提交 `b010ba614`") && readme.include?("真实 `linux/amd64` Docker build")
fail_validation("文字报告缺少 Durable schedule 分阶段生产闭环") unless
  report.include?("## Durable schedule 修复进度") &&
  report.include?("当前 Ready `4c0596c7` 上的 fresh NyxID 端到端复验") &&
  report.include?("当前 Ready fresh 复验") &&
  report.include?("run hash `b9859494e2a9`") &&
  report.include?("Typed DELETE 后 detail 不存在、owner list 0") &&
  report.include?("run `1 -> 1`") &&
  report.include?("schedule endpoint 返回 HTTP 502") &&
  report.include?("`748f98e7d` 已提交、推送并部署") &&
  report.include?("真实验收入口") &&
  report.include?("HTTP 200 `confirmation_required`") && report.include?("HTTP 202 typed receipt") &&
  report.include?("binding state 7、provisioning state 11 / attempt 2 committed `succeeded`") &&
  report.include?("`NyxIdOperationAuthorityContractUnavailable`") &&
  report.include?("`7a7781067` 已进入 `origin/feature/integrate`，并在历史 `b010ba614` / `b010ba61` 部署完成验证") &&
  report.include?("仅 binder-attested `READ_ONLY` GET/HEAD/OPTIONS") &&
  report.include?("schedule/operation ID 均非空") &&
  report.include?("`fireCount=6`") && report.include?("`failureCount=0`") &&
  report.include?("11/11 committed `completed`") &&
  report.include?("NyxID DELETE 返回 typed accepted receipt") && report.include?("`6 -> 6`") &&
  report.include?("23/23") && report.include?("1730/1730") && report.include?("152/152") &&
  report.include?("Mainnet DI composition 1/1") && report.include?("Studio DI/executor 11/11") &&
  report.include?("Capabilities 642/642") && report.include?("真实 `linux/amd64` Docker build") &&
  report.include?("排除 3 个本机 Redis 版本契约用例后的 solution tests")
fail_validation("分析页缺少 Durable schedule 生产闭环") unless
  html.include?("data-current-schedule-proof=\"validated\"") &&
  html.include?("data-current-schedule-validation=\"passed\"") &&
  html.include?("Durable schedule 当前 fresh 闭环") &&
  html.include?("Ready <code>4c0596c7</code>") &&
  html.include?("run <code>b9859494e2a9</code>") &&
  html.include?("run count 保持 1") &&
  html.include?("Durable schedule provisioning") &&
  html.include?("历史 <code>b010ba614</code> / <code>b010ba61</code>") &&
  html.include?("<code>NyxIdOperationAuthorityContractUnavailable</code>") &&
  html.include?("schedule/operation ID 均非空") &&
  html.include?("六次真实 cron fire=6/failure=0") &&
  html.include?("workflow 11/11 committed <code>completed</code>") &&
  html.include?("DELETE typed accepted 后 detail 消失、owner list 归零") &&
  html.include?("真实 linux/amd64 镜像构建")
stale_schedule_claims = [
  "线上阻塞 / 源码待部署",
  "当前待部署和真实 schedule E2E 复验",
  "截至 2026-08-06 生产仍是",
  "全量测试未绿"
]
stale_schedule_claims.each do |claim|
  fail_validation("报告仍包含过期 Durable schedule 状态：#{claim}") if
    [readme, report, html].any? { |document| document.include?(claim) }
end
fail_validation("README 缺少当前 29-case 严格回归口径") unless
  readme.include?("21/22/23 在用 `config.local.yaml` 重新物化后 fresh committed `completed`") &&
  readme.include?("共创建 4 条固定合成 Base 探针记录") &&
  readme.include?("连同 2 条同契约历史残留精确清理") && readme.include?("回读匹配数为 0") &&
  readme.include?("29/29 个严格业务 artifact contract") &&
  readme.include?("当前直接 runtime 严格结果为 28/29") &&
  readme.include?("a729912ee5d9") && readme.include?("skipped-expired") &&
  readme.include?("严格状态升级为 `validated`") &&
  readme.include?("`03c3f4ded68e`") && readme.include?("114 字节") && readme.include?("113 字节")
fail_validation("文字报告缺少当前 29-case 严格回归口径") unless
  report.include?("当前 Ready 生产镜像 `eead35c0`") &&
  report.include?("旧 01-10、13-20 保留既有 committed 基线") &&
  report.include?("当前直接 runtime 严格结果为 28/29") &&
  report.include?("新增 21-25 当前最新结果为 5/5 completed") &&
  report.include?("29/29 个 strict artifact contract") &&
  report.include?("0 pending-execution") &&
  report.include?("29/29 format、精确名称、版本与 public readback") &&
  report.include?("a729912ee5d9") && report.include?("skipped-expired") &&
  report.include?("回读匹配数为 0") &&
  report.include?("`03c3f4ded68e`") && report.include?("114 字节") && report.include?("113 字节")
fail_validation("分析页缺少当前 29-case 严格回归口径") unless
  html.scan('<span class="metric-value">29 / 29</span>').length == 3 &&
  html.include?('<span class="metric-value">28 / 29</span><span class="metric-label">直接 runtime 严格通过</span>') &&
  html.include?("9/9 committed completed") &&
  html.include?("<strong>当前部署：</strong><code>eead35c0</code>") &&
  html.include?("29/29 个 typed artifact contract") &&
  html.include?("a729912ee5d9") && html.include?("skipped-expired") &&
  html.include?("fresh 写探针共创建 4 条固定合成记录") && html.include?("回读匹配数为 0") &&
  html.include?("<code>03c3f4ded68e</code>") && html.include?("114 字节") && html.include?("113 字节")
fail_validation("分析页阻塞状态未使用红色") unless
  html.include?(".status-blocked { background: var(--red-soft); color: var(--red); }")
fail_validation("分析页仍把已验证失败或回归显示为蓝色") if
  html.match?(/<span class="status status-partial">[^<]*(?:契约回归|已验证阻塞)/)
fail_validation("分析页不应再有审批契约回归状态") unless
  html.scan(/<span class="status status-blocked">契约回归<\/span>/).empty?
fail_validation("分析页当前执行 blocker 未标红") unless
  html.include?("<span class=\"status status-blocked\">已验证阻塞</span>") &&
  html.include?("普通 code_execute authority") &&
  html.include?("三层严格成功") && html.include?("<span class=\"status status-covered\">已恢复</span>")
fail_validation("分析页仍把历史 Lark sender 症状列为当前 blocker") if
  html.include?("P1 已验证阻塞") || html.include?("Lark Bot sender service grant")
%w[USE_SKILL_MOUNT_FAILED CAPABILITY_ADMISSION_REBIND_REQUIRED].each do |closed_blocker|
  fail_validation("分析页仍把已关闭症状列为当前阻塞：#{closed_blocker}") if html.include?(closed_blocker)
end
fail_validation("分析页仍把 contact 权限列为当前阻塞") if html.include?("contact 权限与通用 code 阻塞")

issue_regression_path = File.join(
  ROOT,
  "validation",
  "issue-3161-author-regression-#{REPORT_DATE}.json"
)
issue_regression = JSON.parse(File.read(issue_regression_path))
fail_validation("#3161 作者历史 issue 数量或顺序漂移") unless
  issue_regression.dig("selection", "issueCount") == EXPECTED_ISSUE_3161_AUTHOR_HISTORY.length &&
  issue_regression.dig("selection", "issues") == EXPECTED_ISSUE_3161_AUTHOR_HISTORY
fail_validation("#3161 作者识别漂移") unless issue_regression.dig("anchorIssue", "author") == "jianwei-su"

focused_results = issue_regression.dig("productionRegression", "results")
fail_validation("#3161 作者定向回归案例漂移") unless focused_results.map { |item| item.fetch("case") } == %w[13 15 16]
focused_results.each do |item|
  case_id = item.fetch("case")
  fail_validation("定向回归案例 #{case_id} 不是 committed completed") unless item["terminalStatus"] == "completed"
  fail_validation("定向回归案例 #{case_id} 步骤证据不完整") unless
    item["completedSteps"].is_a?(Integer) && item["completedSteps"] == item["totalSteps"]
  fail_validation("定向回归案例 #{case_id} run hash 格式错误") unless item["runIdHash"].to_s.match?(/\A[0-9a-f]{12}\z/)
  fail_validation("定向回归案例 #{case_id} 不得有副作用") unless item["sideEffects"] == false
end
fail_validation("#3161 作者定向回归顶层副作用标记错误") unless
  issue_regression.dig("productionRegression", "sideEffects") == false

issue_coverage = issue_regression.fetch("issueCoverage")
fail_validation("#3161 作者 issue 覆盖矩阵漂移") unless
  issue_coverage.map { |item| item.fetch("issue") } == EXPECTED_ISSUE_3161_AUTHOR_HISTORY
issue_coverage.each do |item|
  fail_validation("issue ##{item.fetch('issue')} 缺少证据边界") if item["boundary"].to_s.strip.empty?
end

anchor_coverage = issue_regression.fetch("anchorCoverage")
source_p2_regression = issue_regression.fetch("sourceWorkflowAcceptance")
fail_validation("#3161 锚点仍未同步源 P2 authority 验收") unless
  anchor_coverage["status"] == "validated" &&
  anchor_coverage["existingCases"] == ["16", "source-p2-no-send"] &&
  source_p2_regression["deploymentCommit"] == "71a38ff5" &&
  source_p2_regression.dig("preview", "callSiteCount") == 6 &&
  source_p2_regression.dig("preview", "uniqueCallSiteCount") == 6 &&
  source_p2_regression.dig("preview", "readOnly") == true &&
  source_p2_regression["invokeCount"] == 1 &&
  source_p2_regression["terminalStatus"] == "completed" &&
  source_p2_regression["lastSuccess"] == true &&
  source_p2_regression["completedSteps"] == 8 &&
  source_p2_regression["totalSteps"] == 8 &&
  source_p2_regression["typedErrorClasses"] == [] &&
  source_p2_regression["messagesSent"] == false &&
  source_p2_regression["scheduleCreated"] == false

focused_report = File.read(File.join(ROOT, "report", "#{REPORT_DATE}-issue-3161-author-regression.md"))
EXPECTED_ISSUE_3161_AUTHOR_HISTORY.each do |issue_number|
  fail_validation("定向报告缺少 issue ##{issue_number}") unless
    focused_report.include?("https://github.com/aevatarAI/aevatar/issues/#{issue_number}")
end
fail_validation("定向报告缺少机器摘要链接") unless
  focused_report.include?("validation/issue-3161-author-regression-#{REPORT_DATE}.json")
fail_validation("定向报告仍把 #3161 authority 写成待复测") unless
  focused_report.include?("补齐了 #3161 的真实 published-operation authority 主链") &&
  focused_report.include?("只覆盖 no-send 只读执行")

puts "通过 workflow=#{EXPECTED_WORKFLOW_CASES.length} 历史直接案例=20 新增探针=5 风险案例=21 财务源验收=4 " \
     "源版本族=7 能力矩阵=19 自然语言=5 阻塞=3 修复记录=13"
