#!/usr/bin/env ruby

require "set"
require "digest"
require "json"
require "yaml"

ROOT = File.expand_path("..", __dir__)
WORKFLOW_DIR = File.join(ROOT, "workflows")

EXPECTED = {
  "01-release-readiness-review.workflow.yaml" => [13, 0, 0, 0],
  "02-candidate-document-compliance-preview.workflow.yaml" => [3, 0, 0, 0],
  "03-email-access-approval-audit.workflow.yaml" => [5, 2, 2, 0],
  "04-saas-license-utilization-review.workflow.yaml" => [10, 6, 6, 0],
  "05-asset-inventory-attestation.workflow.yaml" => [7, 1, 0, 1],
  "06-project-shared-mailbox-approval.workflow.yaml" => [8, 3, 2, 1],
  "07-quarterly-access-review-reminder.workflow.yaml" => [7, 1, 0, 1],
  "08-saas-license-optimization-digest.workflow.yaml" => [19, 7, 6, 1],
  "09-contractor-access-package-approval.workflow.yaml" => [25, 5, 4, 1],
  "10-monthly-access-certification.workflow.yaml" => [23, 5, 2, 3],
  "11-complex-codex-exec-validation.workflow.yaml" => [32, 0, 0, 0],
  "12-safe-code-execute-validation.workflow.yaml" => [4, 0, 0, 0],
  "13-invoice-ocr-policy-review.workflow.yaml" => [10, 2, 2, 0],
  "14-lark-contact-batch-resolution.workflow.yaml" => [3, 1, 0, 1],
  "15-weekly-budget-variance-digest.workflow.yaml" => [11, 6, 6, 0],
  "16-nyxid-read-receipt-probe.workflow.yaml" => [4, 1, 1, 0],
  "17-lark-post-search-approval-probe.workflow.yaml" => [4, 1, 0, 1],
  "18-supplier-control-attestation-review.workflow.yaml" => [15, 0, 0, 0],
  "19-lark-bot-file-upload-validation.workflow.yaml" => [3, 0, 0, 0],
  "20-supplier-risk-tier-aggregation.workflow.yaml" => [12, 0, 0, 0]
}.freeze

CODEX_EXEC_WORKFLOW = "11-complex-codex-exec-validation.workflow.yaml"
CODEX_EXEC_ARGUMENTS = {
  "target" => { "kind" => "managed_sandbox" },
  "workspace" => { "kind" => "empty_git" },
  "prompt" => "Reply with exactly CODEX_EXEC_READY",
  "timeout_secs" => 180
}.freeze
CODEX_EXEC_CHECK_NAMES = %w[status target output exit_code diagnostic_id].freeze
CODE_EXECUTE_WORKFLOW = "12-safe-code-execute-validation.workflow.yaml"
CODE_EXECUTE_ARGUMENTS = {
  "language" => "javascript",
  "code" => "const grossCents=15250;const taxCents=1373;const totalCents=grossCents+taxCents;console.log(JSON.stringify({case:\"safe_code_execute_validation\",gross_cents:grossCents,tax_cents:taxCents,total_cents:totalCents,feature_ok:totalCents===16623,side_effects:false}));"
}.freeze
INVOICE_WORKFLOW = "13-invoice-ocr-policy-review.workflow.yaml"
CONTACT_WORKFLOW = "14-lark-contact-batch-resolution.workflow.yaml"
BUDGET_WORKFLOW = "15-weekly-budget-variance-digest.workflow.yaml"
NYXID_RECEIPT_WORKFLOW = "16-nyxid-read-receipt-probe.workflow.yaml"
POST_APPROVAL_WORKFLOW = "17-lark-post-search-approval-probe.workflow.yaml"
LARK_BOT_FILE_WORKFLOW = "19-lark-bot-file-upload-validation.workflow.yaml"
LARK_BOT_FILE_NAME = "lark-bot-upload-manifest.json"
LARK_BOT_FILE_BYTES = 114
LARK_BOT_FILE_SHA256 = "5a3cdce7117c7ef1e07ad02d9621b701d300974806da142e579415fb70cb61fb"

ALLOWED_PLACEHOLDERS = Set.new(
  YAML.safe_load(File.read(File.join(ROOT, "config.example.yaml")), aliases: false)
      .fetch("replacements").keys
).freeze

def fail_validation(message)
  warn "验证失败：#{message}"
  exit 1
end

files = Dir[File.join(WORKFLOW_DIR, "*.workflow.yaml")].sort
actual_names = files.map { |file| File.basename(file) }
fail_validation("工作流文件集合与预期不一致") unless actual_names == EXPECTED.keys

all_placeholders = Set.new

files.each do |file|
  name = File.basename(file)
  text = File.read(file)
  document = YAML.safe_load(text, aliases: false)
  steps = document.fetch("steps")
  ids = steps.map { |step| step.fetch("id") }
  fail_validation("#{name} 存在重复的步骤 ID") unless ids.uniq.length == ids.length

  references = []
  steps.each do |step|
    references << [step.fetch("id"), step["next"]] if step["next"]
    next unless step["branches"].is_a?(Hash)

    step.fetch("branches", {}).each_value do |target|
      references << [step.fetch("id"), target]
    end
  end
  references.each do |source, target|
    fail_validation("#{name}：#{source} 引用了不存在的步骤 #{target}") unless ids.include?(target)
  end

  steps.each do |step|
    template = step["template"] || step.dig("parameters", "template")
    next unless template

    if template.match?(/\belse\s+if\b.*?\bend\s*;\s*end\b/m)
      fail_validation("#{name}：#{step.fetch('id')} 的 Scriban else if 分支多写了 end")
    end
  end

  capabilities = steps.map { |step| step.dig("capability", "nyxid_request") }.compact
  methods = capabilities.map { |capability| capability.fetch("method").upcase }
  expected_steps, expected_external, expected_get, expected_post = EXPECTED.fetch(name)
  actual = [steps.length, capabilities.length, methods.count("GET"), methods.count("POST")]
  expected = [expected_steps, expected_external, expected_get, expected_post]
  fail_validation("#{name}：预期统计 #{expected.inspect}，实际为 #{actual.inspect}") unless actual == expected

  codex_steps = steps.select { |step| step.dig("parameters", "tool") == "codex_exec" }
  generic_code_steps = steps.select { |step| step.dig("parameters", "tool") == "code_execute" }
  expected_code_count = name == CODE_EXECUTE_WORKFLOW ? 1 : 0
  fail_validation("#{name}：code_execute 调用数应为 #{expected_code_count}") unless generic_code_steps.length == expected_code_count
  if name == CODE_EXECUTE_WORKFLOW
    begin
      arguments = JSON.parse(generic_code_steps.first.dig("parameters", "arguments"))
    rescue JSON::ParserError => e
      fail_validation("#{name}：code_execute 参数不是有效 JSON：#{e.message}")
    end
    fail_validation("#{name}：code_execute 必须保持固定、无副作用的结算探针") unless arguments == CODE_EXECUTE_ARGUMENTS

    receipt_step = steps.find { |step| step["id"] == "verify_receipt" }
    template = receipt_step&.fetch("template", receipt_step&.dig("parameters", "template"))
    unless template.to_s.include?("total_cents == 16623") && template.to_s.include?("side_effects: false")
      fail_validation("#{name}：结算 receipt 缺少金额与无副作用断言")
    end
  end
  if %w[05-asset-inventory-attestation.workflow.yaml 07-quarterly-access-review-reminder.workflow.yaml].include?(name)
    extract_mode = steps.find { |step| step["id"] == "extract_mode" }
    unless extract_mode&.dig("parameters", "op") == "json_extract" &&
           extract_mode.dig("parameters", "path") == "route"
      fail_validation("#{name}：原生输入路由必须直接提取 normalize_context.route")
    end
  end
  if name == "09-contractor-access-package-approval.workflow.yaml"
    steps_by_id = steps.to_h { |step| [step.fetch("id"), step] }
    history_arguments = JSON.parse(steps_by_id.fetch("list_approval_history").dig("parameters", "arguments"))
    extracted_history = steps_by_id.fetch("extract_history_codes").fetch("parameters")
    expected_window = {
      "page_size" => "100",
      "start_time" => "1785772800000",
      "end_time" => "1785859199000"
    }
    unless expected_window.all? { |key, value| history_arguments.dig("query", key) == value } &&
           extracted_history["n"] == "100"
      fail_validation("#{name}：稳定键去重必须检查验收日内完整的百条历史窗口")
    end
  end
  if name == INVOICE_WORKFLOW
    steps_by_id = steps.to_h { |step| [step.fetch("id"), step] }
    extraction = steps_by_id.fetch("extract_document").fetch("parameters")
    unless extraction["items_source"] == "input_file_refs" &&
           extraction["sub_param_tool"] == "document_extract"
      fail_validation("#{name}：必须从类型化媒体输入调用 document_extract")
    end
    unless text.include?("amount_minor == 123450") &&
           text.include?("currency == 'SGD'") &&
           text.include?("vendor_key == 'harbor-cloud'") &&
           text.include?("exact_matches == 1") &&
           text.include?("vendor_matches == 2")
      fail_validation("#{name}：发票归一化或去重规则不完整")
    end
    fixture = File.join(ROOT, "fixtures", "synthetic-invoice.pdf")
    fail_validation("#{name}：缺少合成 PDF fixture") unless File.file?(fixture) && File.size(fixture).positive?
  end
  if name == CONTACT_WORKFLOW
    contact = steps.find { |step| step["id"] == "resolve_contact" }
    capability = contact&.dig("capability", "nyxid_request")
    arguments = JSON.parse(contact&.dig("parameters", "arguments").to_s)
    contract_ok = capability&.fetch("method") == "POST" &&
                  capability["path_template"] == "/open-apis/contact/v3/users/batch_get_id" &&
                  capability["body_mode"] == "json" &&
                  arguments.dig("query", "user_id_type") == "user_id" &&
                  arguments.dig("body", "emails") == ["__LARK_CONTACT_EMAIL__"]
    fail_validation("#{name}：contact batch_get_id 契约漂移") unless contract_ok
  end
  if name == BUDGET_WORKFLOW
    unless capabilities.length == 6 &&
           text.include?("data.weekly.actual == 2340") &&
           text.include?("monthly_projection.actual == 9360") &&
           text.include?("over_count == 1") &&
           text.include?("watch_count == 1")
      fail_validation("#{name}：预算周报/月报差异契约不完整")
    end
  end
  if name == NYXID_RECEIPT_WORKFLOW
    steps_by_id = steps.to_h { |step| [step.fetch("id"), step] }
    probe = steps_by_id.fetch("read_base_records")
    capability = probe.dig("capability", "nyxid_request")
    arguments = JSON.parse(probe.dig("parameters", "arguments"))
    contract_ok = capability == {
      "user_service_id" => "__LARK_USER_SERVICE_ID__",
      "method" => "GET",
      "path_template" => "/open-apis/bitable/v1/apps/{app_token}/tables/{table_id}/records",
      "query_parameters" => ["page_size"],
      "header_parameters" => [],
      "body_mode" => "none",
      "body_required" => false,
      "response_mode" => "text"
    } && arguments.dig("query", "page_size") == "1"
    fail_validation("#{name}：NyxID 只读 receipt 探针契约漂移") unless contract_ok

    receipt_template = steps_by_id.fetch("verify_receipt").fetch("template")
    unless receipt_template.include?("provider_response_verified == true") &&
           receipt_template.include?("side_effects == false")
      fail_validation("#{name}：缺少 provider receipt 与无副作用断言")
    end
  end
  if name == POST_APPROVAL_WORKFLOW
    steps_by_id = steps.to_h { |step| [step.fetch("id"), step] }
    probe = steps_by_id.fetch("search_base_records")
    capability = probe.dig("capability", "nyxid_request")
    arguments = JSON.parse(probe.dig("parameters", "arguments"))
    contract_ok = capability == {
      "user_service_id" => "__LARK_USER_SERVICE_ID__",
      "method" => "POST",
      "path_template" => "/open-apis/bitable/v1/apps/{app_token}/tables/{table_id}/records/search",
      "query_parameters" => ["page_size"],
      "header_parameters" => [],
      "body_mode" => "json",
      "body_required" => true,
      "response_mode" => "text"
    } && arguments.dig("query", "page_size") == "3" &&
         arguments["body"] == { "automatic_fields" => false }
    fail_validation("#{name}：Base POST search approval 探针契约漂移") unless contract_ok

    resume_template = steps_by_id.fetch("verify_approval_resume").fetch("template")
    unless resume_template.include?("approval_resumed == true") &&
           resume_template.include?("side_effects == false")
      fail_validation("#{name}：缺少 approval resume 与无副作用断言")
    end
  end
  if name == LARK_BOT_FILE_WORKFLOW
    steps_by_id = steps.to_h { |step| [step.fetch("id"), step] }
    extraction = steps_by_id.fetch("extract_uploaded_file").fetch("parameters")
    extraction_arguments = JSON.parse(extraction.fetch("sub_param_arguments"))
    unless extraction == {
      "items_source" => "input_file_refs",
      "sub_step_type" => "tool_call",
      "sub_param_tool" => "document_extract",
      "sub_param_arguments" => '{"maxChars":1000}',
      "min_concurrent_workers" => "1",
      "max_concurrent_workers" => "1"
    } && extraction_arguments == { "maxChars" => 1000 }
      fail_validation("#{name}：必须从单个类型化 file ref 精确调用一次 document_extract")
    end

    fixture = File.join(ROOT, "fixtures", LARK_BOT_FILE_NAME)
    fixture_ok = File.file?(fixture) &&
                 File.binread(fixture).bytesize == LARK_BOT_FILE_BYTES &&
                 Digest::SHA256.file(fixture).hexdigest == LARK_BOT_FILE_SHA256
    fail_validation("#{name}：Lark Bot 合成文件 fixture 契约漂移") unless fixture_ok

    receipt_template = steps_by_id.fetch("verify_file_contract").fetch("template")
    receipt_ok = receipt_template.include?("data.extracted_chars == #{LARK_BOT_FILE_BYTES}") &&
                 receipt_template.include?("get(file, 'size_bytes', 0) == #{LARK_BOT_FILE_BYTES}") &&
                 receipt_template.include?(LARK_BOT_FILE_SHA256) &&
                 receipt_template.include?("source_message_id != ''") &&
                 receipt_template.include?("source_resource_key != ''") &&
                 receipt_template.include?("lark_bot_ingress_validated:") &&
                 receipt_template.include?("identifiers_redacted: true") &&
                 receipt_template.include?("side_effects: false")
    fail_validation("#{name}：文件内容、Lark ingress 或脱敏断言不完整") unless receipt_ok
  end
  expected_codex_count = name == CODEX_EXEC_WORKFLOW ? 1 : 0
  fail_validation("#{name}：codex_exec 调用数应为 #{expected_codex_count}") unless codex_steps.length == expected_codex_count
  if name == CODEX_EXEC_WORKFLOW
    codex_step = codex_steps.first
    fail_validation("#{name}：codex_exec 步骤必须设置 360000ms 的工作流超时") unless codex_step["timeout_ms"] == 360_000

    begin
      arguments = JSON.parse(codex_step.dig("parameters", "arguments"))
    rescue JSON::ParserError => e
      fail_validation("#{name}：codex_exec 参数不是有效 JSON：#{e.message}")
    end
    fail_validation("#{name}：codex_exec 参数偏离固定 managed probe") unless arguments == CODEX_EXEC_ARGUMENTS

    steps_by_id = steps.to_h { |step| [step.fetch("id"), step] }
    check_names = JSON.parse(steps_by_id.fetch("seed_check_names").dig("parameters", "value"))
    fail_validation("#{name}：并行检查项必须精确覆盖五个 receipt 字段") unless check_names == CODEX_EXEC_CHECK_NAMES

    foreach_step = steps_by_id.fetch("normalize_check_names")
    foreach_parameters = foreach_step.fetch("parameters")
    expected_foreach = {
      "sub_step_type" => "transform",
      "sub_param_op" => "uppercase",
      "min_concurrent_workers" => "2",
      "max_concurrent_workers" => "5"
    }
    fail_validation("#{name}：五项检查必须保持并行 foreach 契约") unless foreach_step["type"] == "foreach" && foreach_parameters == expected_foreach

    count_step = steps_by_id.fetch("count_parallel_serialized_lines")
    fail_validation("#{name}：并行汇总必须按物理行计数") unless count_step["type"] == "transform" && count_step.dig("parameters", "op") == "count"

    count_gate = steps_by_id.fetch("verify_parallel_serialized_line_count")
    expected_branches = { "9" => "build_success_result", "_default" => "fail_parallel_summary" }
    fail_validation("#{name}：五个结果和四个分隔符必须精确断言为九行") unless count_gate.fetch("branches") == expected_branches

    success_result = JSON.parse(steps_by_id.fetch("build_success_result").dig("parameters", "value"))
    expected_checks = CODEX_EXEC_CHECK_NAMES.to_h { |check_name| [check_name, true] }
    success_contract_valid = success_result["success"] == true &&
                             success_result["output"] == "CODEX_EXEC_READY" &&
                             success_result["checks"] == expected_checks &&
                             success_result["parallel_check_count"] == 5 &&
                             success_result["side_effects"] == false
    fail_validation("#{name}：成功终态必须保留五项机器可判定证据") unless success_contract_valid
  end

  placeholders = Set.new(text.scan(/__[A-Z0-9_]+__/))
  unknown = placeholders - ALLOWED_PLACEHOLDERS
  fail_validation("#{name}：包含未声明占位符 #{unknown.to_a.join(', ')}") unless unknown.empty?
  all_placeholders.merge(placeholders)

  fail_validation("#{name}：包含字面 UUID") if text.match?(/\b[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}\b/i)
  fail_validation("#{name}：包含字面 Lark table 或 record ID") if text.match?(/\b(?:tbl|rec|vew)[A-Za-z0-9]{8,}\b/)
  fail_validation("#{name}：包含非 example 域名的 Lark 租户 URL") if text.match?(%r{https://(?!example\.larksuite\.com)[^/]*larksuite\.com})

  puts "通过 #{name} 步骤=#{steps.length} 外部调用=#{capabilities.length} GET=#{methods.count('GET')} POST=#{methods.count('POST')} codex_exec=#{codex_steps.length}"
end

schedule_path = File.join(ROOT, "schedules", "15-weekly-budget-variance-digest.schedule.example.yaml")
fail_validation("缺少案例 15 的 durable schedule 契约") unless File.file?(schedule_path)
schedule_text = File.read(schedule_path)
schedule = YAML.safe_load(schedule_text, aliases: false)
all_placeholders.merge(schedule_text.scan(/__[A-Z0-9_]+__/))
weekly, monthly = schedule.fetch("schedules")
schedule_ok = schedule["skill_name"] == "weekly-budget-variance-digest" &&
              schedule["endpoint_template"] == "/api/workflow/skills/{skill_guid}/schedule" &&
              schedule["team_id"] == "__STUDIO_TEAM_ID__" &&
              weekly["cron_expression"] == "0 9 * * 1" &&
              monthly["cron_expression"] == "0 9 1 * *" &&
              [weekly, monthly].all? { |item| item["timezone"] == "Asia/Singapore" }
fail_validation("案例 15 的 durable schedule 契约漂移") unless schedule_ok

unused = ALLOWED_PLACEHOLDERS - all_placeholders
fail_validation("存在未使用的已声明占位符：#{unused.to_a.join(', ')}") unless unused.empty?

puts "通过 工作流总数=#{files.length} 占位符总数=#{all_placeholders.length}"
