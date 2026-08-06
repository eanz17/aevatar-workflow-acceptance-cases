#!/usr/bin/env ruby

require "json"
require "yaml"

ROOT = File.expand_path("..", __dir__)
EXPECTED_CASES = (1..20).map { |number| format("%02d", number) }.freeze
EXPECTED_BLOCKED = [].freeze
EXPECTED_CONTRACT_REGRESSIONS = [].freeze
EXPECTED_UNVERIFIED = [].freeze
EXPECTED_ISSUE_3161_AUTHOR_HISTORY = [2411, 2412, 2447, 2944, 2958, 2999, 3000, 3001, 3061, 3086, 3087].freeze
REPORT_DATE = "2026-08-05"

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
fail_validation("直接 runtime 严格通过数不是 20") unless summary.dig("directRuntimeSummary", "passed") == 20
fail_validation("直接 runtime 平台阻塞数不是 0") unless summary.dig("directRuntimeSummary", "platformBlocked") == 0
fail_validation("直接 runtime 契约回归数不是 0") unless summary.dig("directRuntimeSummary", "contractRegressions") == 0
fail_validation("直接 runtime completed 数不是 20") unless summary.dig("directRuntimeSummary", "terminalCompleted") == 20
fail_validation("直接 runtime failed 数不是 0") unless summary.dig("directRuntimeSummary", "terminalFailed") == 0
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
  "side_effects" => false
}
case19_lark = case19.fetch("larkBotCanary")
fail_validation("案例 19 Lark canary 不得伪报 workflow 成功") unless
  case19_lark["fileUploadCardObserved"] == true &&
  case19_lark["inboundFileContentParsed"] == true &&
  case19_lark["replyRelayObserved"] == true &&
  case19_lark["workflowStartAttempts"] == 3 &&
  case19_lark["workflowValidationStatus"] == "start-blocked" &&
  case19_lark["stableErrorCode"] == "service_catalog_missing" &&
  case19_lark["newWorkflowRunCount"] == 0 &&
  case19_lark["committedTerminalObserved"] == false &&
  case19_lark["larkBotIngressValidated"] == false &&
  case19_lark["rawIdentifiersPersisted"] == false &&
  case19_lark["sideEffects"] == false

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

case12 = summary.fetch("case12RecoveryValidation")
fail_validation("案例 12 恢复证据不完整") unless
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

ornn = summary.fetch("ornnPublication")
fail_validation("本地 Ornn skill 数不是 20") unless ornn.fetch("localSkillCount") == 19
%w[skillCount serverFormatValidated publishedPublic nameReadbackPassed].each do |field|
  fail_validation("Ornn #{field} 不是 15") unless ornn.fetch(field) == 15
end

assistant = summary.fetch("assistantNaturalLanguage")
fail_validation("/api/chat 案例数不是 5") unless assistant.fetch("cases") == 5
fail_validation("/api/chat completed 数不是 5") unless assistant.fetch("chatCompleted") == 5
fail_validation("/api/chat validated 数不是 4") unless assistant.fetch("workflowValidated") == 4
fail_validation("/api/chat typed failure 数不是 1") unless assistant.fetch("workflowTypedFailures") == 1
fail_validation("/api/chat 案例编号漂移") unless assistant.fetch("results").map { |item| item.fetch("case") } == %w[01 12 13 14 15]
fail_validation("/api/chat 未全部搜索 Ornn") unless assistant.fetch("results").all? { |item| item["ornnSearch"] == true }
fail_validation("/api/chat 未全部加载 skill") unless assistant.fetch("results").all? { |item| item["skillLoaded"] == true }
fail_validation("/api/chat 未全部启动 workflow") unless assistant.fetch("results").all? { |item| item["workflowStarted"] == true }

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
  case15_assistant["runIdHash"] == case15_artifact["runIdHash"] &&
  case15_assistant["assistantReportedCommittedArtifact"] == true &&
  case15_assistant["artifactPendingReportedAsFinal"] == false

current_deployment = summary.fetch("currentDeployment")
fail_validation("当前部署证据不完整") unless
  summary["updatedAtUtc"] == "2026-08-06T03:35:16Z" &&
  summary["deployedCommit"] == "20d9ba410d8fe29f0a0ede8e41050743f6de3de4" &&
  summary["deploymentImage"].to_s.end_with?("20d9ba41") &&
  current_deployment["observedAtUtc"] == "2026-08-06T02:52:00Z" &&
  current_deployment["deployedCommit"] == "20d9ba410d8fe29f0a0ede8e41050743f6de3de4" &&
  current_deployment["healthyReplicas"] == "1/1" &&
  current_deployment["podRestarts"] == 0 &&
  current_deployment["containsFixCommits"] ==
    %w[03389d0ae 71a38ff59 7ad633e6f e30fdd94a 53e20f9ba 748f98e7d f7f543c51 7a7781067 b010ba614 5a0b545d8 e1aedcae7 20d9ba410] &&
  current_deployment["productionVerificationWindowUtc"] == {
    "startedAt" => "2026-08-06T02:52:00Z",
    "completedAt" => "2026-08-06T03:35:16Z"
  } &&
  current_deployment["postDeploymentLogCountersSampled"] == false

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
fail_validation("财务源 workflow 未运行清单漂移") unless
  financial.fetch("notRun").map { |item| item.fetch("workflow") } == [
    "P2 send workflow", "P1 v6", "durable/weekly schedule", "P1 v2 legacy definition"
  ]
fail_validation("Lark channel canary 不得伪报成功") unless
  financial.dig("larkChannelCanary", "status") == "unproven" &&
  financial.dig("larkChannelCanary", "issue") == "#3087"

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

channel_e2e = summary.fetch("channelE2EAcceptance")
fail_validation("Lark channel E2E 机器证据摘要漂移") unless
  channel_e2e["schemaVersion"] == "1.0" &&
  channel_e2e["requiredDeploymentCommit"] == "b7cacf1838a519e83fbfd70953be988b9696ee2b" &&
  channel_e2e["summary"] == {
    "total" => 3,
    "passed" => 0,
    "failed" => 0,
    "pendingDeployment" => 3
  }
channel_results = channel_e2e.fetch("results")
fail_validation("Lark channel E2E 案例编号不完整") unless
  channel_results.map { |item| item["case"] } == %w[20 21 22]
fail_validation("Lark channel E2E 尚未部署时不得伪报通过") unless
  channel_results.all? do |item|
    item["status"] == "pending-deployment" &&
      item["readyProductionWorkloadTraceable"] == false &&
      item["deploymentCommit"].nil? && item["committedTerminalObserved"].nil? &&
      item["terminalStatus"].nil? && item["finalArtifact"].nil? &&
      item["rawIdentifiersPersisted"] == false
  end

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
EXPECTED_CASES.each do |case_id|
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
fail_validation("分析页案例编号不完整") unless html_case_ids == EXPECTED_CASES

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
  "直接证据" => [/<tr data-result=/, 20],
  "自然语言证据" => [/<tr data-chat-case=/, 5],
  "Lark channel E2E 证据" => [/<tr data-channel-case=/, 3],
  "阻塞项" => [/<div class="gap-row">/, 4],
  "修复记录" => [/<div class="repair-item">/, 13]
}
expected_html_counts.each do |label, (pattern, expected)|
  actual = html.scan(pattern).length
  fail_validation("分析页#{label}数量为 #{actual}，预期 #{expected}") unless actual == expected
end

report = File.read(File.join(ROOT, "report", "#{REPORT_DATE}-workflow-coverage-report.md"))
fail_validation("README 缺少 19 workflows + 3 channel cases 口径") unless
  readme.include?("19 个 workflow + 3 个 Lark channel E2E case") &&
  readme.include?("0/3 个 channel case 已通过生产验收") &&
  readme.include?("`pending-deployment`")
fail_validation("文字报告缺少 #3210 的 mount 与 workflow 运行期审批 channel cases") unless
  report.include?("## Lark channel E2E 案例（#3210）") &&
  report.include?("Case 20") && report.include?("Case 21") && report.include?("Case 22") &&
  report.include?("`approval_denied`") && report.include?("`awaiting_tool_approval`") &&
  report.include?("`pending-deployment`")
fail_validation("分析页缺少未通过的 Lark channel E2E 状态") unless
  html.include?("0 / 3") && html.include?("Lark channel E2E 严格通过") &&
  html.scan(/<tr data-channel-case="(?:20|21|22)" data-channel-status="pending-deployment">/).length == 3 &&
  html.scan(/<tr data-channel-case="(?:20|21|22)"[^>]*>.*?<span class="status status-pending">待部署验证<\/span>.*?<\/tr>/m).length == 3
fail_validation("分析页把待部署 channel case 渲染成绿色") if
  html.match?(/<tr data-channel-case="(?:20|21|22)"[^>]*>.*?status-passed.*?<\/tr>/m)
fail_validation("文字报告缺少案例 11 managed codex_exec 修复闭环") unless
  report.include?("## Managed codex_exec 修复与生产复验") &&
  report.include?("`Authorization: Bearer`") && report.include?("`forward_access_token=true`") &&
  report.include?("提交 `f7f543c51` 增加 bounded `X-API-Key` 代理入口") &&
  report.include?("`NyxIdApiClientBoundedProxyTests` 3/3") &&
  report.include?("`NyxIdManagedCodexChronoTransportTests` 16/16") &&
  report.include?("run hash `fa77c0c49035`") && report.include?("state 179、30/30 步") &&
  report.include?("`parallel_check_count=5`") && report.include?("`side_effects=false`")
fail_validation("分析页缺少案例 11 managed codex_exec 修复闭环") unless
  html.include?("Managed codex_exec 已恢复") &&
  html.include?("两次 <code>codex_execution_admission_denied</code>") &&
  html.include?("bounded <code>X-API-Key</code>") &&
  html.include?("committed <code>completed</code>（state 179，30/30）") &&
  html.include?("<code>CODEX_EXEC_READY</code>") &&
  html.include?("parallel=5") && html.include?("side-effects=false") &&
  html.include?("19/19 聚焦测试通过")
fail_validation("文字报告缺少 41 个非 n8n 定义口径") unless report.include?("只比较其余 41 个定义")
fail_validation("文字报告缺少 #3182 证据边界") unless report.include?("`#3182`")
fail_validation("文字报告缺少 #3161 定向回归边界") unless report.include?("`#3161`")
fail_validation("文字报告缺少 #3184 定向回归边界") unless report.include?("`#3184`")
fail_validation("文字报告缺少 /api/chat 与 Lark Bot 区分") unless report.include?("`/api/chat` 与 Lark Bot")
fail_validation("README 缺少案例 15 artifact identity 回归证据") unless readme.include?("`d7844b5e`")
fail_validation("文字报告缺少案例 15 artifact identity 回归证据") unless report.include?("`d7844b5e`")
fail_validation("分析页缺少案例 15 artifact identity 回归证据") unless html.include?("d7844b5e")
fail_validation("分析页缺少实际路径口径") unless html.include?("~/Code/workflows") && html.include?("~/workflows")
fail_validation("分析页缺少 4/5 自然语言结论") unless html.include?("4 / 5")
fail_validation("README 缺少财务源 workflow post-fix 验收") unless
  readme.include?("财务源工作流 post-fix 验收") && readme.include?("8/8 completed") &&
  readme.include?("14/14 实际步骤") && readme.include?("2/2 completed")
fail_validation("文字报告缺少财务源 workflow post-fix 验收") unless
  report.include?("财务源工作流 post-fix 验收") && report.include?("8/8 committed completion") &&
  report.include?("14 个实际步骤全部 completed") && report.include?("2/2 completed")
fail_validation("分析页缺少三项财务源 workflow 成功证据") unless
  html.scan(/<tr data-finance-result="passed">/).length == 3 &&
  html.include?("data-source-financial-acceptance=\"validated\"")
fail_validation("报告把安全限制未运行的财务分支伪报为成功") unless
  [readme, report, html].all? { |document| document.include?("P2 send") && document.include?("P1 v6") }
fail_validation("README 缺少 Durable schedule 生产闭环") unless
  readme.include?("Durable schedule 修复提交 `748f98e7d`") &&
  readme.include?("当前生产镜像 `b010ba61`") &&
  readme.include?("HTTP 200 `confirmation_required`") &&
  readme.include?("HTTP 202 typed `pending_binding` receipt") &&
  readme.include?("`NyxIdOperationAuthorityContractUnavailable`") &&
  readme.include?("schedule/operation ID 均非空") &&
  readme.include?("`fireCount=6`") && readme.include?("`failureCount=0`") &&
  readme.include?("workflow 11/11 committed `completed`") &&
  readme.include?("NyxID DELETE 返回 typed accepted receipt") && readme.include?("`6 -> 6`") &&
  readme.include?("编译修复提交 `b010ba614`") && readme.include?("真实 `linux/amd64` Docker build")
fail_validation("文字报告缺少 Durable schedule 分阶段生产闭环") unless
  report.include?("## Durable schedule 修复进度") &&
  report.include?("历史 HTTP 502") &&
  report.include?("`748f98e7d` 已提交、推送并部署") &&
  report.include?("真实验收入口") &&
  report.include?("HTTP 200 `confirmation_required`") && report.include?("HTTP 202 typed receipt") &&
  report.include?("binding/provisioning committed success") &&
  report.include?("`NyxIdOperationAuthorityContractUnavailable`") &&
  report.include?("`7a7781067` 已进入 `origin/feature/integrate`，并包含在当前 `b010ba614` / `b010ba61` 部署中") &&
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
  html.include?("Durable schedule 已恢复") &&
  html.include?("生产端到端通过") &&
  html.include?("Durable schedule provisioning") &&
  html.include?("当前 <code>b010ba614</code> / <code>b010ba61</code> 部署") &&
  html.include?("HTTP 200 <code>confirmation_required</code>") &&
  html.include?("HTTP 202 typed <code>pending_binding</code> receipt") &&
  html.include?("<code>NyxIdOperationAuthorityContractUnavailable</code>") &&
  html.include?("schedule/operation ID 均非空") &&
  html.include?("真实 cron fire=6/failure=0") &&
  html.include?("workflow 11/11 committed <code>completed</code>") &&
  html.include?("DELETE typed accepted 后 list 归零") && html.include?("run count 保持 6") &&
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
fail_validation("README 缺少最新全量回归口径") unless
  readme.include?("生产镜像 `20d9ba41`") && readme.include?("共 18 个案例") &&
  readme.include?("14、16、17、18、19 强制 typed artifact 契约") &&
  readme.include?("严格状态为 `start-blocked`")
fail_validation("文字报告缺少最新全量回归口径") unless
  report.include?("镜像 `20d9ba41`") && report.include?("19 个案例的 direct runtime 最新终态均为 committed `completed`") &&
  report.include?("只对 14、16、17、18、19、20 强制 typed artifact 契约") &&
  report.include?("`service_catalog_missing`") && report.include?("run catalog 增量为 0")
fail_validation("分析页缺少最新全量回归口径") unless
  html.include?("20 / 20") && html.include?("<code>20d9ba41</code>") &&
  html.include?("只对 14、16、17、18、19、20 强制 typed artifact 契约")
fail_validation("分析页阻塞状态未使用红色") unless
  html.include?(".status-blocked { background: var(--red-soft); color: var(--red); }")
fail_validation("分析页仍把已验证失败或回归显示为蓝色") if
  html.match?(/<span class="status status-partial">[^<]*(?:契约回归|已验证阻塞)/)
fail_validation("分析页不应再有审批契约回归状态") unless
  html.scan(/<span class="status status-blocked">契约回归<\/span>/).empty?
fail_validation("分析页 Lark Bot 已验证阻塞未标红") unless
  html.include?("<span class=\"status status-blocked\">已验证阻塞</span>") &&
  html.include?("<span class=\"status status-blocked\">P1 已验证阻塞</span>")
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

puts "通过 报告案例=20 财务源验收=3 源版本族=7 能力矩阵=19 自然语言=5 阻塞=4 修复记录=13"
