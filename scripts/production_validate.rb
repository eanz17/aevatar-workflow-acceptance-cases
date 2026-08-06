#!/usr/bin/env ruby

require "base64"
require "digest"
require "json"
require "open3"
require "optparse"
require "time"
require "uri"

ROOT = File.expand_path("..", __dir__)
WORKFLOW_DIR = File.join(ROOT, "build", "workflows")

CASES = {
  "01" => {
    file: "01-release-readiness-review.workflow.yaml",
    prompt: "run"
  },
  "02" => {
    file: "02-candidate-document-compliance-preview.workflow.yaml",
    prompt: "检查附件中的合成候选人材料。",
    attachment: "candidate-profile-sample.txt"
  },
  "03" => {
    file: "03-email-access-approval-audit.workflow.yaml",
    prompt: "run"
  },
  "04" => {
    file: "04-saas-license-utilization-review.workflow.yaml",
    prompt: "run"
  },
  "05" => {
    file: "05-asset-inventory-attestation.workflow.yaml",
    prompt: '{"submit":false}',
    mutation_prompt: '{"submit":true}',
    side_effect: "新增一条 Base 资产盘点记录"
  },
  "06" => {
    file: "06-project-shared-mailbox-approval.workflow.yaml",
    prompt: "run",
    mutation_prompt: "run",
    side_effect: "创建一条 Lark 审批"
  },
  "07" => {
    file: "07-quarterly-access-review-reminder.workflow.yaml",
    prompt: '{"submit":false}',
    mutation_prompt: '{"submit":true}',
    side_effect: "发送一条 Lark 私信"
  },
  "08" => {
    file: "08-saas-license-optimization-digest.workflow.yaml",
    prompt: '{"submit":false}',
    mutation_prompt: '{"submit":true}',
    side_effect: "发送一条 Lark 卡片"
  },
  "09" => {
    file: "09-contractor-access-package-approval.workflow.yaml",
    prompt: '{"submit":false}',
    mutation_prompt: '{"submit":true}',
    attachment: "contractor-access-package-sample.txt",
    side_effect: "创建一条 Lark 审批"
  },
  "10" => {
    file: "10-monthly-access-certification.workflow.yaml",
    prompt: '{"mode":"preview","run_date":"2026-08-31","period":"2026-08"}',
    mutation_prompt: '{"mode":"submit","run_date":"2026-08-31","period":"2026-08"}',
    side_effect: "创建一条 Lark 审批并发送完成私信"
  },
  "11" => {
    file: "11-complex-codex-exec-validation.workflow.yaml",
    prompt: "run"
  },
  "12" => {
    file: "12-safe-code-execute-validation.workflow.yaml",
    prompt: "校验这笔合成结算金额。",
    approval_required: true
  },
  "13" => {
    file: "13-invoice-ocr-policy-review.workflow.yaml",
    prompt: "提取这份合成发票，归一化字段并检查历史重复；不要创建审批。",
    attachment: "synthetic-invoice.pdf"
  },
  "14" => {
    file: "14-lark-contact-batch-resolution.workflow.yaml",
    prompt: "解析验收入职邮箱，只返回是否解析成功和数量。",
    approval_required: true,
    preview_contract: {
      method: "post",
      effectiveRisk: "write",
      approvalRequired: true,
      approvalEnforcement: "bind_time_confirmation",
      allowedExecutionModes: ["interactive"]
    }
  },
  "15" => {
    file: "15-weekly-budget-variance-digest.workflow.yaml",
    prompt: "生成合成预算的周度和月度差异摘要；不要发送消息。"
  },
  "16" => {
    file: "16-nyxid-read-receipt-probe.workflow.yaml",
    prompt: "运行单次只读 NyxID receipt 探针，不执行任何写入。",
    preview_contract: { method: "get", effectiveRisk: "read_only", approvalRequired: false }
  },
  "17" => {
    file: "17-lark-post-search-approval-probe.workflow.yaml",
    prompt: "运行语义只读的 Base POST 搜索批准恢复探针，不修改任何记录。",
    approval_required: true,
    preview_contract: {
      method: "post",
      effectiveRisk: "write",
      approvalRequired: true,
      approvalEnforcement: "bind_time_confirmation",
      allowedExecutionModes: ["interactive"]
    }
  },
  "18" => {
    file: "18-supplier-control-attestation-review.workflow.yaml",
    prompt: "运行无副作用的供应商控制项自证审查。"
  }
}.freeze

TERMINAL_STATUSES = %w[completed failed stopped compensated compensation_failed].freeze

class ValidationError < StandardError; end

class NyxIdAevatarClient
  DIAGNOSTIC_BUFFER_BYTES = 64 * 1024

  def initialize(scope_id)
    @scope_id = scope_id
  end

  def nyxid_json(*arguments)
    stdout, stderr, status = Open3.capture3("nyxid", *arguments)
    raise ValidationError, command_error(stderr, stdout, status) unless status.success?
    raise ValidationError, command_error(stderr, stdout, status) if stderr.include?("Proxy request failed")

    JSON.parse(stdout)
  rescue JSON::ParserError => e
    raise ValidationError, "NyxID 未返回有效 JSON：#{e.message}"
  end

  def request_json(path, method: "GET", body: nil)
    arguments = ["proxy", "request", "aevatar", path, "--method", method, "--output", "json"]
    if body
      arguments += ["--header", "Content-Type:application/json", "--data", "-"]
    end
    stdout, stderr, status = Open3.capture3("nyxid", *arguments, stdin_data: body ? JSON.generate(body) : "")
    raise ValidationError, command_error(stderr, stdout, status) unless status.success?
    raise ValidationError, command_error(stderr, stdout, status) if stderr.include?("Proxy request failed")

    JSON.parse(stdout)
  rescue JSON::ParserError => e
    raise ValidationError, "Aevatar 未返回有效 JSON：#{e.message}"
  end

  def request_stream(path, body)
    arguments = [
      "proxy", "request", "aevatar", path,
      "--method", "POST",
      "--header", "Content-Type:application/json",
      "--header", "Accept:text/event-stream",
      "--data", "-",
      "--stream",
      "--output", "json"
    ]
    captured_stdout = +"".b
    captured_stderr = +"".b
    status = nil
    Open3.popen3("nyxid", *arguments) do |stdin, stdout, stderr, wait_thread|
      stderr_thread = Thread.new { read_diagnostic_stream(stderr) }
      stdin.write(JSON.generate(body))
      stdin.close
      stdout.each_line do |line|
        captured_stdout = append_diagnostic(captured_stdout, line)
        yield line
      end
      captured_stderr = stderr_thread.value
      status = wait_thread.value
    end
    raise ValidationError, command_error(captured_stderr, captured_stdout, status) unless status&.success?
    if captured_stderr.include?("Proxy request failed")
      raise ValidationError, command_error(captured_stderr, captured_stdout, status)
    end
  end

  def scope_path(suffix)
    "/api/scopes/#{URI.encode_www_form_component(@scope_id)}#{suffix}"
  end

  private

  def read_diagnostic_stream(io)
    buffer = +"".b
    loop do
      buffer = append_diagnostic(buffer, io.readpartial(16_384))
    end
  rescue EOFError
    buffer
  end

  def append_diagnostic(buffer, chunk)
    combined = buffer + chunk.to_s.b
    return combined if combined.bytesize <= DIAGNOSTIC_BUFFER_BYTES

    combined.byteslice(combined.bytesize - DIAGNOSTIC_BUFFER_BYTES, DIAGNOSTIC_BUFFER_BYTES)
  end

  def printable_diagnostic(value)
    value.to_s.force_encoding(Encoding::UTF_8).scrub.strip
  end

  def command_error(stderr, stdout, status)
    detail = [stderr, stdout].map { |value| printable_diagnostic(value) }.reject(&:empty?).join(" | ")
    "NyxID 请求失败（exit=#{status.exitstatus}）：#{detail}"
  end
end

class ProductionValidator
  def initialize(options)
    @options = options
    @client = NyxIdAevatarClient.new(options.fetch(:scope_id))
  end

  def run
    lark_service_id = resolve_lark_service_id
    results = @options.fetch(:cases).map do |case_id|
      validate_case(case_id, CASES.fetch(case_id), lark_service_id)
    rescue ValidationError => e
      {
        case: case_id,
        result: "失败",
        error: sanitize_error(e.message)
      }
    end

    puts JSON.pretty_generate(
      generatedAt: Time.now.utc.iso8601,
      scopeHash: Digest::SHA256.hexdigest(@options.fetch(:scope_id))[0, 12],
      larkServiceHash: Digest::SHA256.hexdigest(lark_service_id)[0, 12],
      runEnabled: @options.fetch(:run),
      approvedSideEffectCases: @options.fetch(:side_effect_cases).sort,
      approvedReadOnlyCases: @options.fetch(:read_only_approval_cases).sort,
      results: results
    )
    exit 1 if results.any? { |item| item[:result] == "失败" }
  end

  private

  def validate_case(case_id, config, lark_service_id)
    workflow_path = File.join(WORKFLOW_DIR, config.fetch(:file))
    raise ValidationError, "缺少已物化工作流：#{config.fetch(:file)}" unless File.file?(workflow_path)

    yaml = File.read(workflow_path).gsub(
      /user_service_id:\s*\S+/,
      "user_service_id: #{lark_service_id}"
    )
    if @options.fetch(:run) && case_id == "14" &&
        yaml.include?(%q{"emails":["acceptance-user@example.com"]})
      raise ValidationError, "案例 14 真实运行拒绝 config.example.yaml 的示例邮箱；请先使用 config.local.yaml 物化"
    end

    display_name = "公开验收案例 #{case_id}-#{Digest::SHA256.hexdigest(yaml)[0, 10]}"
    preview = preview_workflow(yaml, display_name)
    if config[:preview_contract]
      item = preview.fetch("items").first
      expected = config.fetch(:preview_contract)
      actual = expected.keys.to_h { |key| [key, item&.fetch(key.to_s, nil)] }
      unless preview.fetch("items").length == 1 && actual == expected
        raise ValidationError, "定向 preview 契约不匹配：预期 #{expected.inspect}，实际 #{actual.inspect}"
      end
    end
    base_result = {
      case: case_id,
      workflow: config.fetch(:file),
      preview: "通过",
      callSiteCount: preview.fetch("items").length,
      callSites: preview.fetch("items").map do |item|
        {
          method: item["method"],
          pathTemplate: item["pathTemplate"],
          effectiveRisk: item["effectiveRisk"],
          approvalRequired: item["approvalRequired"],
          allowedExecutionModes: item["allowedExecutionModes"]
        }
      end
    }

    return base_result.merge(result: "仅预检") unless @options.fetch(:run)

    if config[:side_effect] && !@options.fetch(:side_effect_cases).include?(case_id)
      return base_result.merge(result: "仅预检", runSkipped: "未授权副作用：#{config[:side_effect]}") if case_id == "06"
    end

    member_id, revision_id, binding_reused = prepare_binding(yaml, preview, display_name)
    wait_for_endpoint(member_id, revision_id)
    run_result = invoke_workflow(case_id, config, member_id, revision_id)
    base_result
      .merge(binding: binding_reused ? "复用现有 revision" : "新建 revision")
      .merge(run_result)
      .merge(result: run_result.fetch(:success) ? "通过" : "失败")
  end

  def resolve_lark_service_id
    inventory = @client.nyxid_json("service", "list", "--output", "json")
    rows = inventory["keys"] || inventory["services"] || inventory
    candidates = Array(rows).select do |item|
      ["api-lark-bot", "api-lark-bot-2"].include?(item["slug"]) &&
        item["connected"] == true &&
        item["is_active"] == true &&
        item.dig("credential_source", "allowed") != false
    end
    if @options[:lark_service_id]
      selected = candidates.find { |item| item["id"] == @options.fetch(:lark_service_id) }
      raise ValidationError, "指定的 Lark Bot UserService 当前不可用" unless selected

      return selected.fetch("id")
    end

    preferred = candidates.find { |item| item.dig("credential_source", "type") == "org" }
    selected = preferred || candidates.first
    raise ValidationError, "当前 NyxID 账号没有可用的 Lark Bot UserService" unless selected

    selected.fetch("id")
  end

  def preview_workflow(yaml, display_name)
    provision_key = build_provision_key(display_name)
    body = {
      workflowYaml: yaml,
      executionMode: "interactive",
      workflowId: "workflow-#{provision_key}",
      revisionId: "revision-#{provision_key}"
    }
    response = @client.request_json(
      @client.scope_path("/workflows:explicit-request-preview"),
      method: "POST",
      body: body
    )
    raise ValidationError, response["message"] if response["code"]
    response
  end

  def prepare_binding(yaml, preview, display_name)
    provision_key = build_provision_key(display_name)
    expected_member_id = "wf-#{provision_key}"
    existing_revision_id = resolve_existing_revision(expected_member_id)
    if existing_revision_id
      return [expected_member_id, existing_revision_id, true]
    end

    provision = provision_workflow(yaml, preview, display_name)
    binding = wait_for_binding(provision.fetch("memberId"), provision.fetch("bindingRunId"))
    [provision.fetch("memberId"), binding.dig("result", "revisionId"), false]
  end

  def resolve_existing_revision(member_id)
    response = @client.request_json(
      @client.scope_path(
        "/members/#{URI.encode_www_form_component(member_id)}/binding"
      )
    )
    return response.dig("lastBinding", "revisionId") if response["lastBinding"]

    current_run_id = response.dig("currentBindingRun", "bindingRunId")
    return nil unless current_run_id

    wait_for_binding(member_id, current_run_id).dig("result", "revisionId")
  rescue ValidationError => e
    return nil if e.message.include?("HTTP 404") || e.message.include?("STUDIO_MEMBER_NOT_FOUND")
    raise
  end

  def build_provision_key(display_name)
    Digest::SHA256.hexdigest(
      [@options.fetch(:scope_id), @options.fetch(:team_id), display_name].join("\n")
    )[0, 32]
  end

  def provision_workflow(yaml, preview, display_name)
    confirmations = preview.fetch("items").map do |item|
      {
        callSiteId: item.fetch("callSiteId"),
        requestContractDigest: item.fetch("requestContractDigest"),
        attestedRisk: item.fetch("effectiveRisk"),
        workflowId: "",
        revisionId: ""
      }
    end
    body = {
      displayName: display_name,
      teamId: @options.fetch(:team_id),
      workflowYaml: yaml,
      runImmediately: false,
      caller: {
        platform: "nyxid",
        externalUserId: @options.fetch(:scope_id),
        scope: "proxy"
      },
      explicitRequestConfirmations: confirmations
    }
    response = @client.request_json(
      @client.scope_path("/provision-workflow"),
      method: "POST",
      body: body
    )
    raise ValidationError, response["message"] if response["code"]
    response
  end

  def wait_for_binding(member_id, binding_run_id)
    deadline = Time.now + @options.fetch(:timeout)
    loop do
      begin
        response = @client.request_json(
          @client.scope_path(
            "/members/#{URI.encode_www_form_component(member_id)}/binding-runs/#{URI.encode_www_form_component(binding_run_id)}"
          )
        )
      rescue ValidationError => e
        raise unless e.message.include?("STUDIO_MEMBER_BINDING_RUN_NOT_FOUND")
        raise ValidationError, "等待绑定投影超时" if Time.now >= deadline
        sleep 2
        next
      end
      return response if response["status"] == "succeeded"
      raise ValidationError, "绑定失败：#{response.dig("failure", "message") || response["status"]}" if response["status"] == "failed"
      raise ValidationError, "等待绑定超时" if Time.now >= deadline
      sleep 2
    end
  end

  def invoke_workflow(case_id, config, member_id, revision_id)
    side_effect = @options.fetch(:side_effect_cases).include?(case_id)
    read_only_approval = @options.fetch(:read_only_approval_cases).include?(case_id)
    approval_allowed = @options.fetch(:approve) && (side_effect || read_only_approval)
    prompt = @options[:prompt] ||
      (side_effect ? config.fetch(:mutation_prompt, config.fetch(:prompt)) : config.fetch(:prompt))
    body = {
      prompt: prompt,
      revisionId: revision_id
    }
    body[:inputParts] = [attachment_part(config.fetch(:attachment))] if config[:attachment]

    path = @client.scope_path(
      "/members/#{URI.encode_www_form_component(member_id)}/invoke/chat:stream"
    )
    evidence = {}
    approved_keys = {}
    @client.request_stream(path, body) do |line|
      approval = parse_stream_line(evidence, line)
      next unless approval

      validate_approval_identity!(approval)
      evidence[:typed_approval_identity_present] = true
      unless approval_allowed
        raise ValidationError, "运行等待 tool approval；必须显式允许对应的写入或只读批准后才会继续"
      end
      raise ValidationError, "tool approval 到达前没有 run ID" unless evidence[:run_id]
      next if approved_keys[approval.fetch(:approval_request_id)]

      approve(member_id, evidence.fetch(:run_id), approval)
      approved_keys[approval.fetch(:approval_request_id)] = true
    end
    raise ValidationError, "运行未返回 run ID" unless evidence[:run_id]

    detail = wait_for_run(member_id, evidence.fetch(:run_id), approval_allowed, approved_keys, evidence)
    final_output = detail["finalOutput"]
    final_output = evidence[:final_output] if final_output.to_s.strip.empty?
    terminal_success = detail.dig("summary", "status") == "completed" && detail.dig("summary", "success") == true
    runtime_contract_evidence = {}
    contract_failure = nil
    if terminal_success
      begin
        runtime_contract_evidence = validate_runtime_contract(case_id, detail, final_output, evidence)
      rescue ValidationError => e
        contract_failure = e.message
      end
    end
    success = terminal_success && contract_failure.nil?
    {
      run: "已提交并查询 committed read model",
      runIdHash: Digest::SHA256.hexdigest(evidence.fetch(:run_id))[0, 12],
      terminalStatus: detail.dig("summary", "status"),
      terminalSuccess: terminal_success,
      success: success,
      stateVersion: detail.dig("summary", "stateVersion"),
      completedSteps: detail.dig("statistics", "completedSteps"),
      totalSteps: detail.dig("statistics", "totalSteps"),
      finalOutput: sanitize_output(final_output),
      failure: sanitize_output(contract_failure || terminal_failure(detail)),
      sideEffectAuthorized: side_effect,
      readOnlyApprovalAuthorized: read_only_approval
    }.merge(runtime_contract_evidence)
  end

  def wait_for_endpoint(member_id, revision_id)
    deadline = Time.now + @options.fetch(:timeout)
    loop do
      begin
        contract = @client.request_json(
          @client.scope_path(
            "/members/#{URI.encode_www_form_component(member_id)}/endpoints/chat/contract"
          )
        )
      rescue ValidationError => e
        raise unless e.message.include?("HTTP 404")
        raise ValidationError, "等待 member endpoint 投影超时" if Time.now >= deadline
        sleep 2
        next
      end

      readiness = contract["invocationReadiness"] || {}
      return if readiness["canInvoke"] == true && contract["revisionId"] == revision_id
      raise ValidationError, "等待 member endpoint 就绪超时，当前状态：#{readiness['status']}" if Time.now >= deadline
      sleep 2
    end
  end

  def attachment_part(name)
    path = File.join(ROOT, "fixtures", name)
    bytes = File.binread(path)
    {
      type: "file",
      inlineFile: {
        dataBase64: Base64.strict_encode64(bytes),
        mediaType: File.extname(name).downcase == ".pdf" ? "application/pdf" : "text/plain",
        name: name,
        sizeBytes: bytes.bytesize,
        ownerScopeId: @options.fetch(:scope_id)
      }
    }
  end

  def parse_stream_line(evidence, line)
    return nil unless line.start_with?("data: ")

    event = JSON.parse(line.delete_prefix("data: "))
    custom = event["custom"]
    if custom && custom["name"] == "aevatar.run.context"
      evidence[:run_id] = custom.dig("payload", "actorId")
    elsif custom && custom["name"] == "aevatar.tool_approval.pending"
      payload = custom.fetch("payload")
      return {
        step_id: payload["stepId"],
        execution_id: payload["executionId"],
        tool_call_id: payload["toolCallId"],
        approval_request_id: payload["approvalRequestId"]
      }
    elsif event["runFinished"]
      evidence[:final_output] = event.dig("runFinished", "result", "output")
    end
    nil
  rescue JSON::ParserError
    nil
  end

  def wait_for_run(member_id, run_id, approval_allowed, approved_keys = {}, evidence = {})
    deadline = Time.now + @options.fetch(:timeout)
    loop do
      detail = @client.request_json(
        "/api/workflow/observatory/runs/#{URI.encode_www_form_component(run_id)}"
      )
      status = detail.dig("summary", "status")
      return detail if TERMINAL_STATUSES.include?(status)

      if status == "awaiting_tool_approval"
        approval_step = Array(detail["steps"]).reverse.find do |step|
          step["completedAtUtc"].nil? && step["toolApproval"]
        end
        raise ValidationError, "read model 缺少 typed tool approval identity" unless approval_step
        approval = approval_step.fetch("toolApproval")
        key = approval["approvalRequestId"]
        unless approved_keys[key]
          unless approval_allowed
            raise ValidationError, "运行等待 tool approval；没有获得自动批准授权"
          end
          typed_approval = {
            step_id: approval_step["stepId"],
            execution_id: approval["executionId"],
            tool_call_id: approval["toolCallId"],
            approval_request_id: key
          }
          validate_approval_identity!(typed_approval)
          key = typed_approval.fetch(:approval_request_id)
          evidence[:typed_approval_identity_present] = true
          approve(member_id, run_id, typed_approval)
          approved_keys[key] = true
        end
      end

      raise ValidationError, "等待运行终态超时，当前状态：#{status}" if Time.now >= deadline
      sleep 2
    end
  end

  def approve(member_id, run_id, approval)
    body = {
      stepId: approval.fetch(:step_id),
      approved: true,
      actorId: run_id,
      toolApproval: {
        executionId: approval.fetch(:execution_id),
        toolCallId: approval.fetch(:tool_call_id),
        approvalRequestId: approval.fetch(:approval_request_id)
      }
    }
    response = @client.request_json(
      @client.scope_path(
        "/members/#{URI.encode_www_form_component(member_id)}/runs/#{URI.encode_www_form_component(run_id)}:resume"
      ),
      method: "POST",
      body: body
    )
    raise ValidationError, response["message"] || response["error"] unless response["accepted"] == true
  end

  def validate_approval_identity!(approval)
    required = %i[step_id execution_id tool_call_id approval_request_id]
    return if required.all? { |key| !approval[key].to_s.strip.empty? }

    raise ValidationError, "typed tool approval identity 不完整"
  end

  def sanitize_output(output)
    return nil if output.nil?
    return scrub_identifiers(output) if output.is_a?(Hash) || output.is_a?(Array)

    scrub_identifiers(JSON.parse(output.to_s))
  rescue JSON::ParserError
    output.to_s
      .gsub(/[0-9a-f]{8}(?:-[0-9a-f]{4}){3}-[0-9a-f]{12}/i, "<已脱敏>")
      .gsub(/\b[0-9a-f]{32}\b/i, "<已脱敏>")
      .slice(0, 800)
  end

  def validate_runtime_contract(case_id, detail, final_output, evidence = {})
    contract = case case_id
               when "14"
                 {
                   step_id: "resolve_contact",
                   expected_artifact: {
                     "case" => "lark_contact_batch_resolution",
                     "success" => true,
                     "contact_api_reachable" => true,
                     "resolved_count" => 1,
                     "identifiers_redacted" => true,
                     "side_effects" => false
                   },
                   approval_required: false
                 }
               when "16"
                 {
                   step_id: "read_base_records",
                   expected_artifact: {
                     "success" => true,
                     "provider_response_verified" => true,
                     "side_effects" => false
                   },
                   approval_required: false
                 }
               when "17"
                 {
                   step_id: "search_base_records",
                   expected_artifact: {
                     "success" => true,
                     "approval_resumed" => true,
                     "side_effects" => false
                   },
                   approval_required: false
                 }
               when "18"
                 {
                   step_id: "replay_control_order",
                   expected_artifact: {
                     "attested" => true,
                     "control_count" => 3,
                     "leading_control" => "breach_notice",
                     "replay_iterations" => 3,
                     "side_effects" => false
                   },
                   approval_required: false
                 }
               else
                 return {}
               end

    first_step = Array(detail["steps"]).find { |step| step["stepId"] == contract.fetch(:step_id) }
    unless first_step && first_step["success"] == true && !first_step["outputPreview"].to_s.strip.empty?
      raise ValidationError, "案例 #{case_id} committed read model 缺少非空首步输出"
    end

    typed_approval_present = false
    if contract.fetch(:approval_required)
      approval = first_step["toolApproval"]
      read_model_identity_present = approval.is_a?(Hash) &&
        %w[executionId toolCallId approvalRequestId].all? { |key| !approval[key].to_s.strip.empty? }
      typed_approval_present = read_model_identity_present || evidence[:typed_approval_identity_present] == true
      raise ValidationError, "案例 #{case_id} 运行缺少 typed approval identity" unless typed_approval_present
    end

    artifact = final_output.is_a?(String) ? JSON.parse(final_output) : final_output
    expected = contract.fetch(:expected_artifact)
    actual = expected.keys.to_h { |key| [key, artifact.is_a?(Hash) ? artifact[key] : nil] }
    raise ValidationError, "案例 #{case_id} 最终 artifact 契约不匹配：#{actual.inspect}" unless actual == expected

    evidence = {
      firstToolStepOutputPresent: true,
      finalArtifactVerified: true
    }
    evidence[:typedApprovalIdentityPresent] = true if typed_approval_present
    evidence
  rescue JSON::ParserError => e
    raise ValidationError, "案例 #{case_id} 最终 artifact 不是有效 JSON：#{e.message}"
  end

  def terminal_failure(detail)
    detail.dig("summary", "lastError") ||
      detail.dig("summary", "error") ||
      detail["lastError"] ||
      detail["error"] ||
      Array(detail["steps"]).reverse.find { |step| !step["error"].to_s.empty? }&.fetch("error", nil)
  end

  def scrub_identifiers(value)
    case value
    when Hash
      value.each_with_object({}) do |(key, item), result|
        key_name = key.to_s
        identifier_key = key_name.match?(/instance_code|diagnostic_id/i) || key_name.end_with?("_id", "Id", "ID")
        sensitive_id = identifier_key && item.to_s != ""
        result[key] = sensitive_id ? "<已脱敏>" : scrub_identifiers(item)
      end
    when Array
      value.map { |item| scrub_identifiers(item) }
    when String
      value
        .gsub(/[0-9a-f]{8}(?:-[0-9a-f]{4}){3}-[0-9a-f]{12}/i, "<已脱敏>")
        .gsub(/\b[0-9a-f]{32}\b/i, "<已脱敏>")
    else
      value
    end
  end

  def sanitize_error(message)
    codes = []
    protected_message = message.gsub(/\b[A-Z][A-Z0-9]*(?:_[A-Z0-9]+){2,}\b/) do |code|
      codes << code
      "@@CODE#{codes.length - 1}@@"
    end
    sanitized = protected_message
      .gsub(/[0-9a-f]{8}(?:-[0-9a-f]{4}){3}-[0-9a-f]{12}/i, "<已脱敏>")
      .gsub(/[A-Za-z0-9_-]{20,}/, "<长标识已脱敏>")
      .slice(0, 800)
    codes.each_with_index { |code, index| sanitized = sanitized.gsub("@@CODE#{index}@@", code) }
    sanitized
  end
end

options = {
  scope_id: ENV["AEVATAR_SCOPE_ID"],
  team_id: ENV["AEVATAR_TEAM_ID"],
  lark_service_id: ENV["LARK_USER_SERVICE_ID"],
  cases: CASES.keys,
  run: false,
  approve: false,
  side_effect_cases: [],
  read_only_approval_cases: [],
  timeout: 420,
  prompt: nil
}

OptionParser.new do |parser|
  parser.banner = "用法：ruby scripts/production_validate.rb [选项]"
  parser.on("--scope-id ID", "Aevatar scope ID，也可使用 AEVATAR_SCOPE_ID") { |value| options[:scope_id] = value }
  parser.on("--team-id ID", "用于创建临时验收成员的 Studio team ID，也可使用 AEVATAR_TEAM_ID") { |value| options[:team_id] = value }
  parser.on("--lark-user-service-id ID", "固定 Lark Bot UserService，也可使用 LARK_USER_SERVICE_ID") { |value| options[:lark_service_id] = value }
  parser.on("--cases LIST", "案例编号，逗号分隔；默认 01-17") { |value| options[:cases] = value.split(",").map { |item| item.strip.rjust(2, "0") } }
  parser.on("--run", "在 preview 后执行工作流；默认只 preview") { options[:run] = true }
  parser.on("--allow-side-effects LIST", "允许执行副作用的案例编号，逗号分隔") do |value|
    options[:side_effect_cases] = value.split(",").map { |item| item.strip.rjust(2, "0") }
  end
  parser.on("--approve-read-only LIST", "允许批准只读但被平台门禁的案例编号，逗号分隔") do |value|
    options[:read_only_approval_cases] = value.split(",").map { |item| item.strip.rjust(2, "0") }
  end
  parser.on("--approve", "通过 typed receipt 自动批准已允许案例的 tool approval") { options[:approve] = true }
  parser.on("--timeout SECONDS", Integer, "单个绑定或运行的超时秒数；默认 420") { |value| options[:timeout] = value }
  parser.on("--prompt TEXT", "覆盖单个案例的运行输入，用于验证同一定义的其他分支") { |value| options[:prompt] = value }
end.parse!

abort "缺少 --scope-id 或 AEVATAR_SCOPE_ID" if options[:scope_id].to_s.strip.empty?
abort "缺少 --team-id 或 AEVATAR_TEAM_ID" if options[:team_id].to_s.strip.empty?
unknown_cases = options[:cases] - CASES.keys
abort "未知案例：#{unknown_cases.join(", ")}" unless unknown_cases.empty?
unknown_side_effect_cases = options[:side_effect_cases] - CASES.keys
abort "未知副作用案例：#{unknown_side_effect_cases.join(", ")}" unless unknown_side_effect_cases.empty?
unknown_read_only_cases = options[:read_only_approval_cases] - CASES.keys
abort "未知只读批准案例：#{unknown_read_only_cases.join(", ")}" unless unknown_read_only_cases.empty?
invalid_read_only_cases = options[:read_only_approval_cases].reject { |case_id| CASES.fetch(case_id)[:approval_required] }
abort "这些案例未声明只读批准契约：#{invalid_read_only_cases.join(", ")}" unless invalid_read_only_cases.empty?
if options[:approve] && options[:side_effect_cases].empty? && options[:read_only_approval_cases].empty?
  abort "--approve 必须与 --allow-side-effects 或 --approve-read-only 一起使用"
end
abort "--prompt 只能与单个 --cases 案例一起使用" if options[:prompt] && options[:cases].length != 1

ProductionValidator.new(options).run
