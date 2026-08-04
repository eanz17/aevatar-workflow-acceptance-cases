#!/usr/bin/env ruby

require "base64"
require "digest"
require "json"
require "open3"
require "optparse"
require "securerandom"
require "time"

ROOT = File.expand_path("..", __dir__)

CASES = {
  "01" => {
    prompt: "帮我做一次上线准备度审查：检查发布窗口、备份、监控和回滚条件。请寻找并使用合适的 Ornn skill，实际运行其中的 workflow，并以 typed artifact 为准报告结果。"
  },
  "12" => {
    prompt: "请用安全代码执行验收案例核对这笔合成结算：小计 152.30 美元、税率 7.5%、手续费 0.50 美元。寻找并使用合适的 Ornn skill，实际运行 workflow；如果平台阻止执行，请返回真实 typed blocker。"
  },
  "13" => {
    prompt: "请从这张合成发票图片中提取字段、归一化金额和日期，并检查历史重复。寻找并使用合适的 Ornn skill，实际运行 workflow；不要创建审批，结果只以 typed artifact 为准。",
    image: "synthetic-invoice.png"
  },
  "14" => {
    prompt: "请把验收入职邮箱解析为 Lark 联系人 ID，只返回是否成功和解析数量。寻找并使用合适的 Ornn skill，实际运行 workflow；如果缺少 Lark 权限，请原样报告 typed blocker，不要伪造联系人。"
  },
  "15" => {
    prompt: "请生成合成预算的周度和月度差异摘要，不发送任何消息。寻找并使用合适的 Ornn skill，实际运行 workflow，并以 typed artifact 为准报告结果。"
  }
}.freeze

class AssistantValidationError < StandardError; end

options = { cases: CASES.keys, timeout: 600, inline_fallback: false }
OptionParser.new do |parser|
  parser.banner = "用法：ruby scripts/assistant_validate.rb [选项]"
  parser.on("--cases LIST", "逗号分隔的案例编号，默认 01,12,13,14,15") do |value|
    options[:cases] = value.split(",").map(&:strip)
  end
  parser.on("--timeout SECONDS", Integer, "单次请求超时，默认 600 秒") do |value|
    options[:timeout] = value
  end
  parser.on("--inline-fallback", "诊断 issue 3182：禁用 mount，改用 inline workflow YAML") do
    options[:inline_fallback] = true
  end
end.parse!

unknown = options.fetch(:cases) - CASES.keys
abort "未知案例：#{unknown.join(', ')}" unless unknown.empty?

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

def parse_tool_result(result)
  typed_failure_codes = result.scan(
    /\b(?:USE_SKILL_MOUNT_NO_WORKFLOWS|USE_SKILL_MOUNT_FAILED|CAPABILITY_ADMISSION_REBIND_REQUIRED|NYXID_PROXY_UNAUTHORIZED|NYXID_PROXY_HTTP_400)\b/i
  ).map(&:upcase).uniq
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
    typedFailureCodes: typed_failure_codes
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
  mount_blocked = mount_results.any? { |result| result.dig(:signals, :failed) } ||
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

def run_case(case_id, config, timeout, inline_fallback)
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

  stderr_text = +""
  status = nil
  Open3.popen3("nyxid", *arguments) do |stdin, stdout, stderr, wait_thread|
    stdin.write(JSON.generate(body))
    stdin.close
    stderr_thread = Thread.new { stderr.read }
    deadline = Time.now + timeout
    stdout.each_line do |line|
      raise AssistantValidationError, "案例 #{case_id} 的 /api/chat 超时" if Time.now >= deadline
      next unless line.start_with?("data: ")

      event = JSON.parse(line.delete_prefix("data: "))
      type = event["type"]
      events << type unless events.last == type
      case type
      when "RUN_STARTED"
        conversation_id = event["actorId"]
        turn_id = event["turnId"]
      when "TOOL_CALL_START"
        tools << {
          name: event.dig("toolCallStart", "toolName"),
          callIdHash: Digest::SHA256.hexdigest(event.dig("toolCallStart", "toolCallId").to_s)[0, 12]
        }
      when "TOOL_CALL_END"
        current = tools.reverse.find do |tool|
          tool[:callIdHash] == Digest::SHA256.hexdigest(event.dig("toolCallEnd", "toolCallId").to_s)[0, 12]
        end
        current[:result] = parse_tool_result(event.dig("toolCallEnd", "result").to_s) if current
      when "TEXT_MESSAGE_CONTENT"
        assistant_text << event.dig("textMessageContent", "delta").to_s
      when "TOOL_APPROVAL_REQUEST"
        approvals << {
          tool: event.dig("toolApprovalRequest", "toolName"),
          destructive: event.dig("toolApprovalRequest", "isDestructive") == true
        }
      when "CUSTOM"
        if event.dig("custom", "name") == "nyxid.authorization.required"
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
    rescue JSON::ParserError
      next
    end
    stderr_text = stderr_thread.value
    status = wait_thread.value
  end

  unless status&.success? && !stderr_text.include?("Proxy request failed")
    raise AssistantValidationError, "案例 #{case_id} 的 NyxID 请求失败：#{redacted_text(stderr_text)}"
  end
  raise AssistantValidationError, "案例 #{case_id} 未收到 RUN_STARTED" unless conversation_id && turn_id

  tool_names = tools.map { |tool| tool.fetch(:name) }
  workflow_validation = classify_workflow(tools, run_error)
  {
    case: case_id,
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
    startedWorkflow: tool_names.include?("aevatar_start_workflow"),
    readTypedArtifact: tool_names.include?("aevatar_read_workflow_run_artifact"),
    workflowValidationStatus: workflow_validation.fetch(:status),
    workflowValidated: workflow_validation.fetch(:validated),
    workflowBlockerCodes: workflow_validation.fetch(:blockerCodes),
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
    options.fetch(:inline_fallback)
  )
rescue AssistantValidationError => e
  { case: case_id, validationError: redacted_text(e.message) }
end

puts JSON.pretty_generate(
  generatedAt: Time.now.utc.iso8601,
  ingress: "nyxid proxy request aevatar /api/chat",
  inputMode: "natural-language",
  workflowMountMode: options.fetch(:inline_fallback) ? "explicit-inline-fallback" : "default",
  results: results
)
