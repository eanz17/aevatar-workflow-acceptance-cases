#!/usr/bin/env ruby

# 执行 risk-cases 33-36 的 admission 探针：验证平台对越界工作流定义的
# fail-closed 行为（缺失 capability、path 槽位越界、n8n 导出、durable 写准入）。
# 案例 34 是混合探针：平台契约允许 path_params 槽位值来自 workflow 表达式，
# 因此只有模板化 selector 与越出单段的槽位值才必须被拒绝。
# 只读 + 预期拒绝路径；案例 33 会创建一个失败终态的探针成员运行，不产生外部写入。
# 输出脱敏后的机器证据 JSON，供 validation/risk-validation-*.json 与
# scripts/validate_risk_cases.rb 消费。

require "digest"
require "json"
require "optparse"
require "time"
require "uri"
require "yaml"

require_relative "production_validate"

PROBE_ROOT = File.expand_path("..", __dir__)

def sanitize_probe_error(message)
  codes = []
  # 与 stable_error_code 同口径（>=2 段），避免两段式稳定错误码被当成长标识误删。
  protected_message = message.to_s.gsub(/\b[A-Z][A-Z0-9]*(?:_[A-Z0-9]+){1,}\b/) do |code|
    codes << code
    "@@CODE#{codes.length - 1}@@"
  end
  sanitized = protected_message.gsub(
    /[0-9a-f]{8}(?:-[0-9a-f]{4}){3}-[0-9a-f]{12}/i,
    "<已脱敏>"
  )
  # Lark table/record/view ID 短于长标识阈值，必须单独脱敏。
  sanitized = sanitized
    .gsub(/\b(?:tbl|rec|vew)[A-Za-z0-9]{8,}\b/, "<已脱敏>")
    .gsub(/[A-Za-z0-9_-]{20,}/, "<长标识已脱敏>")
  # 先还原稳定错误码再截断，否则截断可能切断 @@CODEn@@ 占位符导致错误码永久丢失。
  codes.each_with_index { |code, index| sanitized = sanitized.gsub("@@CODE#{index}@@", code) }
  sanitized.slice(0, 400)
end

def stable_error_code(message)
  message.to_s.scan(/\b[A-Z][A-Z0-9]*(?:_[A-Z0-9]+){1,}\b/).first
end

class AdmissionProbeRunner
  MISSING_CAPABILITY_YAML = <<~YAML
    name: admission_missing_capability_probe
    description: 负例探针：nyxid_proxy 调用未声明 capability，预期运行期被 operation admission 拒绝。
    roles:
      - id: prober
        name: 准入探针
    steps:
      - id: call_without_capability
        type: tool_call
        parameters:
          tool: nyxid_proxy
          arguments: '{"query":{"page_size":"1"}}'
        next: done
      - id: done
        type: assign
        parameters:
          target: final
          value: "$input"
  YAML

  # 正例：selector 静态，运行时只为 path_template 已声明的槽位提供值，值来自
  # 步骤输出。平台契约允许这种取值（canon workflow-primitives.md 的
  # {"path_params":{"object_id":"${input}"}} 即同一形态），因此期望放行；
  # 合成 app_token 无效，最坏结果是 Lark 侧 4xx，不产生写入。
  PATH_SLOT_ADMITTED_YAML_TEMPLATE = <<~YAML
    name: admission_path_slot_admitted_probe
    description: 正例探针：path 槽位值由步骤输出提供，预期准入放行且路由仍由 path_template 固定。
    roles:
      - id: prober
        name: 准入探针
    steps:
      - id: seed_token
        type: assign
        parameters:
          target: seeded
          value: "not-a-real-app-token"
        next: read_with_slot_value
      - id: read_with_slot_value
        type: tool_call
        capability:
          nyxid_request:
            user_service_id: %<service_id>s
            method: GET
            path_template: /open-apis/bitable/v1/apps/{app_token}/tables/{table_id}/records
            query_parameters: [page_size]
            header_parameters: []
            body_mode: none
            body_required: false
            response_mode: text
        parameters:
          tool: nyxid_proxy
          arguments: '{"path_params":{"app_token":"${steps.seed_token.output}","table_id":"${steps.seed_token.output}"},"query":{"page_size":"1"}}'
        next: done
      - id: done
        type: assign
        parameters:
          target: final
          value: "$input"
  YAML

  # 负例 A：把表达式内联进 selector 的 path_template。path_template 参与
  # request_contract_digest，必须逐字静态，预期在 preview/provision 即被拒绝。
  TEMPLATED_SELECTOR_YAML_TEMPLATE = <<~YAML
    name: admission_templated_selector_probe
    description: 负例探针：selector 的 path_template 内联表达式，预期被显式请求契约拒绝。
    roles:
      - id: prober
        name: 准入探针
    steps:
      - id: seed_token
        type: assign
        parameters:
          target: seeded
          value: "not-a-real-app-token"
        next: read_with_templated_selector
      - id: read_with_templated_selector
        type: tool_call
        capability:
          nyxid_request:
            user_service_id: %<service_id>s
            method: GET
            path_template: /open-apis/bitable/v1/apps/${steps.seed_token.output}/tables/{table_id}/records
            query_parameters: [page_size]
            header_parameters: []
            body_mode: none
            body_required: false
            response_mode: text
        parameters:
          tool: nyxid_proxy
          arguments: '{"path_params":{"table_id":"${steps.seed_token.output}"},"query":{"page_size":"1"}}'
        next: done
      - id: done
        type: assign
        parameters:
          target: final
          value: "$input"
  YAML

  # 负例 B：槽位值本身合法（表达式取值），但解析后含路径分隔符与 dot segment，
  # 会越出单个 path segment。预期运行期在调用 provider 之前 fail-closed。
  SLOT_ESCAPE_YAML_TEMPLATE = <<~YAML
    name: admission_path_slot_escape_probe
    description: 负例探针：path 槽位值解析后越出单段，预期运行期在 provider 调用前拒绝。
    roles:
      - id: prober
        name: 准入探针
    steps:
      - id: seed_escape
        type: assign
        parameters:
          target: seeded
          value: "a/../../open-apis/im/v1/messages"
        next: read_with_escaping_slot
      - id: read_with_escaping_slot
        type: tool_call
        capability:
          nyxid_request:
            user_service_id: %<service_id>s
            method: GET
            path_template: /open-apis/bitable/v1/apps/{app_token}/tables/{table_id}/records
            query_parameters: [page_size]
            header_parameters: []
            body_mode: none
            body_required: false
            response_mode: text
        parameters:
          tool: nyxid_proxy
          arguments: '{"path_params":{"app_token":"${steps.seed_escape.output}","table_id":"not-a-real-table"},"query":{"page_size":"1"}}'
        next: done
      - id: done
        type: assign
        parameters:
          target: final
          value: "$input"
  YAML

  N8N_EXPORT_JSON = JSON.generate(
    "name" => "admission_n8n_export_probe",
    "nodes" => [
      {
        "id" => "webhook-entry",
        "name" => "Webhook",
        "type" => "n8n-nodes-base.webhook",
        "typeVersion" => 1,
        "position" => [0, 0],
        "parameters" => { "path" => "synthetic-probe", "httpMethod" => "POST" }
      }
    ],
    "connections" => {},
    "active" => false,
    "pinData" => {}
  )

  DURABLE_WRITE_YAML_TEMPLATE = <<~YAML
    name: admission_durable_write_probe
    description: 负例探针：未声明风险的写入调用请求 durable 执行模式，预期准入 fail-closed。
    roles:
      - id: prober
        name: 准入探针
    steps:
      - id: create_probe_record
        type: tool_call
        capability:
          nyxid_request:
            user_service_id: %<service_id>s
            method: POST
            path_template: /open-apis/bitable/v1/apps/{app_token}/tables/{table_id}/records
            query_parameters: []
            header_parameters: []
            body_mode: json
            body_required: true
            response_mode: text
        parameters:
          tool: nyxid_proxy
          arguments: '{"path_params":{"app_token":"%<app_token>s","table_id":"%<table_id>s"},"body":{"fields":{"Attestation Key":"durable-admission-probe","Control":"durable 准入探针","Owner":"验收自动化","Status":"Probe"}}}'
        next: done
      - id: done
        type: assign
        parameters:
          target: final
          value: "$input"
  YAML

  def initialize(options)
    @options = options
    @client = NyxIdAevatarClient.new(options.fetch(:scope_id))
  end

  def run
    results = {
      "33" => probe_missing_capability,
      "34" => probe_path_slot_contract,
      "35" => probe_n8n_export,
      "36" => probe_durable_write
    }
    puts JSON.pretty_generate(
      generatedAtUtc: Time.now.utc.iso8601,
      scopeHash: Digest::SHA256.hexdigest(@options.fetch(:scope_id))[0, 12],
      probes: results
    )
    results
  end

  private

  def preview(yaml_text, display_name, execution_mode: "interactive")
    provision_key = Digest::SHA256.hexdigest(
      [@options.fetch(:scope_id), @options.fetch(:team_id), display_name].join("\n")
    )[0, 32]
    @client.request_json(
      @client.scope_path("/workflows:explicit-request-preview"),
      method: "POST",
      body: {
        workflowYaml: yaml_text,
        executionMode: execution_mode,
        workflowId: "workflow-#{provision_key}",
        revisionId: "revision-#{provision_key}"
      }
    )
  end

  def probe_missing_capability
    display_name = "准入负例探针 33-#{Digest::SHA256.hexdigest(MISSING_CAPABILITY_YAML)[0, 10]}-#{@options.fetch(:probe_nonce)}"
    stage = "preview"
    begin
      preview_response = preview(MISSING_CAPABILITY_YAML, display_name)
    rescue ValidationError => e
      return admission_rejection(e, stage)
    end
    preview_call_site_count = Array(preview_response["items"]).length
    if preview_response["code"]
      return admission_rejection_from_body(preview_response, stage, preview_call_site_count)
    end
    unless preview_call_site_count.zero?
      return {
        outcome: "unexpected",
        stage: stage,
        detail: "preview 未按无 capability 处理",
        previewCallSiteCount: preview_call_site_count
      }
    end

    stage = "provision"
    begin
      member_id, revision_id = provision_and_bind(MISSING_CAPABILITY_YAML, preview_response, display_name)
    rescue ValidationError => e
      return admission_rejection(e, stage).merge(previewCallSiteCount: 0)
    end

    stage = "run"
    begin
      run_detail = invoke_and_wait(member_id, revision_id, "run")
    rescue ValidationError => e
      return admission_rejection(e, stage).merge(previewCallSiteCount: 0)
    end
    status = run_detail.dig("summary", "status")
    failing_step = Array(run_detail["steps"]).find { |step| !step["error"].to_s.empty? }
    error_text = failing_step&.fetch("error", nil).to_s
    {
      outcome: status == "failed" && error_text.match?(/admission/i) ? "fail_closed_confirmed" : "unexpected",
      stage: stage,
      previewCallSiteCount: 0,
      terminalStatus: status,
      failingStepId: failing_step&.fetch("stepId", nil),
      stableErrorCode: stable_error_code(error_text),
      sanitizedError: sanitize_probe_error(error_text)
    }
  end

  # 准入语义的拒绝才算 fail-closed 证据；传输层或其他失败保持 unexpected，
  # 避免把偶发错误写成"平台已拦截"。
  def admission_rejection(error, stage)
    confirmed = error.message.match?(/admission|OPERATION_SELECTION|DURABLE_AUTHORIZATION|Unsupported workflow YAML/i)
    {
      outcome: confirmed ? "fail_closed_confirmed" : "unexpected",
      stage: stage,
      stableErrorCode: stable_error_code(error.message),
      sanitizedError: sanitize_probe_error(error.message)
    }
  end

  def admission_rejection_from_body(response, stage, preview_call_site_count = nil)
    message = response["message"].to_s
    confirmed = message.match?(/admission|OPERATION_SELECTION|DURABLE_AUTHORIZATION|Unsupported workflow YAML/i)
    result = {
      outcome: confirmed ? "fail_closed_confirmed" : "unexpected",
      stage: stage,
      stableErrorCode: stable_error_code(message),
      sanitizedError: sanitize_probe_error(message)
    }
    result[:previewCallSiteCount] = preview_call_site_count if preview_call_site_count
    result
  end

  # 案例 34 由三条子探针组成：一条正例证明契约允许的取值被放行且路由未被改写，
  # 两条负例证明 selector 与槽位边界仍然 fail-closed。整体只有三条都符合期望才通过。
  def probe_path_slot_contract
    admitted = probe_slot_value_admitted
    templated_selector = probe_templated_selector_rejected
    slot_escape = probe_slot_escape_rejected
    subprobes = {
      slotValueAdmitted: admitted,
      templatedSelectorRejected: templated_selector,
      slotEscapeRejected: slot_escape
    }
    conforming = admitted[:outcome] == "contract_conformant" &&
      templated_selector[:outcome] == "fail_closed_confirmed" &&
      slot_escape[:outcome] == "fail_closed_confirmed"
    {
      outcome: conforming ? "contract_confirmed" : "unexpected",
      stage: "composite",
      subprobes: subprobes
    }
  end

  # 正例：期望放行到 provider，仅因合成 app_token 无效得到下游 4xx。
  def probe_slot_value_admitted
    yaml_text = format(PATH_SLOT_ADMITTED_YAML_TEMPLATE, service_id: @options.fetch(:lark_service_id))
    # 探针必须每轮新建 member：display_name 若只按内容哈希，第二轮会命中首轮已
    # 成功绑定的 member，把当轮准入行为的证据退化成"复用旧绑定"，结论不可复现。
    display_name = "准入探针 34a-#{Digest::SHA256.hexdigest(yaml_text)[0, 10]}-#{@options.fetch(:probe_nonce)}"
    begin
      preview_response = preview(yaml_text, display_name)
    rescue ValidationError => e
      return unexpected_rejection(e.message, "preview", "契约允许的槽位取值在 preview 被拒绝")
    end
    if preview_response["code"]
      return unexpected_rejection(preview_response["message"].to_s, "preview", "契约允许的槽位取值在 preview 被拒绝")
    end

    begin
      member_id, revision_id = provision_and_bind(yaml_text, preview_response, display_name)
    rescue ValidationError => e
      return unexpected_rejection(e.message, "provision_or_binding", "契约允许的槽位取值在绑定被拒绝")
    end

    run_detail = invoke_and_wait(member_id, revision_id, "run")
    status = run_detail.dig("summary", "status")
    failing_step = Array(run_detail["steps"]).find { |step| !step["error"].to_s.empty? }
    error_text = failing_step&.fetch("error", nil).to_s
    # 期望：准入放行，失败发生在 provider 之后。若失败码属于 path/admission 家族，
    # 说明平台把契约允许的取值也拒绝了，同样记为 unexpected。
    reached_provider = error_text.match?(/NYXID_PROXY_HTTP_/)
    local_rejection = error_text.match?(/NYXID_OPERATION_PATH|ADMISSION|CALL_SITE/i)
    {
      outcome: reached_provider && !local_rejection ? "contract_conformant" : "unexpected",
      stage: "run",
      terminalStatus: status,
      providerReached: reached_provider,
      stableErrorCode: stable_error_code(error_text),
      sanitizedError: sanitize_probe_error(error_text)
    }
  rescue ValidationError => e
    unexpected_rejection(e.message, "run", "正例子探针未取得终态")
  end

  # 负例 A：path_template 内联 ${...}，期望在 preview/provision 被 NyxID 显式请求
  # 契约拒绝（selector 必须逐字静态且进入 request_contract_digest）。
  def probe_templated_selector_rejected
    yaml_text = format(TEMPLATED_SELECTOR_YAML_TEMPLATE, service_id: @options.fetch(:lark_service_id))
    display_name = "准入负例探针 34b-#{Digest::SHA256.hexdigest(yaml_text)[0, 10]}-#{@options.fetch(:probe_nonce)}"
    begin
      preview_response = preview(yaml_text, display_name)
    rescue ValidationError => e
      return selector_rejection(e.message, "preview")
    end
    return selector_rejection(preview_response["message"].to_s, "preview") if preview_response["code"]

    begin
      provision_and_bind(yaml_text, preview_response, display_name)
    rescue ValidationError => e
      return selector_rejection(e.message, "provision_or_binding")
    end
    { outcome: "unexpected", stage: "provision_or_binding", detail: "模板化 selector 未被拒绝" }
  rescue ValidationError => e
    unexpected_rejection(e.message, "provision_or_binding", "负例 A 未取得判定结果")
  end

  # 负例 B：槽位值解析后含分隔符与 dot segment，期望运行期在调用 provider 之前
  # 返回 NYXID_OPERATION_PATH_PARAMETER_INVALID。
  def probe_slot_escape_rejected
    yaml_text = format(SLOT_ESCAPE_YAML_TEMPLATE, service_id: @options.fetch(:lark_service_id))
    display_name = "准入负例探针 34c-#{Digest::SHA256.hexdigest(yaml_text)[0, 10]}-#{@options.fetch(:probe_nonce)}"
    begin
      preview_response = preview(yaml_text, display_name)
    rescue ValidationError => e
      return admission_rejection(e, "preview")
    end
    return admission_rejection_from_body(preview_response, "preview") if preview_response["code"]

    begin
      member_id, revision_id = provision_and_bind(yaml_text, preview_response, display_name)
    rescue ValidationError => e
      return admission_rejection(e, "provision_or_binding")
    end

    run_detail = invoke_and_wait(member_id, revision_id, "run")
    status = run_detail.dig("summary", "status")
    failing_step = Array(run_detail["steps"]).find { |step| !step["error"].to_s.empty? }
    error_text = failing_step&.fetch("error", nil).to_s
    # provider 侧错误码出现即说明请求已经发出，越界值没有被本地拦截。
    reached_provider = error_text.match?(/NYXID_PROXY_HTTP_/)
    confined = status == "failed" &&
      error_text.match?(/NYXID_OPERATION_PATH_PARAMETER_INVALID|NYXID_OPERATION_PATH_TEMPLATE_INVALID/) &&
      !reached_provider
    {
      outcome: confined ? "fail_closed_confirmed" : "unexpected",
      stage: "run",
      terminalStatus: status,
      providerReached: reached_provider,
      stableErrorCode: stable_error_code(error_text),
      sanitizedError: sanitize_probe_error(error_text)
    }
  rescue ValidationError => e
    unexpected_rejection(e.message, "run", "负例 B 未取得终态")
  end

  # selector 契约的拒绝文案不含稳定错误码家族的关键词，需独立判定，
  # 避免被 admission_rejection 的通用匹配记成 unexpected。
  def selector_rejection(message, stage)
    # 内联表达式的 path_template 无法匹配任何已连接的精确 operation，因此平台在
    # explicit-request preview 就以 NYXID_OPERATION_SELECTION_REQUIRED 拒绝——这与
    # 契约文案类拒绝（NYXID_REQUEST_CONTRACT_INVALID / "must be static"）等价，
    # 都证明 selector 必须逐字静态，两类都记为 fail-closed。
    confirmed = message.match?(
      /NYXID_REQUEST_CONTRACT_INVALID|NYXID_OPERATION_SELECTION_REQUIRED|path_template|must be static|static relative path/i
    )
    {
      outcome: confirmed ? "fail_closed_confirmed" : "unexpected",
      stage: stage,
      stableErrorCode: stable_error_code(message),
      sanitizedError: sanitize_probe_error(message)
    }
  end

  def unexpected_rejection(message, stage, detail)
    {
      outcome: "unexpected",
      stage: stage,
      detail: detail,
      stableErrorCode: stable_error_code(message),
      sanitizedError: sanitize_probe_error(message)
    }
  end

  def probe_n8n_export
    display_name = "准入负例探针 35-#{Digest::SHA256.hexdigest(N8N_EXPORT_JSON)[0, 10]}-#{@options.fetch(:probe_nonce)}"
    begin
      preview_response = preview(N8N_EXPORT_JSON, display_name)
    rescue ValidationError => e
      return admission_rejection(e, "preview")
    end
    if preview_response["code"]
      admission_rejection_from_body(preview_response, "preview")
    else
      { outcome: "unexpected", stage: "preview", detail: "n8n 导出未被拒绝",
        previewCallSiteCount: Array(preview_response["items"]).length }
    end
  end

  def probe_durable_write
    yaml_text = format(
      DURABLE_WRITE_YAML_TEMPLATE,
      service_id: @options.fetch(:lark_service_id),
      app_token: @options.fetch(:base_app_token),
      table_id: @options.fetch(:asset_table_id)
    )
    display_name = "准入负例探针 36-#{Digest::SHA256.hexdigest(yaml_text)[0, 10]}-#{@options.fetch(:probe_nonce)}"
    begin
      preview_response = preview(yaml_text, display_name, execution_mode: "durable")
    rescue ValidationError => e
      return admission_rejection(e, "preview")
    end
    return admission_rejection_from_body(preview_response, "preview") if preview_response["code"]
    durable_admitted = Array(preview_response["items"]).any? do |item|
      Array(item["allowedExecutionModes"]).include?("durable")
    end
    if durable_admitted
      { outcome: "unexpected", stage: "preview", detail: "durable 写准入未 fail-closed" }
    else
      {
        outcome: "fail_closed_confirmed",
        stage: "preview_execution_modes",
        allowedExecutionModes: Array(preview_response["items"]).flat_map { |item| Array(item["allowedExecutionModes"]) }.uniq
      }
    end
  end

  def provision_and_bind(yaml_text, preview_response, display_name)
    confirmations = Array(preview_response["items"]).map do |item|
      {
        callSiteId: item.fetch("callSiteId"),
        requestContractDigest: item.fetch("requestContractDigest"),
        attestedRisk: item.fetch("effectiveRisk"),
        workflowId: "",
        revisionId: ""
      }
    end
    provision = @client.request_json(
      @client.scope_path("/provision-workflow"),
      method: "POST",
      body: {
        displayName: display_name,
        teamId: @options.fetch(:team_id),
        workflowYaml: yaml_text,
        runImmediately: false,
        caller: {
          platform: "nyxid",
          externalUserId: @options.fetch(:scope_id),
          scope: "proxy"
        },
        explicitRequestConfirmations: confirmations
      }
    )
    raise ValidationError, provision["message"] if provision["code"]

    member_id = provision.fetch("memberId")
    binding_run_id = provision.fetch("bindingRunId")
    deadline = Time.now + @options.fetch(:timeout)
    loop do
      begin
        response = @client.request_json(
          @client.scope_path(
            "/members/#{URI.encode_www_form_component(member_id)}/binding-runs/#{URI.encode_www_form_component(binding_run_id)}"
          )
        )
      rescue ValidationError => e
        # 绑定投影有延迟时该端点会短暂 404，重试而不是记成准入拒绝证据。
        raise unless e.message.include?("STUDIO_MEMBER_BINDING_RUN_NOT_FOUND")
        raise ValidationError, "等待绑定投影超时" if Time.now >= deadline
        sleep 2
        next
      end
      if response["status"] == "succeeded"
        return [member_id, response.dig("result", "revisionId")]
      end
      raise ValidationError, "绑定失败：#{response.dig("failure", "message") || response["status"]}" if response["status"] == "failed"
      raise ValidationError, "等待绑定超时" if Time.now >= deadline
      sleep 2
    end
  end

  def invoke_and_wait(member_id, revision_id, prompt)
    run_id = nil
    path = @client.scope_path(
      "/members/#{URI.encode_www_form_component(member_id)}/invoke/chat:stream"
    )
    @client.request_stream(path, { prompt: prompt, revisionId: revision_id }) do |line|
      next unless line.start_with?("data: ")

      begin
        event = JSON.parse(line.delete_prefix("data: "))
        custom = event["custom"]
        run_id = custom.dig("payload", "actorId") if custom && custom["name"] == "aevatar.run.context"
      rescue JSON::ParserError
        nil
      end
    end
    raise ValidationError, "运行未返回 run ID" unless run_id

    deadline = Time.now + @options.fetch(:timeout)
    loop do
      detail = @client.request_json(
        "/api/workflow/observatory/runs/#{URI.encode_www_form_component(run_id)}"
      )
      status = detail.dig("summary", "status")
      return detail if TERMINAL_STATUSES.include?(status)
      raise ValidationError, "等待运行终态超时，当前状态：#{status}" if Time.now >= deadline
      sleep 2
    end
  end
end

if __FILE__ == $PROGRAM_NAME
  options = {
    scope_id: ENV["AEVATAR_SCOPE_ID"],
    team_id: ENV["AEVATAR_TEAM_ID"],
    lark_service_id: ENV["LARK_USER_SERVICE_ID"],
    base_app_token: ENV["ACCEPTANCE_BASE_APP_TOKEN"],
    asset_table_id: ENV["ACCEPTANCE_ASSET_TABLE_ID"],
    timeout: 300,
    # 每轮探针使用新 nonce，保证 33/34 的 member 与绑定都是全新的，
    # 证据反映当轮准入行为而非复用上一轮已成功绑定的 member。
    probe_nonce: Time.now.utc.strftime("%Y%m%d%H%M%S")
  }
  OptionParser.new do |parser|
    parser.banner = "用法：ruby scripts/run_admission_probes.rb [选项]"
    parser.on("--scope-id ID") { |value| options[:scope_id] = value }
    parser.on("--team-id ID") { |value| options[:team_id] = value }
    parser.on("--lark-user-service-id ID") { |value| options[:lark_service_id] = value }
    parser.on("--base-app-token TOKEN") { |value| options[:base_app_token] = value }
    parser.on("--asset-table-id ID") { |value| options[:asset_table_id] = value }
    parser.on("--timeout SECONDS", Integer) { |value| options[:timeout] = value }
  end.parse!

  %i[scope_id team_id lark_service_id base_app_token asset_table_id].each do |key|
    abort "缺少 #{key}" if options[key].to_s.strip.empty?
  end

  AdmissionProbeRunner.new(options).run
end
