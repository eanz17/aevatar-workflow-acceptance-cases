#!/usr/bin/env ruby

require "set"
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
  "11-complex-codex-exec-validation.workflow.yaml" => [32, 0, 0, 0]
}.freeze

CODEX_EXEC_WORKFLOW = "11-complex-codex-exec-validation.workflow.yaml"
CODEX_EXEC_ARGUMENTS = {
  "target" => { "kind" => "managed_sandbox" },
  "workspace" => { "kind" => "empty_git" },
  "prompt" => "Reply with exactly CODEX_EXEC_READY",
  "timeout_secs" => 180
}.freeze
CODEX_EXEC_CHECK_NAMES = %w[status target output exit_code diagnostic_id].freeze

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
  fail_validation("#{name}：不得依赖线上未授权的通用 code_execute") unless generic_code_steps.empty?
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

unused = ALLOWED_PLACEHOLDERS - all_placeholders
fail_validation("存在未使用的已声明占位符：#{unused.to_a.join(', ')}") unless unused.empty?

puts "通过 工作流总数=#{files.length} 占位符总数=#{all_placeholders.length}"
