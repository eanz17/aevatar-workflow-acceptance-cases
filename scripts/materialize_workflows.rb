#!/usr/bin/env ruby

require "fileutils"
require "yaml"

abort "usage: ruby scripts/materialize_workflows.rb <config.yaml> [output-dir]" unless (1..2).cover?(ARGV.length)

root = File.expand_path("..", __dir__)
config_path = File.expand_path(ARGV[0])
output_dir = File.expand_path(ARGV[1] || File.join(root, "build", "workflows"))
config = YAML.safe_load(File.read(config_path), aliases: false)
replacements = config.fetch("replacements")

unless replacements.is_a?(Hash) && replacements.all? { |key, value| key.match?(/\A__[A-Z0-9_]+__\z/) && !value.to_s.strip.empty? }
  abort "config replacements must map __PLACEHOLDER__ keys to non-empty values"
end

FileUtils.mkdir_p(output_dir)
Dir[File.join(root, "workflows", "*.workflow.yaml")].sort.each do |source|
  content = File.read(source)
  content.scan(/__[A-Z0-9_]+__/).uniq.each do |placeholder|
    abort "missing replacement for #{placeholder}" unless replacements.key?(placeholder)
    content = content.gsub(placeholder, replacements.fetch(placeholder).to_s)
  end
  unresolved = content.scan(/__[A-Z0-9_]+__/).uniq
  abort "unresolved placeholders in #{File.basename(source)}: #{unresolved.join(', ')}" unless unresolved.empty?

  target = File.join(output_dir, File.basename(source))
  File.write(target, content)
  puts "MATERIALIZED #{File.basename(source)}"
end
