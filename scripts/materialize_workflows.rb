#!/usr/bin/env ruby

require "fileutils"
require "yaml"

abort "用法：ruby scripts/materialize_workflows.rb <配置.yaml> [输出目录]" unless (1..2).cover?(ARGV.length)

root = File.expand_path("..", __dir__)
config_path = File.expand_path(ARGV[0])
output_dir = File.expand_path(ARGV[1] || File.join(root, "build", "workflows"))
config = YAML.safe_load(File.read(config_path), aliases: false)
replacements = config.fetch("replacements")

unless replacements.is_a?(Hash) && replacements.all? { |key, value| key.match?(/\A__[A-Z0-9_]+__\z/) && !value.to_s.strip.empty? }
  abort "配置中的 replacements 必须把 __PLACEHOLDER__ 键映射到非空值"
end

sources = Dir[File.join(root, "workflows", "*.workflow.yaml")].sort
expected_outputs = sources.map { |source| File.basename(source) }

FileUtils.mkdir_p(output_dir)
Dir[File.join(output_dir, "*.workflow.yaml")].sort.each do |target|
  next if expected_outputs.include?(File.basename(target))

  File.delete(target)
  puts "已清理过期输出 #{File.basename(target)}"
end

sources.each do |source|
  content = File.read(source)
  content.scan(/__[A-Z0-9_]+__/).uniq.each do |placeholder|
    abort "缺少占位符替换值：#{placeholder}" unless replacements.key?(placeholder)
    content = content.gsub(placeholder, replacements.fetch(placeholder).to_s)
  end
  unresolved = content.scan(/__[A-Z0-9_]+__/).uniq
  abort "#{File.basename(source)} 中仍有未解析占位符：#{unresolved.join(', ')}" unless unresolved.empty?

  target = File.join(output_dir, File.basename(source))
  File.write(target, content)
  puts "已生成 #{File.basename(source)}"
end
