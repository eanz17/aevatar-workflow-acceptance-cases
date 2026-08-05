#!/usr/bin/env ruby

require "json"
require "yaml"

ROOT = File.expand_path("..", __dir__)
EXPECTED_CASES = (1..17).map { |number| format("%02d", number) }.freeze
EXPECTED_BLOCKED = %w[12 14].freeze
EXPECTED_UNVERIFIED = %w[16 17].freeze
REPORT_DATE = "2026-08-05"

def fail_validation(message)
  warn "报告验证失败：#{message}"
  exit 1
end

summary_path = File.join(ROOT, "validation", "production-validation-#{REPORT_DATE}.json")
summary = JSON.parse(File.read(summary_path))
runtime = summary.fetch("runtime")

fail_validation("静态验证摘要不是 17/17") unless summary.dig("staticValidation", "passed") == 17
fail_validation("production preview 已验证数不是 15/17") unless summary.dig("productionPreview", "passed") == 15 &&
  summary.dig("productionPreview", "unverified") == 2
fail_validation("production runtime 案例数不是 17") unless runtime.length == 17
fail_validation("production runtime 案例编号不完整") unless runtime.map { |item| item.fetch("case") } == EXPECTED_CASES
fail_validation("直接 runtime 通过数不是 13") unless summary.dig("directRuntimeSummary", "passed") == 13
fail_validation("直接 runtime 平台阻塞数不是 2") unless summary.dig("directRuntimeSummary", "platformBlocked") == 2
fail_validation("直接 runtime 待验证数不是 2") unless summary.dig("directRuntimeSummary", "unverified") == 2

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
  else
    fail_validation("案例 #{case_id} 未通过") unless item["result"] == "通过"
    fail_validation("案例 #{case_id} 不是 completed") unless item["terminalStatus"] == "completed"
    fail_validation("案例 #{case_id} 缺少 stateVersion") unless item["stateVersion"].is_a?(Integer)
  end
end

ornn = summary.fetch("ornnPublication")
fail_validation("本地 Ornn skill 数不是 17") unless ornn.fetch("localSkillCount") == 17
%w[skillCount serverFormatValidated publishedPublic nameReadbackPassed].each do |field|
  fail_validation("Ornn #{field} 不是 15") unless ornn.fetch(field) == 15
end

assistant = summary.fetch("assistantNaturalLanguage")
fail_validation("/api/chat 案例数不是 5") unless assistant.fetch("cases") == 5
fail_validation("/api/chat completed 数不是 5") unless assistant.fetch("chatCompleted") == 5
fail_validation("/api/chat validated 数不是 3") unless assistant.fetch("workflowValidated") == 3
fail_validation("/api/chat typed failure 数不是 2") unless assistant.fetch("workflowTypedFailures") == 2
fail_validation("/api/chat 案例编号漂移") unless assistant.fetch("results").map { |item| item.fetch("case") } == %w[01 12 13 14 15]
fail_validation("/api/chat 未全部搜索 Ornn") unless assistant.fetch("results").all? { |item| item["ornnSearch"] == true }
fail_validation("/api/chat 未全部加载 skill") unless assistant.fetch("results").all? { |item| item["skillLoaded"] == true }
fail_validation("/api/chat 未全部启动 workflow") unless assistant.fetch("results").all? { |item| item["workflowStarted"] == true }

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
html_case_ids = html.scan(/<tr data-result="(?:passed|blocked|unverified)"[^>]*><td class="case-id">(\d{2})<\/td>/).flatten
fail_validation("分析页案例编号不完整") unless html_case_ids == EXPECTED_CASES

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
  "能力矩阵" => [/<tr data-family=/, 18],
  "直接证据" => [/<tr data-result=/, 17],
  "自然语言证据" => [/<tr data-chat-case=/, 5],
  "阻塞项" => [/<div class="gap-row">/, 6],
  "修复记录" => [/<div class="repair-item">/, 10]
}
expected_html_counts.each do |label, (pattern, expected)|
  actual = html.scan(pattern).length
  fail_validation("分析页#{label}数量为 #{actual}，预期 #{expected}") unless actual == expected
end

report = File.read(File.join(ROOT, "report", "#{REPORT_DATE}-workflow-coverage-report.md"))
fail_validation("文字报告缺少 41 个非 n8n 定义口径") unless report.include?("只比较其余 41 个定义")
fail_validation("文字报告缺少 #3182 证据边界") unless report.include?("`#3182`")
fail_validation("文字报告缺少 #3161 定向回归边界") unless report.include?("`#3161`")
fail_validation("文字报告缺少 #3184 定向回归边界") unless report.include?("`#3184`")
fail_validation("文字报告缺少 /api/chat 与 Lark Bot 区分") unless report.include?("`/api/chat` 与 Lark Bot")
fail_validation("分析页缺少实际路径口径") unless html.include?("~/Code/workflows") && html.include?("~/workflows")
fail_validation("分析页缺少 3/5 自然语言结论") unless html.include?("3 / 5")
%w[USE_SKILL_MOUNT_FAILED CAPABILITY_ADMISSION_REBIND_REQUIRED].each do |closed_blocker|
  fail_validation("分析页仍把已关闭症状列为当前阻塞：#{closed_blocker}") if html.include?(closed_blocker)
end

puts "通过 报告案例=17 源版本族=7 能力矩阵=18 自然语言=5 阻塞=6 修复记录=10"
