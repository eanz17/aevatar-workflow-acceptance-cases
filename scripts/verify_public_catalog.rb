#!/usr/bin/env ruby

require "json"
require "open3"
require "time"
require "uri"

ROOT = File.expand_path("..", __dir__)
PACKAGE_DIR = File.join(ROOT, "build", "skills")
SERVICE = ENV.fetch("ORNN_SERVICE_SLUG", "ornn-api")

def request_json(path, method: "GET", data_path: nil, content_type: nil, allow_not_found: false)
  arguments = ["proxy", "request", SERVICE, path, "--method", method, "--output", "json"]
  arguments += ["--data", "@#{data_path}"] if data_path
  arguments += ["--header", "Content-Type:#{content_type}"] if content_type
  stdout, stderr, status = Open3.capture3("nyxid", *arguments)
  return nil if allow_not_found && stderr.include?("HTTP 404 Not Found")

  detail = [stderr, stdout].map(&:strip).reject(&:empty?).join(" | ")
  raise "NyxID 请求失败（exit=#{status.exitstatus}）：#{detail}" unless status.success?
  raise "NyxID 代理请求失败：#{detail}" if stderr.include?("Proxy request failed")

  JSON.parse(stdout)
rescue JSON::ParserError => e
  raise "Ornn 未返回有效 JSON：#{e.message}"
end

def local_version(package, name)
  text, stderr, status = Open3.capture3("unzip", "-p", package, "#{name}/SKILL.md")
  raise "#{name} 无法读取 SKILL.md：#{stderr.strip}" unless status.success?

  match = text.match(/^version: "(0|[1-9]\d*)\.(0|[1-9]\d*)"$/)
  raise "#{name} 缺少有效 major.minor version" unless match

  "#{match[1]}.#{match[2]}"
end

packages = Dir[File.join(PACKAGE_DIR, "*.zip")].sort
abort "没有 skill ZIP，请先执行 ruby scripts/package_skills.rb config.local.yaml" if packages.empty?

results = packages.map do |package|
  name = File.basename(package, ".zip")
  version = local_version(package, name)
  validation = request_json(
    "/api/v1/skill-format/validate",
    method: "POST",
    data_path: package,
    content_type: "application/zip"
  )
  valid = validation.dig("data", "valid")
  valid = validation["valid"] if valid.nil?
  remote = request_json(
    "/api/v1/skills/#{URI.encode_www_form_component(name)}",
    allow_not_found: true
  )&.fetch("data")
  {
    name: name,
    localVersion: version,
    serverFormatValid: valid == true,
    found: !remote.nil?,
    public: remote && remote["isPrivate"] == false,
    versionMatches: remote && remote["version"] == version
  }
rescue StandardError => e
  {
    name: name,
    localVersion: version,
    serverFormatValid: false,
    found: false,
    public: false,
    versionMatches: false,
    diagnostic: e.message.to_s.byteslice(0, 500)
  }
end

summary = {
  verifiedAtUtc: Time.now.utc.iso8601,
  service: SERVICE,
  localSkillCount: results.length,
  serverFormatValidated: results.count { |item| item[:serverFormatValid] },
  exactNameReadback: results.count { |item| item[:found] },
  publicSkillCount: results.count { |item| item[:public] },
  versionMatches: results.count { |item| item[:versionMatches] },
  missingSkills: results.reject { |item| item[:found] }.map { |item| item[:name] },
  privateSkills: results.select { |item| item[:found] && !item[:public] }.map { |item| item[:name] },
  versionMismatches: results.select { |item| item[:found] && !item[:versionMatches] }.map { |item| item[:name] },
  uploadsPerformed: false,
  permissionsChanged: false
}

puts JSON.pretty_generate(summary)
exit 1 unless summary.values_at(
  :localSkillCount,
  :serverFormatValidated,
  :exactNameReadback,
  :publicSkillCount,
  :versionMatches
).uniq == [results.length]
