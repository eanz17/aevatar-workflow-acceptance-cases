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
  "20-supplier-risk-tier-aggregation.workflow.yaml" => [13, 0, 0, 0],
  "21-approval-window-integrity-audit.workflow.yaml" => [7, 2, 2, 0],
  "22-acceptance-fixture-drift-attestation.workflow.yaml" => [8, 4, 4, 0],
  "23-readonly-attested-post-probe.workflow.yaml" => [4, 1, 0, 1],
  "24-runtime-tool-approval-write-probe.workflow.yaml" => [5, 1, 0, 1],
  "25-sequential-tool-approval-write-probe.workflow.yaml" => [8, 2, 0, 2],
  "26-vendor-policy-inline-delegation.workflow.yaml" => [6, 0, 0, 0],
  "27-deterministic-parallel-evidence-review.workflow.yaml" => [12, 0, 0, 0],
  "28-deterministic-race-policy-review.workflow.yaml" => [3, 0, 0, 0],
  "29-invoice-approval-routing-preview.workflow.yaml" => [10, 2, 1, 1]
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
INLINE_DELEGATION_WORKFLOW = "26-vendor-policy-inline-delegation.workflow.yaml"
INLINE_DELEGATION_CHILD = File.join(
  ROOT,
  "fixtures",
  "inline-workflows",
  "vendor-policy-inline-evaluator.workflow.yaml"
)
DETERMINISTIC_PARALLEL_WORKFLOW = "27-deterministic-parallel-evidence-review.workflow.yaml"
DETERMINISTIC_RACE_WORKFLOW = "28-deterministic-race-policy-review.workflow.yaml"
INVOICE_ROUTING_PREVIEW_WORKFLOW = "29-invoice-approval-routing-preview.workflow.yaml"

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
    canonical_variants = {
      113 => "ac83c56b0d1f200c9299e74effb5d570f3921f5cc0dec1be0dc057e74d73e671",
      LARK_BOT_FILE_BYTES => LARK_BOT_FILE_SHA256,
      115 => "26daf820a262a8ae5c96998337d6df26dd0c248e43cb044f819ce75ff17a3d6c"
    }
    receipt_ok = canonical_variants.all? do |bytes, sha256|
                   receipt_template.include?("extracted_chars == #{bytes}") &&
                     receipt_template.include?("file_size == #{bytes}") &&
                     receipt_template.include?(sha256)
                 end &&
                 receipt_template.include?("expected_payload") &&
                 receipt_template.include?("text_contract_matches") &&
                 receipt_template.include?("sha256_matches") &&
                 receipt_template.include?("source_message_id != ''") &&
                 receipt_template.include?("source_resource_key != ''") &&
                 receipt_template.include?("lark_bot_ingress_validated:") &&
                 receipt_template.include?("identifiers_redacted: true") &&
                 receipt_template.include?("side_effects: false")
    fail_validation("#{name}：文件内容、Lark ingress 或脱敏断言不完整") unless receipt_ok
  end
  if name == "20-supplier-risk-tier-aggregation.workflow.yaml"
    steps_by_id = steps.to_h { |step| [step.fetch("id"), step] }
    cache_keys = %w[cache_probe_primary cache_probe_repeat].map do |step_id|
      steps_by_id.fetch(step_id).dig("parameters", "cache_key").to_s
    end
    # cache 模块状态跨 run 存活到重新绑定；固定 key 会让 TTL 内的重跑连 primary 也命中，
    # miss -> 派发子步骤 -> 回填这条路径不执行，断言却仍为真（假通过）。
    unless cache_keys.uniq.length == 1 &&
           cache_keys.first.include?("${steps.normalize_probe_context.json.probe_nonce}")
      fail_validation("#{name}：两个 cache 步骤必须共用同一个带 run 级 nonce 的 cache_key，否则 miss 分支会被 TTL 内的重跑跳过")
    end

    guard_template = steps_by_id.fetch("normalize_probe_context").fetch("template").to_s
    unless guard_template.match?(/probe_nonce\.size < 8 \|\| probe_nonce\.size > 14/) &&
           guard_template.include?("stamp = number(probe_nonce)")
      fail_validation("#{name}：probe_nonce 必须做 number() 数值守卫与长度校验")
    end
  end
  if name == "21-approval-window-integrity-audit.workflow.yaml"
    steps_by_id = steps.to_h { |step| [step.fetch("id"), step] }
    legacy_arguments = JSON.parse(steps_by_id.fetch("list_legacy_window").dig("parameters", "arguments"))
    active_arguments = JSON.parse(steps_by_id.fetch("list_active_window").dig("parameters", "arguments"))
    windows_ok = legacy_arguments.dig("query", "start_time") == "1754238719855" &&
                 legacy_arguments.dig("query", "end_time") == "1785774719855" &&
                 active_arguments.dig("query", "start_time") == "1754238719855" &&
                 active_arguments.dig("query", "end_time") == "1817310719855" &&
                 [legacy_arguments, active_arguments].all? { |args| args.dig("query", "page_size") == "100" }
    fail_validation("#{name}：审批窗口常量漂移（legacy 窗口必须保持案例 03/09 原值，active 窗口 2027-08 前有效）") unless windows_ok

    verify_template = steps_by_id.fetch("verify_window_integrity").fetch("template")
    unless verify_template.include?("legacy_window_expired") &&
           verify_template.include?("active_window_covers_now") &&
           verify_template.include?("side_effects: false")
      fail_validation("#{name}：缺少窗口过期与无副作用断言")
    end
  end
  if name == "22-acceptance-fixture-drift-attestation.workflow.yaml"
    read_targets = capabilities.map { |capability| capability.fetch("path_template") }
    unless read_targets.all? { |path| path.start_with?("/open-apis/bitable/v1/apps/") } && methods.uniq == ["GET"]
      fail_validation("#{name}：fixture 体检必须保持只读 Base GET")
    end
    verify_template = steps.find { |step| step["id"] == "verify_attestation" }&.fetch("template")
    unless verify_template.to_s.include?("fixtures_intact") &&
           verify_template.to_s.include?("reads_completed") &&
           verify_template.to_s.include?("side_effects: false")
      fail_validation("#{name}：缺少 fixture 完整性与无副作用断言")
    end
  end
  if name == "23-readonly-attested-post-probe.workflow.yaml"
    steps_by_id = steps.to_h { |step| [step.fetch("id"), step] }
    probe = steps_by_id.fetch("search_with_attested_risk")
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
      "response_mode" => "text",
      "risk" => "read_only"
    } && arguments.dig("query", "page_size") == "2" &&
         arguments["body"] == { "automatic_fields" => false }
    fail_validation("#{name}：read_only 声明 POST 探针契约漂移") unless contract_ok

    verify_template = steps_by_id.fetch("verify_attested_probe").fetch("template")
    unless verify_template.include?("attested_readonly_executed == true") &&
           verify_template.include?("side_effects == false")
      fail_validation("#{name}：缺少 read_only 执行与无副作用断言")
    end
  end
  if %w[24-runtime-tool-approval-write-probe.workflow.yaml 25-sequential-tool-approval-write-probe.workflow.yaml].include?(name)
    marker = name.start_with?("24-") ? "runtime-approval-probe-" : "sequential-approval-probe-"
    write_steps = steps.select { |step| step.dig("capability", "nyxid_request", "method") == "POST" }
    write_steps.each do |step|
      arguments = step.dig("parameters", "arguments").to_s
      unless arguments.include?("__TABLE_ASSET_ATTESTATIONS__") &&
             arguments.include?(marker) &&
             arguments.include?('"Status":"Probe"')
        fail_validation("#{name}：写入探针必须只写资产盘点表并携带可清理的探针标记")
      end
      if step.dig("capability", "nyxid_request", "risk")
        fail_validation("#{name}：运行时审批探针不得声明 risk，必须保持未声明风险的 write 语义")
      end
    end
    verify_step = steps.find { |step| step["id"].to_s.start_with?("verify_") }
    unless verify_step&.fetch("template", nil).to_s.include?("side_effects: true")
      fail_validation("#{name}：写入探针必须如实声明 side_effects: true")
    end

    # probe_note 会被引擎逐字替换进 tool_call 的 arguments JSON 字符串。
    # bounded 模板只提供 append/data/date/get/number/json/keys/round，没有 string.* 函数，
    # 因此用 number() 做守卫：它对任何非数值字符串抛错，而可解析字符集不含引号、反斜杠或花括号，
    # 从而封死注入面；再叠加长度与正整数下界，排除括号负数与短指数写法。
    guard_template = steps.find { |step| step["id"] == "normalize_context" }&.fetch("template", nil).to_s
    unless guard_template.match?(/probe_note\.size < 8 \|\| probe_note\.size > 14/) &&
           guard_template.include?("stamp = number(probe_note)") &&
           guard_template.include?("stamp < 10000000")
      fail_validation("#{name}：probe_note 必须做 number() 数值守卫与长度、下界校验，防止注入 tool arguments")
    end
  end
  if name == INLINE_DELEGATION_WORKFLOW
    call = steps.find { |step| step["id"] == "delegate_policy_check" }
    unless call&.fetch("type", nil) == "workflow_call" && call.fetch("parameters") == {
      "workflow" => "vendor_policy_inline_evaluator",
      "lifecycle" => "transient"
    }
      fail_validation("#{name}：必须通过 transient workflow_call 调用固定 inline 子定义")
    end

    fail_validation("#{name}：缺少 inline 子工作流 fixture") unless File.file?(INLINE_DELEGATION_CHILD)
    child = YAML.safe_load(File.read(INLINE_DELEGATION_CHILD), aliases: false)
    child_steps = child.fetch("steps")
    child_contract_ok = child["name"] == "vendor_policy_inline_evaluator" &&
                        child_steps.length == 1 &&
                        child_steps.first == {
                          "id" => "return_policy_decision",
                          "type" => "assign",
                          "parameters" => {
                            "target" => "policy_decision",
                            "value" => "INLINE_POLICY_APPROVED"
                          }
                        }
    fail_validation("#{name}：inline 子工作流必须保持固定、无副作用、可机器判断") unless child_contract_ok

    success_result = JSON.parse(steps.find { |step| step["id"] == "delegated" }.dig("parameters", "value"))
    unless success_result == {
      "case" => "vendor_policy_inline_delegation",
      "success" => true,
      "inline_definition_bound" => true,
      "child_definition_resolved" => true,
      "child_workflow_completed" => true,
      "side_effects" => false
    }
      fail_validation("#{name}：inline delegation 成功 artifact 漂移")
    end
  end
  if name == DETERMINISTIC_PARALLEL_WORKFLOW
    fanout = steps.find { |step| step["id"] == "fanout_evidence" }
    expected_parameters = {
      "parallel_count" => "3",
      "sub_step_type" => "assign",
      "sub_param_target" => "evidence_${index}",
      "sub_param_value" => "evidence-${index}",
      "min_concurrent_workers" => "3",
      "max_concurrent_workers" => "3"
    }
    unless fanout&.fetch("type", nil) == "parallel" && fanout.fetch("parameters") == expected_parameters
      fail_validation("#{name}：parallel 必须固定为三路 deterministic assign worker")
    end

    first_gate = steps.find { |step| step["id"] == "verify_first_evidence" }
    last_gate = steps.find { |step| step["id"] == "verify_last_evidence" }
    count_gate = steps.find { |step| step["id"] == "verify_merged_shape" }
    order_contract_ok = first_gate&.fetch("branches", nil) == {
      "evidence-0" => "restore_merged_for_last",
      "_default" => "parallel_failed"
    } && last_gate&.fetch("branches", nil) == {
      "evidence-2" => "restore_merged_for_count",
      "_default" => "parallel_failed"
    } && count_gate&.fetch("branches", nil) == {
      "5" => "parallel_verified",
      "_default" => "parallel_failed"
    }
    fail_validation("#{name}：缺少 dispatch index 顺序和三路合并形状断言") unless order_contract_ok
  end
  if name == DETERMINISTIC_RACE_WORKFLOW
    race = steps.find { |step| step["id"] == "first_successful_review" }
    unless race&.fetch("type", nil) == "race" && race.fetch("parameters") == {
      "count" => "3",
      "sub_step_type" => "assign",
      "sub_param_target" => "candidate_${index}",
      "sub_param_value" => '"candidate-${index}"'
    }
      fail_validation("#{name}：race 必须固定为三路 deterministic assign worker")
    end

    verification = steps.find { |step| step["id"] == "verify_race_result" }&.fetch("template", nil).to_s
    unless %w[candidate-0 candidate-1 candidate-2 first_success_selected later_completions_ignored].all? do |token|
      verification.include?(token)
    end
      fail_validation("#{name}：race 缺少 winner 集合、首成功与后续完成忽略断言")
    end
  end
  if name == INVOICE_ROUTING_PREVIEW_WORKFLOW
    steps_by_id = steps.to_h { |step| [step.fetch("id"), step] }
    extraction = steps_by_id.fetch("extract_document").fetch("parameters")
    unless extraction == {
      "items_source" => "input_file_refs",
      "sub_step_type" => "tool_call",
      "sub_param_tool" => "document_extract",
      "sub_param_arguments" => '{"maxChars":6000}',
      "min_concurrent_workers" => "1",
      "max_concurrent_workers" => "1"
    }
      fail_validation("#{name}：必须从单个类型化 file ref 调用固定 document_extract")
    end

    history = steps_by_id.fetch("list_approval_history")
    history_capability = history.dig("capability", "nyxid_request")
    history_arguments = JSON.parse(history.dig("parameters", "arguments"))
    history_contract_ok = history_capability == {
      "user_service_id" => "__LARK_USER_SERVICE_ID__",
      "method" => "GET",
      "path_template" => "/open-apis/approval/v4/instances",
      "query_parameters" => %w[approval_code page_size start_time end_time],
      "header_parameters" => [],
      "body_mode" => "none",
      "body_required" => false,
      "response_mode" => "text"
    } && history_arguments == {
      "query" => {
        "approval_code" => "__LARK_APPROVAL_CODE__",
        "page_size" => "100",
        "start_time" => "1785772800000",
        "end_time" => "1785859199000"
      }
    }
    fail_validation("#{name}：审批历史必须保持固定百条只读窗口") unless history_contract_ok

    contact = steps_by_id.fetch("resolve_approval_route")
    contact_capability = contact.dig("capability", "nyxid_request")
    contact_arguments = JSON.parse(contact.dig("parameters", "arguments"))
    contact_contract_ok = contact_capability == {
      "user_service_id" => "__LARK_USER_SERVICE_ID__",
      "method" => "POST",
      "path_template" => "/open-apis/contact/v3/users/batch_get_id",
      "query_parameters" => ["user_id_type"],
      "header_parameters" => [],
      "body_mode" => "json",
      "body_required" => true,
      "response_mode" => "text",
      "risk" => "read_only"
    } && contact_arguments == {
      "query" => { "user_id_type" => "user_id" },
      "body" => { "emails" => ["__LARK_CONTACT_EMAIL__"] }
    }
    fail_validation("#{name}：审批路由必须使用脱敏的 batch_get_id 只读契约") unless contact_contract_ok

    result_template = steps_by_id.fetch("evaluate_preview").fetch("template")
    required_result_tokens = %w[
      execution_mode exact_duplicate_found same_vendor_history_verified approval_route_resolved
      identifiers_redacted approval_created message_sent external_writes side_effects
    ]
    unless required_result_tokens.all? { |token| result_template.include?(token) } &&
           result_template.include?("approval_created: false") &&
           result_template.include?("message_sent: false") &&
           result_template.include?("external_writes: false") &&
           result_template.include?("side_effects: false")
      fail_validation("#{name}：no-submit typed artifact 契约不完整")
    end
    forbidden_paths = capabilities.map { |capability| capability.fetch("path_template") }.grep(
      %r{/open-apis/approval/v4/instances/\{?[^/]*\}?$}
    )
    fail_validation("#{name}：预览定义不得包含审批创建 call site") unless forbidden_paths.empty?
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
