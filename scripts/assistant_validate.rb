#!/usr/bin/env ruby

require "base64"
require "digest"
require "json"
require "open3"
require "optparse"
require "securerandom"
require "time"
require "uri"

require_relative "runtime_contracts"

ROOT = File.expand_path("..", __dir__)

CASES = {
  "01" => {
    prompt: "帮我做一次上线准备度审查：检查发布窗口、备份、监控和回滚条件。请先通过 Ornn 搜索确认并使用精确名称为 release-readiness-review 的 skill，把其中的 workflow 挂载到当前 scope 后实际运行，并以 typed artifact 为准报告结果。",
    skill: "release-readiness-review",
    workflow: "release_readiness_review",
    chat_approval_tools: ["use_skill"]
  },
  "06" => {
    prompt: "请运行项目共享邮箱审批验收：从 Base 读取已准备好的合成申请，创建并回读一条 Lark 审批。请先通过 Ornn 搜索确认并使用精确名称为 project-shared-mailbox-approval 的 skill，把其中的 workflow 挂载到当前 scope 后实际运行；这是我明确要求的有副作用操作，等待 typed tool approval 后再继续，并以 typed artifact 为准报告结果。",
    skill: "project-shared-mailbox-approval",
    workflow: "project_shared_mailbox_approval",
    chat_approval_tools: ["use_skill"],
    side_effect: true,
    workflow_approval: true
  },
  "12" => {
    prompt: "请用安全代码执行验收案例核对这笔合成结算：小计 152.30 美元、税率 7.5%、手续费 0.50 美元。请先通过 Ornn 搜索确认并使用精确名称为 safe-code-execute-validation 的 skill，把其中的 workflow 挂载到当前 scope 后实际运行；如果平台阻止执行，请返回真实 typed blocker。",
    skill: "safe-code-execute-validation",
    workflow: "safe_code_execute_validation",
    chat_approval_tools: ["use_skill"]
  },
  "13" => {
    prompt: "请从这张合成发票图片中提取字段、归一化金额和日期，并检查历史重复。请先通过 Ornn 搜索确认并使用精确名称为 invoice-ocr-policy-review 的 skill，把其中的 workflow 挂载到当前 scope 后实际运行；禁止直接用模型视觉回答，禁止创建审批，结果只以 typed artifact 为准。",
    skill: "invoice-ocr-policy-review",
    workflow: "invoice_ocr_policy_review",
    chat_approval_tools: ["use_skill"],
    image: "synthetic-invoice.png"
  },
  "14" => {
    prompt: "请把验收入职邮箱解析为 Lark 联系人 ID，只返回是否成功和解析数量。请先通过 Ornn 搜索确认并使用精确名称为 lark-contact-batch-resolution 的 skill，把其中的 workflow 挂载到当前 scope 后实际运行；如果缺少 Lark 权限，请原样报告 typed blocker，不要伪造联系人。",
    skill: "lark-contact-batch-resolution",
    workflow: "lark_contact_batch_resolution",
    chat_approval_tools: ["use_skill"],
    workflow_approval: true
  },
  "15" => {
    prompt: "请生成合成预算的周度和月度差异摘要，不发送任何消息。请先通过 Ornn 搜索确认并使用精确名称为 weekly-budget-variance-digest 的 skill，把其中的 workflow 挂载到当前 scope 后实际运行，并以 typed artifact 为准报告结果。",
    skill: "weekly-budget-variance-digest",
    workflow: "weekly_budget_variance_digest",
    chat_approval_tools: ["use_skill"]
  }
}.freeze

class AssistantValidationError < StandardError; end

options = { cases: CASES.keys, timeout: 600, inline_fallback: false, approved_cases: [] }
OptionParser.new do |parser|
  parser.banner = "用法：ruby scripts/assistant_validate.rb [选项]"
  parser.on("--cases LIST", "逗号分隔的案例编号，默认 01,06,12,13,14,15") do |value|
    options[:cases] = value.split(",").map(&:strip)
  end
  parser.on("--timeout SECONDS", Integer, "单次请求超时，默认 600 秒") do |value|
    options[:timeout] = value
  end
  parser.on("--inline-fallback", "诊断 issue 3182：禁用 mount，改用 inline workflow YAML") do
    options[:inline_fallback] = true
  end
  parser.on("--approve LIST", "逗号分隔的已授权案例；仅批准 current state 中匹配的 typed tool approval") do |value|
    options[:approved_cases] = value.split(",").map(&:strip)
  end
end.parse!

unknown = options.fetch(:cases) - CASES.keys
abort "未知案例：#{unknown.join(', ')}" unless unknown.empty?
unknown_approvals = options.fetch(:approved_cases) - CASES.keys
abort "未知批准案例：#{unknown_approvals.join(', ')}" unless unknown_approvals.empty?
unselected_approvals = options.fetch(:approved_cases) - options.fetch(:cases)
abort "批准案例必须同时出现在 --cases：#{unselected_approvals.join(', ')}" unless unselected_approvals.empty?
unsafe_approvals = options.fetch(:approved_cases).reject do |case_id|
  config = CASES.fetch(case_id)
  !Array(config[:chat_approval_tools]).empty? || config[:workflow_approval]
end
abort "案例没有声明可自动批准的 typed approval：#{unsafe_approvals.join(', ')}" unless unsafe_approvals.empty?

def redacted_text(value)
  value.to_s
    .gsub(/[0-9a-f]{8}-[0-9a-f-]{27,}/i, "<uuid>")
    .gsub(/\b[0-9a-f]{32}\b/i, "<opaque-id>")
    .gsub(/scope-workflow:[^\s\"']+/i, "scope-workflow:<已脱敏>")
    .gsub(/workflow\.definition:[^\s\"']+/i, "workflow.definition:<已脱敏>")
    .gsub(/Bearer\s+[^\s\"']+/i, "Bearer <已脱敏>")
    .strip
    .byteslice(0, 2_000)
end

def typed_failure_codes(value)
  value.to_s.scan(/\b[A-Z][A-Z0-9]+(?:_[A-Z0-9]+)+\b/).uniq
end

def tool_result_failure_codes(value)
  value.to_s.scan(
    /(?:failure_code|failureCode|error_code|errorCode|code)[\s\"':=]+([A-Z][A-Z0-9]+(?:_[A-Z0-9]+)+)/
  ).flatten.uniq
end

def parse_tool_result(result)
  signals = {}
  signals[:completed] = true if result.match?(/\bcompleted\b/i)
  signals[:pending] = true if result.match?(/\bpending\b/i)
  signals[:failed] = true if result.match?(/\bfailed\b/i)
  signals[:successTrue] = true if result.match?(/(?:"success"|success)\s*[:=]\s*true/i)
  signals[:shortRunArtifactPending] = true if result.match?(/artifact.*pending|pending.*artifact/i)
  run_id = result[/\b(?:run_id|runId)\b[\s\"':=]+([^\s\",}]+)/i, 1]
  signals[:runIdHash] = Digest::SHA256.hexdigest(run_id)[0, 12] if run_id
  {
    bytes: result.bytesize,
    sha256: Digest::SHA256.hexdigest(result)[0, 16],
    signals: signals,
    typedFailureCodes: tool_result_failure_codes(result)
  }
end

def nyxid_request_json(path, method: "GET", body: nil)
  arguments = [
    "proxy", "request", "aevatar", path,
    "--method", method,
    "--output", "json"
  ]
  if body
    arguments += [
      "--header", "Content-Type:application/json",
      "--data", "-"
    ]
  end
  stdout, stderr, status = Open3.capture3(
    "nyxid",
    *arguments,
    stdin_data: body ? JSON.generate(body) : ""
  )
  unless status.success? && !stderr.include?("Proxy request failed")
    raise AssistantValidationError, "NyxID control 请求失败：#{redacted_text([stderr, stdout].join(' | '))}"
  end

  JSON.parse(stdout)
rescue JSON::ParserError => e
  raise AssistantValidationError, "NyxID control 响应不是 JSON：#{e.message}"
end

def resolve_current_approval(conversation_id, event_request_id, timeout)
  state_path = "/api/chat/conversations/#{URI.encode_www_form_component(conversation_id)}/state"
  deadline = Time.now + [timeout, 30].min
  state = nil
  loop do
    begin
      state = nyxid_request_json(state_path)
    rescue AssistantValidationError => e
      raise unless e.message.include?("HTTP 404") && Time.now < deadline

      sleep 1
      next
    end
    pending = state.dig("snapshot", "pendingApproval")
    break if state["status"] == "current" &&
             pending.is_a?(Hash) &&
             pending["approvalRequestId"] == event_request_id

    raise AssistantValidationError, "等待匹配的 current-state tool approval 超时" if Time.now >= deadline
    sleep 1
  end

  client_request_id = "assistant-approval-#{SecureRandom.uuid}"
  response = nyxid_request_json(
    "/api/chat",
    method: "POST",
    body: {
      type: "approval.resolve",
      conversationId: conversation_id,
      clientRequestId: client_request_id,
      requestId: event_request_id,
      approved: true,
      reason: "已明确授权当前生产验收案例的 typed tool approval。",
      expectedStateVersion: state.fetch("stateVersion")
    }
  )
  unless response["status"] == "accepted" && response["requestId"] == event_request_id
    raise AssistantValidationError, "tool approval 未返回匹配的 accepted receipt"
  end

  {
    accepted: true,
    stateVersion: state.fetch("stateVersion"),
    requestIdHash: Digest::SHA256.hexdigest(event_request_id)[0, 12],
    commandIdHash: Digest::SHA256.hexdigest(response.fetch("commandId"))[0, 12]
  }
end

def handle_tool_approval(
  approvals,
  resolved_approvals,
  approve,
  conversation_id,
  request_id,
  tool_name,
  destructive,
  source,
  timeout,
  allowed_tools
)
  approval = {
    tool: tool_name,
    destructive: destructive,
    source: source,
    requestIdHash: Digest::SHA256.hexdigest(request_id)[0, 12],
    approved: false
  }
  approvals << approval
  return unless approve && !resolved_approvals[request_id]

  raise AssistantValidationError, "tool approval 到达前没有 authoritative conversation ID" unless conversation_id
  raise AssistantValidationError, "typed tool approval 缺少 requestId" if request_id.empty?
  unless allowed_tools.include?(tool_name)
    raise AssistantValidationError, "拒绝批准白名单外的 chat tool：#{redacted_text(tool_name)}"
  end
  if destructive
    raise AssistantValidationError, "拒绝自动批准 destructive chat tool：#{redacted_text(tool_name)}"
  end

  approval[:resolution] = resolve_current_approval(conversation_id, request_id, timeout)
  approval[:approved] = true
  resolved_approvals[request_id] = true
end

def monotonic_now
  Process.clock_gettime(Process::CLOCK_MONOTONIC)
end

def each_line_until(io, deadline, timeout_message)
  buffer = +""
  loop do
    remaining = deadline - monotonic_now
    raise AssistantValidationError, timeout_message if remaining <= 0

    readable = IO.select([io], nil, nil, remaining)
    raise AssistantValidationError, timeout_message unless readable

    chunk = io.read_nonblock(16 * 1024, exception: false)
    next if chunk == :wait_readable
    if chunk.nil?
      yield buffer unless buffer.empty?
      break
    end

    buffer << chunk
    while (newline = buffer.index("\n"))
      yield buffer.slice!(0, newline + 1)
    end
  end
end

def terminate_child(wait_thread)
  return unless wait_thread.alive?

  Process.kill("TERM", wait_thread.pid)
  return if wait_thread.join(3)

  Process.kill("KILL", wait_thread.pid)
  wait_thread.join
rescue Errno::ESRCH, Errno::ECHILD
  nil
end

WORKFLOW_TERMINAL_STATUSES = %w[completed failed stopped].freeze

def locate_workflow_run(workflow_name, request_started_at, timeout)
  deadline = Time.now + [timeout, 60].min
  from = (request_started_at - 2).utc.iso8601(6)
  query = URI.encode_www_form(origin: "ad-hoc-chat", from: from, take: 100)

  loop do
    summaries = nyxid_request_json("/api/workflow/observatory/runs?#{query}")
    raise AssistantValidationError, "workflow observatory 列表响应不是数组" unless summaries.is_a?(Array)

    candidates = summaries.select do |summary|
      next false unless summary["workflowName"] == workflow_name

      started_at = Time.iso8601(summary.fetch("startedAtUtc"))
      started_at >= request_started_at - 2
    rescue ArgumentError, KeyError
      false
    end
    return candidates.fetch(0) if candidates.length == 1
    if candidates.length > 1
      raise AssistantValidationError,
            "同一自然语言请求窗口出现多个 #{workflow_name} run，拒绝猜测 workflow identity"
    end

    raise AssistantValidationError, "等待 #{workflow_name} committed run binding 超时" if Time.now >= deadline
    sleep 1
  end
end

def workflow_run_detail(actor_run_id)
  encoded = URI.encode_www_form_component(actor_run_id)
  nyxid_request_json("/api/workflow/observatory/runs/#{encoded}")
end

def pending_workflow_approval(detail)
  step = Array(detail["steps"]).reverse.find do |candidate|
    candidate["completedAtUtc"].nil? && candidate["toolApproval"].is_a?(Hash)
  end
  return nil unless step

  approval = step.fetch("toolApproval")
  {
    step_id: step.fetch("stepId"),
    execution_id: approval.fetch("executionId"),
    tool_call_id: approval.fetch("toolCallId"),
    approval_request_id: approval.fetch("approvalRequestId")
  }
rescue KeyError => e
  raise AssistantValidationError, "committed workflow approval identity 不完整：#{e.message}"
end

def resolve_workflow_approval(detail, approval)
  summary = detail.fetch("summary")
  actor_run_id = summary.fetch("runId")
  scope_id = summary.fetch("scopeId")
  approval_request_id = approval.fetch(:approval_request_id)
  command_id = "assistant-workflow-approval-#{Digest::SHA256.hexdigest(approval_request_id)[0, 24]}"
  response = nyxid_request_json(
    "/api/scopes/#{URI.encode_www_form_component(scope_id)}/runs/" \
      "#{URI.encode_www_form_component(actor_run_id)}:resume",
    method: "POST",
    body: {
      stepId: approval.fetch(:step_id),
      commandId: command_id,
      approved: true,
      actorId: actor_run_id,
      toolApproval: {
        executionId: approval.fetch(:execution_id),
        toolCallId: approval.fetch(:tool_call_id),
        approvalRequestId: approval_request_id
      }
    }
  )
  unless response["accepted"] == true &&
         response["actorId"] == actor_run_id &&
         response["runId"] == actor_run_id &&
         response["stepId"] == approval.fetch(:step_id)
    raise AssistantValidationError, "workflow tool approval 未返回 matching accepted receipt"
  end

  {
    source: "committed-workflow-current-state",
    step: approval.fetch(:step_id),
    approved: true,
    requestIdHash: Digest::SHA256.hexdigest(approval_request_id)[0, 12],
    commandIdHash: Digest::SHA256.hexdigest(response.fetch("acceptedCommandId"))[0, 12]
  }
end

def observe_workflow_run(workflow_name, request_started_at, timeout, approve)
  summary = locate_workflow_run(workflow_name, request_started_at, timeout)
  actor_run_id = summary.fetch("runId")
  deadline = Time.now + timeout
  approval_receipts = []
  resolved_approvals = {}

  loop do
    detail = workflow_run_detail(actor_run_id)
    status = detail.dig("summary", "status").to_s.downcase
    return [detail, approval_receipts] if WORKFLOW_TERMINAL_STATUSES.include?(status)

    if status == "awaiting_tool_approval"
      approval = pending_workflow_approval(detail)
      raise AssistantValidationError, "awaiting_tool_approval read model 缺少 typed identity" unless approval

      request_id = approval.fetch(:approval_request_id)
      unless resolved_approvals[request_id]
        return [detail, approval_receipts] unless approve

        approval_receipts << resolve_workflow_approval(detail, approval)
        resolved_approvals[request_id] = true
      end
    end

    raise AssistantValidationError, "等待 workflow committed 终态超时，当前状态：#{status}" if Time.now >= deadline
    sleep 2
  end
end

def summarize_committed_workflow(detail, case_id)
  summary = detail.fetch("summary")
  steps = Array(detail["steps"])
  final_output = detail["finalOutput"]
  parsed_output = if final_output.is_a?(String) && final_output.strip.empty?
                    nil
                  elsif final_output.is_a?(String)
                    JSON.parse(final_output)
                  else
                    final_output
                  end
  parsed_output = nil unless parsed_output.is_a?(Hash)
  if summary["status"].to_s.downcase == "completed" &&
     summary["success"] == true &&
     parsed_output.nil?
    raise AssistantValidationError, "committed workflow 成功终态缺少可解析 JSON finalOutput"
  end
  mismatch = RuntimeContracts.mismatch(case_id, parsed_output)
  if summary["status"].to_s.downcase == "completed" && summary["success"] == true && mismatch
    raise AssistantValidationError,
          "committed workflow artifact 契约不匹配：#{mismatch.fetch(:actual).inspect}"
  end
  failure_text = [
    summary["lastError"],
    detail["lastError"],
    steps.reverse.find { |step| !step["error"].to_s.empty? }&.fetch("error", nil)
  ].compact.join(" ")

  {
    runIdHash: Digest::SHA256.hexdigest(summary.fetch("runId"))[0, 12],
    workflowName: summary.fetch("workflowName"),
    status: summary.fetch("status"),
    success: summary["success"],
    stateVersion: summary.fetch("stateVersion"),
    completedSteps: steps.count { |step| !step["completedAtUtc"].nil? },
    totalSteps: steps.length,
    finalOutputBytes: final_output.to_s.bytesize,
    finalOutputSha256: Digest::SHA256.hexdigest(final_output.to_s)[0, 16],
    finalOutputKeys: parsed_output&.keys&.sort || [],
    artifactCase: parsed_output&.fetch("case", nil),
    artifactApprovalStatus: parsed_output&.fetch("approval_status", nil),
    artifactContractVerified: mismatch.nil?,
    artifactContractKeys: RuntimeContracts.for(case_id).fetch(:expected).keys.sort,
    typedFailureCodes: typed_failure_codes(failure_text)
  }
rescue JSON::ParserError
  raise AssistantValidationError, "committed workflow finalOutput 不是可解析 JSON"
rescue KeyError => e
  raise AssistantValidationError, "committed workflow artifact 不完整：#{e.message}"
end

def classify_committed_workflow(evidence)
  status = evidence.fetch(:status).to_s.downcase
  validation_status = if status == "completed" && evidence[:success] == true
                        "validated"
                      elsif WORKFLOW_TERMINAL_STATUSES.include?(status)
                        "typed-failure"
                      elsif status == "awaiting_tool_approval"
                        "artifact-pending"
                      else
                        "unproven"
                      end
  {
    status: validation_status,
    validated: validation_status == "validated",
    blockerCodes: evidence.fetch(:typedFailureCodes)
  }
end

def classify_workflow(tool_calls, run_error)
  artifact_results = tool_calls
    .select { |tool| tool[:name] == "aevatar_read_workflow_run_artifact" }
    .map { |tool| tool[:result] }
    .compact
  start_results = tool_calls
    .select { |tool| tool[:name] == "aevatar_start_workflow" }
    .map { |tool| tool[:result] }
    .compact
  mount_results = tool_calls
    .select { |tool| tool[:name] == "use_skill" }
    .map { |tool| tool[:result] }
    .compact
  blocker_codes = (artifact_results + start_results + mount_results)
    .flat_map { |result| result.fetch(:typedFailureCodes, []) }
  run_error_code = run_error&.fetch(:code, nil).to_s.strip
  blocker_codes << run_error_code unless run_error_code.empty?
  blocker_codes.uniq!

  artifact_completed = artifact_results.any? do |result|
    result.dig(:signals, :completed) && result.dig(:signals, :successTrue)
  end
  artifact_failed = artifact_results.any? do |result|
    result.dig(:signals, :failed) || !result.fetch(:typedFailureCodes, []).empty?
  end
  artifact_pending = artifact_results.any? do |result|
    result.dig(:signals, :pending) || result.dig(:signals, :shortRunArtifactPending)
  end
  start_blocked = start_results.any? do |result|
    result.dig(:signals, :failed) || !result.fetch(:typedFailureCodes, []).empty?
  end
  mount_blocked = mount_results.any? do |result|
    result.dig(:signals, :failed) || !result.fetch(:typedFailureCodes, []).empty?
  end ||
                  run_error_code.start_with?("USE_SKILL_MOUNT_")

  status = if artifact_completed
             "validated"
           elsif artifact_failed
             "typed-failure"
           elsif start_blocked
             "start-blocked"
           elsif mount_blocked
             "mount-blocked"
           elsif artifact_pending
             "artifact-pending"
           elsif !run_error_code.empty?
             "chat-failed"
           elsif start_results.empty?
             "not-started"
           else
             "unproven"
           end
  {
    status: status,
    validated: status == "validated",
    blockerCodes: blocker_codes
  }
end

def run_case(case_id, config, timeout, inline_fallback, approve)
  request_id = "assistant-workflow-#{case_id}-#{SecureRandom.uuid}"
  body = {
    type: "text",
    clientRequestId: request_id,
    prompt: config.fetch(:prompt)
  }
  if inline_fallback
    body[:prompt] += " 当前生产存在 Ornn/Aevatar workflow mount 契约差异：调用 use_skill 时请显式设置 mount_workflows=false，然后从 skill 返回的关联文件读取完整 workflow YAML，并作为 workflow_yamls inline fallback 传给 aevatar_start_workflow。"
  end
  if config[:image]
    path = File.join(ROOT, "fixtures", config.fetch(:image))
    bytes = File.binread(path)
    body[:inputParts] = [{
      type: "image",
      dataBase64: Base64.strict_encode64(bytes),
      mediaType: "image/png",
      name: File.basename(path)
    }]
  end

  arguments = [
    "proxy", "request", "aevatar", "/api/chat",
    "--method", "POST",
    "--header", "Content-Type:application/json",
    "--header", "Accept:text/event-stream",
    "--data", "-",
    "--stream",
    "--output", "json"
  ]
  events = []
  tools = []
  assistant_text = +""
  conversation_id = nil
  turn_id = nil
  terminal_status = nil
  run_error = nil
  authorizations = []
  approvals = []
  resolved_approvals = {}

  stderr_text = +""
  status = nil
  request_started_at = Time.now.utc
  request_deadline = monotonic_now + timeout
  Open3.popen3("nyxid", *arguments) do |stdin, stdout, stderr, wait_thread|
    stdin.write(JSON.generate(body))
    stdin.close
    stderr_thread = Thread.new { stderr.read }
    timeout_message = "案例 #{case_id} 的 /api/chat 超时"
    each_line_until(stdout, request_deadline, timeout_message) do |line|
      next unless line.start_with?("data: ")

      begin
        event = JSON.parse(line.delete_prefix("data: "))
      rescue JSON::ParserError
        next
      end
      type = event["type"]
      events << type unless events.last == type
      case type
      when "RUN_STARTED"
        conversation_id = event["actorId"]
        turn_id = event["turnId"]
      when "TOOL_CALL_START"
        presentation = event.dig("toolCallStart", "presentation") || {}
        skill_name = presentation.dig("sourceRef", "skill", "skillName").to_s.strip
        tool = {
          name: event.dig("toolCallStart", "toolName"),
          callIdHash: Digest::SHA256.hexdigest(event.dig("toolCallStart", "toolCallId").to_s)[0, 12],
          presentationKind: presentation["kind"]
        }
        tool[:skill] = skill_name unless skill_name.empty?
        tools << tool
      when "TOOL_CALL_END"
        current = tools.reverse.find do |tool|
          tool[:callIdHash] == Digest::SHA256.hexdigest(event.dig("toolCallEnd", "toolCallId").to_s)[0, 12]
        end
        current[:result] = parse_tool_result(event.dig("toolCallEnd", "result").to_s) if current
      when "TEXT_MESSAGE_CONTENT"
        assistant_text << event.dig("textMessageContent", "delta").to_s
      when "TOOL_APPROVAL_REQUEST"
        approval_request_id = event.dig("toolApprovalRequest", "requestId").to_s
        handle_tool_approval(
          approvals,
          resolved_approvals,
          approve,
          conversation_id,
          approval_request_id,
          event.dig("toolApprovalRequest", "toolName"),
          event.dig("toolApprovalRequest", "isDestructive") == true,
          "TOOL_APPROVAL_REQUEST",
          timeout,
          Array(config[:chat_approval_tools])
        )
      when "CUSTOM"
        custom_name = event.dig("custom", "name")
        if custom_name == "nyxid.approval.request"
          payload = event.dig("custom", "payload") || {}
          handle_tool_approval(
            approvals,
            resolved_approvals,
            approve,
            conversation_id,
            payload["approvalRequestId"].to_s,
            payload["toolName"],
            payload.dig("presentation", "reversibility") == "irreversible",
            custom_name,
            timeout,
            Array(config[:chat_approval_tools])
          )
        elsif custom_name == "nyxid.authorization.required"
          authorizations << {
            service: event.dig("custom", "payload", "serviceSlug"),
            code: event.dig("custom", "payload", "reasonCode")
          }
        end
      when "RUN_FINISHED"
        terminal_status = event.dig("runFinished", "status")
      when "RUN_ERROR"
        run_error = {
          code: event.dig("runError", "code"),
          message: redacted_text(event.dig("runError", "message"))
        }
      end
    end
    unless wait_thread.join([request_deadline - monotonic_now, 0].max)
      terminate_child(wait_thread)
      raise AssistantValidationError, timeout_message
    end
    stderr_text = stderr_thread.value
    status = wait_thread.value
  rescue StandardError
    terminate_child(wait_thread)
    stderr_thread&.join(1)
    raise
  end

  unless status&.success? && !stderr_text.include?("Proxy request failed")
    raise AssistantValidationError, "案例 #{case_id} 的 NyxID 请求失败：#{redacted_text(stderr_text)}"
  end
  raise AssistantValidationError, "案例 #{case_id} 未收到 RUN_STARTED" unless conversation_id && turn_id

  tool_names = tools.map { |tool| tool.fetch(:name) }
  committed_workflow = nil
  workflow_approvals = []
  workflow_observation_error = nil
  if tool_names.include?("aevatar_start_workflow")
    begin
      detail, workflow_approvals = observe_workflow_run(
        config.fetch(:workflow),
        request_started_at,
        timeout,
        approve && config[:workflow_approval] == true
      )
      committed_workflow = summarize_committed_workflow(detail, case_id)
    rescue AssistantValidationError => e
      workflow_observation_error = redacted_text(e.message)
    end
  end
  workflow_validation = if committed_workflow
                          classify_committed_workflow(committed_workflow)
                        else
                          classify_workflow(tools, run_error)
                        end
  used_expected_skill = tools.any? do |tool|
    tool[:name] == "use_skill" && tool[:skill] == config.fetch(:skill)
  end
  expected_skill_presentation = tools.any? do |tool|
    tool[:name] == "use_skill" &&
      tool[:skill] == config.fetch(:skill) &&
      tool[:presentationKind] == "skill"
  end
  starts_by_call_id = tools.group_by { |tool| tool.fetch(:callIdHash) }
  duplicate_tool_start_call_ids = starts_by_call_id
    .select { |_call_id_hash, starts| starts.length > 1 }
    .keys
  mixed_presentation_duplicate_call_ids = starts_by_call_id
    .each_with_object([]) do |(call_id_hash, starts), duplicates|
      kinds = starts.map { |start| start[:presentationKind] }.compact.uniq
      if kinds.include?("generic") && kinds.any? { |kind| kind != "generic" }
        duplicates << call_id_hash
      end
    end
  presentation_validated = expected_skill_presentation && duplicate_tool_start_call_ids.empty?
  case_validated = workflow_validation.fetch(:validated) && presentation_validated
  {
    case: case_id,
    expectedSkill: config.fetch(:skill),
    requestIdHash: Digest::SHA256.hexdigest(request_id)[0, 12],
    conversationIdHash: Digest::SHA256.hexdigest(conversation_id)[0, 12],
    turnIdHash: Digest::SHA256.hexdigest(turn_id)[0, 12],
    terminalStatus: terminal_status,
    chatCompleted: terminal_status == "completed" && run_error.nil?,
    runError: run_error,
    events: events,
    toolNames: tool_names,
    usedOrnnSearch: tool_names.include?("ornn_search_skills"),
    usedSkill: tool_names.include?("use_skill"),
    usedExpectedSkill: used_expected_skill,
    expectedSkillPresentation: expected_skill_presentation,
    presentationValidated: presentation_validated,
    duplicateToolStartCallIds: duplicate_tool_start_call_ids,
    mixedPresentationDuplicateCallIds: mixed_presentation_duplicate_call_ids,
    startedWorkflow: tool_names.include?("aevatar_start_workflow"),
    readTypedArtifact: tool_names.include?("aevatar_read_workflow_run_artifact"),
    workflowValidationStatus: workflow_validation.fetch(:status),
    workflowValidated: workflow_validation.fetch(:validated),
    caseValidated: case_validated,
    workflowBlockerCodes: workflow_validation.fetch(:blockerCodes),
    committedWorkflow: committed_workflow,
    workflowApprovals: workflow_approvals,
    workflowObservationError: workflow_observation_error,
    toolCalls: tools,
    approvals: approvals,
    authorizations: authorizations,
    assistantText: redacted_text(assistant_text)
  }
end

results = options.fetch(:cases).map do |case_id|
  run_case(
    case_id,
    CASES.fetch(case_id),
    options.fetch(:timeout),
    options.fetch(:inline_fallback),
    options.fetch(:approved_cases).include?(case_id)
  )
rescue AssistantValidationError => e
  { case: case_id, validationError: redacted_text(e.message) }
end

puts JSON.pretty_generate(
  generatedAt: Time.now.utc.iso8601,
  ingress: "nyxid proxy request aevatar /api/chat",
  inputMode: "natural-language",
  workflowMountMode: options.fetch(:inline_fallback) ? "explicit-inline-fallback" : "default",
  approvedCases: options.fetch(:approved_cases),
  results: results
)
