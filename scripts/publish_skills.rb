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
  via_service: ENV["ORNN_USER_SERVICE_ID"]
}

OptionParser.new do |parser|
  parser.banner = "用法：ruby scripts/publish_skills.rb [选项]"
  parser.on("--service SLUG", "NyxID 中的 Ornn service slug") { |value| options[:service] = value }
  parser.on("--via-service ID", "指定 NyxID UserService ID") { |value| options[:via_service] = value }
end.parse!

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

packages = Dir[File.join(PACKAGE_DIR, "*.zip")].sort
abort "没有找到 skill ZIP，请先执行 ruby scripts/package_skills.rb config.local.yaml" if packages.empty?

results = packages.map do |package|
  name = File.basename(package, ".zip")
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
  unless detail["guid"] == guid && detail["name"] == name && detail["isPrivate"] == false
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
  count: results.length,
  skills: results
)
