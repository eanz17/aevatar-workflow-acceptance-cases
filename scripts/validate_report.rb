#!/usr/bin/env ruby

require "json"
require "yaml"

ROOT = File.expand_path("..", __dir__)
EXPECTED_CASES = (1..11).map { |number| format("%02d", number) }.freeze

def fail_validation(message)
  warn "报告验证失败：#{message}"
  exit 1
end

summary_path = File.join(ROOT, "validation", "production-validation-2026-08-04.json")
summary = JSON.parse(File.read(summary_path))
runtime = summary.fetch("runtime")

fail_validation("静态验证摘要不是 11/11") unless summary.dig("staticValidation", "passed") == 11
fail_validation("production preview 摘要不是 11/11") unless summary.dig("productionPreview", "passed") == 11
fail_validation("production runtime 案例数不是 11") unless runtime.length == 11
fail_validation("production runtime 案例编号不完整") unless runtime.map { |item| item.fetch("case") } == EXPECTED_CASES

runtime.each do |item|
  case_id = item.fetch("case")
  fail_validation("案例 #{case_id} 未通过") unless item["result"] == "通过"
  fail_validation("案例 #{case_id} 不是 completed") unless item["terminalStatus"] == "completed"
  fail_validation("案例 #{case_id} 缺少 stateVersion") unless item["stateVersion"].is_a?(Integer)
  fail_validation("案例 #{case_id} 缺少机器断言") if item["assertion"].to_s.strip.empty?
end

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
html_case_ids = html.scan(/<tr data-effect="(?:none|write)"><td class="case-id">(\d{2})<\/td>/).flatten
fail_validation("分析页案例编号不完整") unless html_case_ids == EXPECTED_CASES

expected_html_counts = {
  "能力矩阵" => [/<tr data-family=/, 14],
  "真实证据" => [/<tr data-effect=/, 11],
  "能力缺口" => [/<div class="gap-row">/, 7],
  "修复记录" => [/<div class="repair-item">/, 6]
}
expected_html_counts.each do |label, (pattern, expected)|
  actual = html.scan(pattern).length
  fail_validation("分析页#{label}数量为 #{actual}，预期 #{expected}") unless actual == expected
end

report = File.read(File.join(ROOT, "report", "2026-08-04-workflow-coverage-report.md"))
fail_validation("文字报告缺少 43 个源定义口径") unless report.include?("源目录共有 43 个可解析工作流定义")
fail_validation("文字报告缺少 #3182 证据边界") unless report.include?("`#3182`")
fail_validation("分析页缺少路径口径") unless html.include?("~/Code/workflows") && html.include?("/Users/chronoai/workflows")

puts "通过 报告案例=11 能力矩阵=14 缺口=7 修复记录=6"
