#!/usr/bin/env ruby

require "set"
require "yaml"

ROOT = File.expand_path("..", __dir__)
WORKFLOW_DIR = File.join(ROOT, "workflows")

EXPECTED = {
  "01-release-readiness-review.workflow.yaml" => [13, 0, 0, 0],
  "02-candidate-document-compliance-preview.workflow.yaml" => [3, 0, 0, 0],
  "03-email-access-approval-audit.workflow.yaml" => [5, 2, 2, 0],
  "04-saas-license-utilization-review.workflow.yaml" => [10, 6, 6, 0],
  "05-asset-inventory-attestation.workflow.yaml" => [8, 1, 0, 1],
  "06-project-shared-mailbox-approval.workflow.yaml" => [8, 3, 2, 1],
  "07-quarterly-access-review-reminder.workflow.yaml" => [8, 1, 0, 1],
  "08-saas-license-optimization-digest.workflow.yaml" => [21, 7, 6, 1],
  "09-contractor-access-package-approval.workflow.yaml" => [23, 5, 4, 1],
  "10-monthly-access-certification.workflow.yaml" => [28, 5, 2, 3]
}.freeze

ALLOWED_PLACEHOLDERS = Set.new(
  YAML.safe_load(File.read(File.join(ROOT, "config.example.yaml")), aliases: false)
      .fetch("replacements").keys
).freeze

def fail_validation(message)
  warn "VALIDATION_FAILED #{message}"
  exit 1
end

files = Dir[File.join(WORKFLOW_DIR, "*.workflow.yaml")].sort
actual_names = files.map { |file| File.basename(file) }
fail_validation("workflow set does not match expected files") unless actual_names == EXPECTED.keys

all_placeholders = Set.new

files.each do |file|
  name = File.basename(file)
  text = File.read(file)
  document = YAML.safe_load(text, aliases: false)
  steps = document.fetch("steps")
  ids = steps.map { |step| step.fetch("id") }
  fail_validation("duplicate step id in #{name}") unless ids.uniq.length == ids.length

  references = []
  steps.each do |step|
    references << [step.fetch("id"), step["next"]] if step["next"]
    next unless step["type"] == "switch"

    step.fetch("branches", {}).each_value do |target|
      references << [step.fetch("id"), target]
    end
  end
  references.each do |source, target|
    fail_validation("#{name}: #{source} references missing step #{target}") unless ids.include?(target)
  end

  capabilities = steps.map { |step| step.dig("capability", "nyxid_request") }.compact
  methods = capabilities.map { |capability| capability.fetch("method").upcase }
  expected_steps, expected_external, expected_get, expected_post = EXPECTED.fetch(name)
  actual = [steps.length, capabilities.length, methods.count("GET"), methods.count("POST")]
  expected = [expected_steps, expected_external, expected_get, expected_post]
  fail_validation("#{name}: expected #{expected.inspect}, got #{actual.inspect}") unless actual == expected

  placeholders = Set.new(text.scan(/__[A-Z0-9_]+__/))
  unknown = placeholders - ALLOWED_PLACEHOLDERS
  fail_validation("#{name}: unknown placeholders #{unknown.to_a.join(', ')}") unless unknown.empty?
  all_placeholders.merge(placeholders)

  fail_validation("#{name}: contains a literal UUID") if text.match?(/\b[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}\b/i)
  fail_validation("#{name}: contains a literal Lark table or record id") if text.match?(/\b(?:tbl|rec|vew)[A-Za-z0-9]{8,}\b/)
  fail_validation("#{name}: contains a non-example Lark tenant URL") if text.match?(%r{https://(?!example\.larksuite\.com)[^/]*larksuite\.com})

  puts "PASS #{name} steps=#{steps.length} external=#{capabilities.length} GET=#{methods.count('GET')} POST=#{methods.count('POST')}"
end

unused = ALLOWED_PLACEHOLDERS - all_placeholders
fail_validation("unused declared placeholders: #{unused.to_a.join(', ')}") unless unused.empty?

puts "PASS workflow_set=#{files.length} placeholders=#{all_placeholders.length}"
