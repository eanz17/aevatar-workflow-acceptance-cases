#!/usr/bin/env ruby

require "fileutils"
require "yaml"

abort "用法：ruby scripts/package_skills.rb <配置.yaml>" unless ARGV.length == 1

ROOT = File.expand_path("..", __dir__)
config = YAML.safe_load(File.read(File.expand_path(ARGV[0])), aliases: false)
replacements = config.fetch("replacements")
build_root = File.join(ROOT, "build", "skills")
FileUtils.mkdir_p(build_root)

Dir[File.join(ROOT, "skills", "*")].sort.each do |source_directory|
  next unless File.directory?(source_directory)

  slug = File.basename(source_directory)
  target_directory = File.join(build_root, slug)
  FileUtils.rm_rf(target_directory)
  FileUtils.mkdir_p(File.join(target_directory, "assets"))
  FileUtils.cp(File.join(source_directory, "SKILL.md"), target_directory)

  Dir[File.join(source_directory, "assets", "*")].sort.each do |source|
    content = File.read(source)
    content.scan(/__[A-Z0-9_]+__/).uniq.each do |placeholder|
      abort "#{slug} 缺少替换值 #{placeholder}" unless replacements.key?(placeholder)
      content = content.gsub(placeholder, replacements.fetch(placeholder).to_s)
    end
    unresolved = content.scan(/__[A-Z0-9_]+__/).uniq
    abort "#{slug} 仍有未解析占位符：#{unresolved.join(', ')}" unless unresolved.empty?
    File.write(File.join(target_directory, "assets", File.basename(source)), content)
  end

  archive = File.join(build_root, "#{slug}.zip")
  FileUtils.rm_f(archive)
  success = system("zip", "-qr", archive, slug, chdir: build_root)
  abort "打包 #{slug} 失败" unless success
  puts "已打包 #{slug}"
end
