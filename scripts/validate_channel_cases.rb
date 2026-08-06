#!/usr/bin/env ruby

require "json"
require "time"
require "yaml"

ROOT = File.expand_path("..", __dir__)
CASE_DIR = File.join(ROOT, "channel-cases")
EVIDENCE_PATH = File.join(ROOT, "validation", "production-validation-2026-08-05.json")
EVIDENCE_BASELINE_COMMIT = "9f67c528174ac477bb144d6bd1525444e7c971cf"
REQUIRED_DEPLOYMENT_COMMITS = {
  "20" => EVIDENCE_BASELINE_COMMIT,
  "21" => EVIDENCE_BASELINE_COMMIT,
  "22" => "330bfa74f49bd48f22d01dbdf851c44db9a23414"
}.freeze
REQUIRED_ANCESTOR_COMMITS = {
  "20" => %w[b3784feef dd12cd6a6 452d72ec5 b7cacf183],
  "21" => %w[b3784feef dd12cd6a6 452d72ec5 b7cacf183],
  "22" => %w[b3784feef dd12cd6a6 452d72ec5 b7cacf183 9f67c5281]
}.transform_values(&:freeze).freeze
EXPECTED_FILES = {
  "20" => "20-lark-agent-run-skill-approval-approved.case.yaml",
  "21" => "21-lark-agent-run-skill-approval-rejected.case.yaml",
  "22" => "22-lark-workflow-runtime-tool-approval-approved.case.yaml"
}.freeze
EXPECTED_NAMES = {
  "20" => "lark_agent_run_skill_approval_approved",
  "21" => "lark_agent_run_skill_approval_rejected",
  "22" => "lark_workflow_runtime_tool_approval_approved"
}.freeze
EXPECTED_DECISIONS = { "20" => "approved", "21" => "rejected", "22" => "approved" }.freeze
AGENT_RUN_IDENTITY_FIELDS = %w[
  agent_run_id approval_request_id tool_request_id tool_call_id tool_name arguments_sha256
  sender_id registration_scope_id conversation_key
].freeze
WORKFLOW_IDENTITY_FIELDS = %w[
  actor_id run_id step_id execution_id tool_call_id approval_request_id
].freeze
OBSERVATION_FIELDS = %w[
  larkInboundObserved channelAgentRunStarted ornnSearchConfirmed exactSkillResolved
  approvalCardObserved approvalPendingExposedToModel approvalDecisionDispatched
  approvalDecisionDispatchCount approvalIdentityMatched sameAgentRunResolved sameAgentRunResumed
  useSkillReceiptStatus mountExecuted workflowStartCalls newWorkflowRunCount
  skillAlreadyMounted newMountApprovalCardObserved newMountApprovalDecisionDispatchCount
  awaitingToolApprovalObserved workflowApprovalCardObserved workflowApprovalDecisionDispatched
  workflowApprovalDecisionDispatchCount workflowApprovalIdentityMatched sameWorkflowRunResumed
  committedTerminalObserved terminalStatus finalArtifact replyRelayObserved stableErrorCode
  ordinaryAgentRunVisibleReplyCount awaitingToolApprovalVisibleTextCount
  workflowApprovalCardCount workflowTerminalResultCount
].freeze
ALLOWED_STATUSES = %w[pending-deployment passed failed].freeze
FORBIDDEN_EVIDENCE_KEYS = %w[
  runId actorId messageId approvalRequestId toolRequestId toolCallId senderId
  registrationScopeId conversationKey callbackCredential replyToken accessToken
  run_id actor_id message_id approval_request_id tool_request_id tool_call_id sender_id
  registration_scope_id conversation_key callback_credential reply_token access_token
].freeze
RAW_ID_PATTERNS = [
  /\b[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}\b/i,
  /\b(?:ou|oc|om)_[A-Za-z0-9_-]{8,}\b/,
  /\b(?:agent-run|workflow-run|actor|message|approval-request|tool-call|tool-request)-[A-Za-z0-9_-]{8,}\b/i
].freeze

def fail_validation(message)
  warn "Channel 案例验证失败：#{message}"
  exit 1
end

def load_yaml(path)
  YAML.safe_load(File.read(path), aliases: false)
rescue Psych::Exception => e
  fail_validation("#{File.basename(path)} YAML 无法解析：#{e.message}")
end

def expected_artifact
  {
    "case" => "lark_contact_batch_resolution",
    "success" => true,
    "contact_api_reachable" => true,
    "resolved_count" => 1,
    "identifiers_redacted" => true,
    "side_effects" => false
  }
end

def find_forbidden_key(value, path = "channelE2EAcceptance")
  case value
  when Hash
    value.each do |key, nested|
      return "#{path}.#{key}" if FORBIDDEN_EVIDENCE_KEYS.include?(key)

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

def find_raw_identity(value, path = "channelE2EAcceptance")
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
expected_paths = EXPECTED_FILES.values.map { |name| File.join(CASE_DIR, name) }.sort
fail_validation("案例文件集合不完整") unless paths == expected_paths

cases = paths.map { |path| [path, load_yaml(path)] }.to_h
cases.each do |path, spec|
  case_id = spec.fetch("case")
  fail_validation("#{File.basename(path)} case 与文件名不一致") unless
    File.basename(path) == EXPECTED_FILES[case_id]
  fail_validation("案例 #{case_id} schema_version 必须为 1.0") unless spec["schema_version"] == "1.0"
  fail_validation("案例 #{case_id} 名称漂移") unless spec["name"] == EXPECTED_NAMES[case_id]
  fail_validation("案例 #{case_id} 标题必须为中文") unless spec.fetch("title").match?(/[\p{Han}]/)
  fail_validation("案例 #{case_id} issue 必须为 #3210") unless spec["issue"] == "#3210"
  fail_validation("案例 #{case_id} 状态无效") unless ALLOWED_STATUSES.include?(spec["status"])
  fail_validation("案例 #{case_id} 入口必须为 Lark 私聊 Bot") unless spec["surface"] == "lark_private_bot"

  target = spec.fetch("target")
  fail_validation("案例 #{case_id} skill/workflow 目标漂移") unless
    target["skill"] == "lark-contact-batch-resolution" &&
    target["workflow"] == "lark_contact_batch_resolution" &&
    target["direct_workflow_case"] == "14"
  fail_validation("案例 #{case_id} 部署提交漂移") unless
    target["required_deployment_commit"] == REQUIRED_DEPLOYMENT_COMMITS.fetch(case_id) &&
    target["required_ancestor_commits"] == REQUIRED_ANCESTOR_COMMITS.fetch(case_id)
  fail_validation("案例 #{case_id} 决策漂移") unless
    spec.dig("trigger", "decision") == EXPECTED_DECISIONS.fetch(case_id)
  fail_validation("案例 #{case_id} 必须使用合成输入") unless
    spec.dig("safety", "synthetic_input_only") == true &&
    spec.dig("safety", "side_effects") == false &&
    spec.dig("safety", "raw_identifiers_persisted") == false
  expected_identity_fields = case_id == "22" ? WORKFLOW_IDENTITY_FIELDS : AGENT_RUN_IDENTITY_FIELDS
  fail_validation("案例 #{case_id} 审批身份字段不完整") unless
    spec.dig("identity", "exact_match_required") == expected_identity_fields
  if case_id == "22"
    fail_validation("案例 22 未固定已挂载且无新 mount 审批前置条件") unless
      spec["preconditions"] == {
        "skill_already_mounted" => true,
        "new_mount_approval_expected" => false
      }
  end
end

workflow_approved = cases.values.find { |spec| spec["case"] == "22" }.fetch("required_evidence")
fail_validation("案例 22 workflow 运行期批准链证据契约不完整") unless workflow_approved == {
  "lark_inbound_observed" => true,
  "channel_agent_run_started" => true,
  "ornn_search_confirmed" => true,
  "exact_skill_resolved" => true,
  "skill_already_mounted" => true,
  "new_mount_approval_card_observed" => false,
  "new_mount_approval_decision_dispatch_count" => 0,
  "use_skill_receipt_status" => "Completed",
  "mount_executed" => false,
  "workflow_start_calls" => 1,
  "ordinary_agent_run_visible_reply_count" => 0,
  "awaiting_tool_approval_visible_text_count" => 0,
  "new_workflow_run_count" => 1,
  "awaiting_tool_approval_observed" => true,
  "workflow_approval_card_observed" => true,
  "workflow_approval_card_count" => 1,
  "approval_pending_exposed_to_model" => false,
  "workflow_approval_decision_dispatched" => true,
  "workflow_approval_decision_dispatch_count" => 1,
  "workflow_approval_identity_matched" => true,
  "same_workflow_run_resumed" => true,
  "committed_terminal_observed" => true,
  "terminal_status" => "completed",
  "reply_relay_observed" => true,
  "workflow_terminal_result_count" => 1,
  "final_artifact" => expected_artifact,
  "raw_identifiers_persisted" => false
}

approved = cases.values.find { |spec| spec["case"] == "20" }.fetch("required_evidence")
fail_validation("案例 20 批准链证据契约不完整") unless approved == {
  "lark_inbound_observed" => true,
  "channel_agent_run_started" => true,
  "ornn_search_confirmed" => true,
  "exact_skill_resolved" => true,
  "approval_card_observed" => true,
  "approval_pending_exposed_to_model" => false,
  "approval_decision_dispatched" => true,
  "approval_decision_dispatch_count" => 1,
  "approval_identity_matched" => true,
  "same_agent_run_resolved" => true,
  "same_agent_run_resumed" => true,
  "use_skill_receipt_status" => "Completed",
  "mount_executed" => true,
  "workflow_start_calls" => 1,
  "new_workflow_run_count" => 1,
  "committed_terminal_observed" => true,
  "terminal_status" => "completed",
  "reply_relay_observed" => true,
  "final_artifact" => expected_artifact,
  "raw_identifiers_persisted" => false
}

rejected = cases.values.find { |spec| spec["case"] == "21" }.fetch("required_evidence")
fail_validation("案例 21 拒绝链证据契约不完整") unless rejected == {
  "lark_inbound_observed" => true,
  "channel_agent_run_started" => true,
  "ornn_search_confirmed" => true,
  "exact_skill_resolved" => true,
  "approval_card_observed" => true,
  "approval_pending_exposed_to_model" => false,
  "approval_decision_dispatched" => true,
  "approval_decision_dispatch_count" => 1,
  "approval_identity_matched" => true,
  "same_agent_run_resolved" => true,
  "same_agent_run_resumed" => false,
  "use_skill_receipt_status" => "Denied",
  "stable_error_code" => "approval_denied",
  "mount_executed" => false,
  "workflow_start_calls" => 0,
  "new_workflow_run_count" => 0,
  "committed_terminal_observed" => false,
  "terminal_status" => nil,
  "reply_relay_observed" => true,
  "final_artifact" => nil,
  "raw_identifiers_persisted" => false
}

summary = JSON.parse(File.read(EVIDENCE_PATH)).fetch("channelE2EAcceptance")
fail_validation("机器证据 schemaVersion 漂移") unless summary["schemaVersion"] == "1.0"
fail_validation("机器证据基线提交漂移") unless summary["requiredDeploymentCommit"] == EVIDENCE_BASELINE_COMMIT
results = summary.fetch("results")
fail_validation("机器证据案例编号不完整") unless results.map { |item| item.fetch("case") } == %w[20 21 22]
forbidden_key_path = find_forbidden_key(summary)
fail_validation("机器证据包含原始身份字段：#{forbidden_key_path}") if forbidden_key_path
raw_identity_path = find_raw_identity(summary)
fail_validation("机器证据包含疑似原始身份：#{raw_identity_path}") if raw_identity_path

counts = results.each_with_object(Hash.new(0)) { |item, memo| memo[item.fetch("status")] += 1 }
expected_summary = {
  "total" => 3,
  "passed" => counts["passed"],
  "failed" => counts["failed"],
  "pendingDeployment" => counts["pending-deployment"]
}
fail_validation("机器证据汇总与逐案例状态不一致") unless summary.fetch("summary") == expected_summary

results.each do |item|
  case_id = item.fetch("case")
  fail_validation("案例 #{case_id} 名称或决策漂移") unless
    item["name"] == EXPECTED_NAMES.fetch(case_id) &&
    item["expectedDecision"] == EXPECTED_DECISIONS.fetch(case_id)
  spec = cases.values.find { |candidate| candidate["case"] == case_id }
  fail_validation("案例 #{case_id} 描述状态与机器证据不一致") unless spec["status"] == item["status"]
  fail_validation("案例 #{case_id} 保存了原始身份") unless item["rawIdentifiersPersisted"] == false

  case item.fetch("status")
  when "pending-deployment"
    fail_validation("案例 #{case_id} 待部署时不应附带生产镜像或时间") unless
      item["observedAtUtc"].nil? && item["deploymentImage"].nil? &&
      item["deploymentDigest"].nil? && item["deploymentCommit"].nil?
    fail_validation("案例 #{case_id} 待部署时不得伪造 Ready workload 证据") unless
      item["readyProductionWorkloadTraceable"] == false
    fail_validation("案例 #{case_id} 待部署时不得伪造运行证据") unless
      OBSERVATION_FIELDS.all? { |field| item[field].nil? }
  when "passed"
    fail_validation("案例 #{case_id} 缺少可追溯 Ready 生产部署") unless
      item["requiredDeploymentCommit"] == REQUIRED_DEPLOYMENT_COMMITS.fetch(case_id) &&
      item["deploymentCommit"].to_s.length.positive? && item["requiredAncestorsPresent"] == true &&
      item["readyProductionWorkloadTraceable"] == true &&
      item["deploymentImage"].to_s.length.positive? && item["deploymentDigest"].to_s.length.positive?
    begin
      Time.iso8601(item.fetch("observedAtUtc"))
    rescue ArgumentError, KeyError
      fail_validation("案例 #{case_id} observedAtUtc 无效")
    end
    common = item.values_at(
      "larkInboundObserved", "channelAgentRunStarted", "ornnSearchConfirmed",
      "exactSkillResolved", "approvalPendingExposedToModel", "replyRelayObserved"
    )
    fail_validation("案例 #{case_id} channel 主链证据不完整") unless
      common == [true, true, true, true, false, true]

    if case_id == "20"
      fail_validation("案例 20 批准后未严格完成 mount 与单次 workflow") unless
        item["approvalCardObserved"] == true && item["approvalDecisionDispatched"] == true &&
        item["approvalDecisionDispatchCount"] == 1 && item["approvalIdentityMatched"] == true &&
        item["sameAgentRunResolved"] == true &&
        item["sameAgentRunResumed"] == true && item["useSkillReceiptStatus"] == "Completed" &&
        item["mountExecuted"] == true && item["workflowStartCalls"] == 1 &&
        item["newWorkflowRunCount"] == 1 && item["committedTerminalObserved"] == true &&
        item["terminalStatus"] == "completed" && item["finalArtifact"] == expected_artifact &&
        item["stableErrorCode"].nil?
    elsif case_id == "21"
      fail_validation("案例 21 拒绝后未严格终止") unless
        item["approvalCardObserved"] == true && item["approvalDecisionDispatched"] == true &&
        item["approvalDecisionDispatchCount"] == 1 && item["approvalIdentityMatched"] == true &&
        item["sameAgentRunResolved"] == true &&
        item["sameAgentRunResumed"] == false && item["useSkillReceiptStatus"] == "Denied" &&
        item["stableErrorCode"] == "approval_denied" && item["mountExecuted"] == false &&
        item["workflowStartCalls"] == 0 && item["newWorkflowRunCount"] == 0 &&
        item["committedTerminalObserved"] == false && item["terminalStatus"].nil? &&
        item["finalArtifact"].nil?
    else
      fail_validation("案例 22 workflow 运行期批准链未严格完成") unless
        item["skillAlreadyMounted"] == true && item["newMountApprovalCardObserved"] == false &&
        item["newMountApprovalDecisionDispatchCount"] == 0 &&
        item["useSkillReceiptStatus"] == "Completed" && item["mountExecuted"] == false &&
        item["workflowStartCalls"] == 1 && item["ordinaryAgentRunVisibleReplyCount"] == 0 &&
        item["awaitingToolApprovalVisibleTextCount"] == 0 && item["newWorkflowRunCount"] == 1 &&
        item["awaitingToolApprovalObserved"] == true && item["workflowApprovalCardObserved"] == true &&
        item["workflowApprovalCardCount"] == 1 &&
        item["workflowApprovalDecisionDispatched"] == true &&
        item["workflowApprovalDecisionDispatchCount"] == 1 &&
        item["workflowApprovalIdentityMatched"] == true && item["sameWorkflowRunResumed"] == true &&
        item["committedTerminalObserved"] == true && item["terminalStatus"] == "completed" &&
        item["workflowTerminalResultCount"] == 1 &&
        item["finalArtifact"] == expected_artifact && item["stableErrorCode"].nil?
    end
  when "failed"
    fail_validation("案例 #{case_id} 失败证据缺少可追溯 Ready 生产部署") unless
      item["requiredDeploymentCommit"] == REQUIRED_DEPLOYMENT_COMMITS.fetch(case_id) &&
      item["deploymentCommit"].to_s.length.positive? && item["requiredAncestorsPresent"] == true &&
      item["readyProductionWorkloadTraceable"] == true &&
      item["deploymentImage"].to_s.length.positive? && item["deploymentDigest"].to_s.length.positive?
    begin
      Time.iso8601(item.fetch("observedAtUtc"))
    rescue ArgumentError, KeyError
      fail_validation("案例 #{case_id} observedAtUtc 无效")
    end
    fail_validation("案例 #{case_id} 失败证据缺少稳定错误码") if item["stableErrorCode"].to_s.empty?
    fail_validation("案例 #{case_id} 失败证据缺少结果说明") if item["result"].to_s.empty?
  else
    fail_validation("案例 #{case_id} 状态无效：#{item['status']}")
  end
end

raw_case_text = paths.map { |path| File.read(path) }.join("\n")
fail_validation("案例定义中出现 UUID") if raw_case_text.match?(/\b[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}\b/i)

puts "通过 Channel E2E 案例=#{results.length} passed=#{counts['passed']} failed=#{counts['failed']} pending-deployment=#{counts['pending-deployment']}"
