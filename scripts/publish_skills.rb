#!/usr/bin/env ruby

require "json"
require "open3"
require "optparse"
require "time"
require "uri"

ROOT = File.expand_path("..", __dir__)
PACKAGE_DIR = File.join(ROOT, "build", "skills")

class PublishError < StandardError; end

options = {
  service: ENV.fetch("ORNN_SERVICE_SLUG", "ornn-api"),
  via_service: ENV["ORNN_USER_SERVICE_ID"],
  verify_only: false,
  missing_only: false,
  skills: nil
}

OptionParser.new do |parser|
  parser.banner = "用法：ruby scripts/publish_skills.rb [选项]"
  parser.on("--service SLUG", "NyxID 中的 Ornn service slug") { |value| options[:service] = value }
  parser.on("--via-service ID", "指定 NyxID UserService ID") { |value| options[:via_service] = value }
  parser.on("--verify-only", "只校验服务端格式、线上版本和 public 状态，不上传") do
    options[:verify_only] = true
  end
  parser.on("--missing-only", "校验全部包，只发布线上缺失的 skill") do
    options[:missing_only] = true
  end
  parser.on("--skills LIST", "只处理逗号分隔的 skill 名称") do |value|
    options[:skills] = value.split(",").map(&:strip).reject(&:empty?).uniq
  end
end.parse!

abort "--verify-only 与 --missing-only 不能同时使用" if options.values_at(:verify_only, :missing_only).all?

def request_json(options, path, method: "GET", data_path: nil, body: nil, content_type: nil,
                 allow_not_found: false)
  arguments = ["proxy", "request", options.fetch(:service), path, "--method", method, "--output", "json"]
  arguments += ["--via-service", options.fetch(:via_service)] if options[:via_service]
  if data_path
    arguments += ["--data", "@#{data_path}"]
  elsif body
    arguments += ["--data", "-"]
  end
  arguments += ["--header", "Content-Type:#{content_type}"] if content_type

  stdout, stderr, status = Open3.capture3(
    "nyxid",
    *arguments,
    stdin_data: body ? JSON.generate(body) : ""
  )
  return nil if allow_not_found && stderr.include?("HTTP 404 Not Found")

  detail = [stderr, stdout].map(&:strip).reject(&:empty?).join(" | ")
  raise PublishError, "NyxID 请求失败（exit=#{status.exitstatus}）：#{detail}" unless status.success?
  raise PublishError, "NyxID 代理请求失败：#{detail}" if stderr.include?("Proxy request failed")

  response = JSON.parse(stdout)
  error = response["error"]
  raise PublishError, "Ornn 返回错误 #{error['code']}：#{error['message']}" if error

  response
rescue JSON::ParserError => e
  raise PublishError, "Ornn 未返回有效 JSON：#{e.message}"
end

def read_package_version(package)
  name = File.basename(package, ".zip")
  skill_text, stderr, status = Open3.capture3("unzip", "-p", package, "#{name}/SKILL.md")
  unless status.success?
    raise PublishError, "#{name} 无法从 ZIP 读取 SKILL.md：#{stderr.strip}"
  end

  match = skill_text.match(/^version: "(0|[1-9]\d*)\.(0|[1-9]\d*)"$/)
  raise PublishError, "#{name} 缺少有效的 major.minor version" unless match

  [match[0].delete_prefix('version: "').delete_suffix('"'), [match[1].to_i, match[2].to_i]]
end

def parse_remote_version(name, version)
  match = version.to_s.match(/\A(0|[1-9]\d*)\.(0|[1-9]\d*)\z/)
  raise PublishError, "#{name} 的线上 version 不符合 major.minor：#{version}" unless match

  [match[1].to_i, match[2].to_i]
end

packages = Dir[File.join(PACKAGE_DIR, "*.zip")].sort
abort "没有找到 skill ZIP，请先执行 ruby scripts/package_skills.rb config.local.yaml" if packages.empty?
if options[:skills]
  requested = options.fetch(:skills)
  available = packages.to_h { |package| [File.basename(package, ".zip"), package] }
  missing = requested.reject { |name| available.key?(name) }
  abort "找不到指定 skill ZIP：#{missing.join(', ')}" unless missing.empty?
  packages = requested.sort.map { |name| available.fetch(name) }
end

prepared = packages.map do |package|
  name = File.basename(package, ".zip")
  local_version, local_version_parts = read_package_version(package)
  validation = request_json(
    options,
    "/api/v1/skill-format/validate",
    method: "POST",
    data_path: package,
    content_type: "application/zip"
  )
  valid = validation.dig("data", "valid")
  valid = validation["valid"] if valid.nil?
  raise PublishError, "#{name} 未通过 Ornn 服务端格式校验" unless valid == true

  existing = request_json(
    options,
    "/api/v1/skills/#{URI.encode_www_form_component(name)}",
    allow_not_found: true
  )&.fetch("data")
  if options.fetch(:verify_only) || (options.fetch(:missing_only) && existing)
    raise PublishError, "#{name} 线上不存在" unless existing

    remote_version_parts = parse_remote_version(name, existing.fetch("version"))
    unless local_version_parts == remote_version_parts && existing["isPrivate"] == false
      raise PublishError,
            "#{name} 回读不一致：本地 #{local_version}，线上 #{existing.fetch('version')}，public=#{existing['isPrivate'] == false}"
    end
  elsif existing && (local_version_parts <=> parse_remote_version(name, existing.fetch("version"))) != 1
    raise PublishError,
          "#{name} 的本地 version #{local_version} 必须严格高于线上 #{existing.fetch('version')}"
  end

  {
    name: name,
    package: package,
    existing: existing,
    local_version: local_version
  }
end

preflight_scope = if options.fetch(:verify_only)
                    "版本/public 回读"
                  elsif options.fetch(:missing_only)
                    "缺失项发布预检"
                  else
                    "版本单调性预检"
                  end
puts "全部 #{prepared.length} 个 skill 已通过服务端格式与#{preflight_scope}"

if options.fetch(:verify_only)
  puts JSON.pretty_generate(
    verifiedAt: Time.now.utc.iso8601,
    service: options.fetch(:service),
    count: prepared.length,
    skills: prepared.map do |item|
      {
        name: item.fetch(:name),
        version: item.fetch(:local_version),
        public: true
      }
    end
  )
  exit
end

to_publish, skipped = if options.fetch(:missing_only)
                        prepared.partition { |item| item.fetch(:existing).nil? }
                      else
                        [prepared, []]
                      end

skipped.each do |item|
  puts "已跳过线上精确匹配 #{item.fetch(:name)} version=#{item.fetch(:local_version)} public=true"
end

results = to_publish.map do |item|
  name = item.fetch(:name)
  package = item.fetch(:package)
  existing = item.fetch(:existing)
  upload = if existing
             request_json(
               options,
               "/api/v1/skills/#{URI.encode_www_form_component(existing.fetch('guid'))}",
               method: "PUT",
               data_path: package,
               content_type: "application/zip"
             ).fetch("data")
           else
             request_json(
               options,
               "/api/v1/skills",
               method: "POST",
               data_path: package,
               content_type: "application/zip"
             ).fetch("data")
           end
  guid = upload.fetch("guid")

  request_json(
    options,
    "/api/v1/skills/#{URI.encode_www_form_component(guid)}/permissions",
    method: "PUT",
    body: {
      isPrivate: false,
      sharedWithUsers: [],
      sharedWithOrgs: []
    },
    content_type: "application/json"
  )

  detail = request_json(
    options,
    "/api/v1/skills/#{URI.encode_www_form_component(name)}"
  ).fetch("data")
  unless detail["guid"] == guid &&
         detail["name"] == name &&
         detail["version"] == item.fetch(:local_version) &&
         detail["isPrivate"] == false
    raise PublishError, "#{name} 上传后的公开状态回读不一致"
  end

  puts "已发布 #{name} guid=#{guid} version=#{detail['version']} public=true"
  {
    name: name,
    guid: guid,
    version: detail["version"],
    public: true
  }
end

puts JSON.pretty_generate(
  publishedAt: Time.now.utc.iso8601,
  service: options.fetch(:service),
  validatedCount: prepared.length,
  publishedCount: results.length,
  skippedExactCount: skipped.length,
  skills: results,
  skippedExact: skipped.map do |item|
    {
      name: item.fetch(:name),
      version: item.fetch(:local_version),
      public: true
    }
  end
)
