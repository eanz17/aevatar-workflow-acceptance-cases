#!/usr/bin/env ruby

require "yaml"

ROOT = File.expand_path("..", __dir__)
INLINE_WORKFLOW_ASSETS = {
  "vendor-policy-inline-delegation" => {
    "vendor-policy-inline-evaluator.yaml" =>
      "fixtures/inline-workflows/vendor-policy-inline-evaluator.workflow.yaml"
  }
}.freeze
workflow_names = Dir[File.join(ROOT, "workflows", "*.workflow.yaml")].sort.map do |path|
  YAML.safe_load(File.read(path), aliases: false).fetch("name")
end
skill_directories = Dir[File.join(ROOT, "skills", "*")].sort.select { |path| File.directory?(path) }

abort "skill 数量不是 #{workflow_names.length}" unless skill_directories.length == workflow_names.length

asset_names = []
skill_directories.each do |directory|
  slug = File.basename(directory)
  skill_path = File.join(directory, "SKILL.md")
  abort "#{slug} 缺少 SKILL.md" unless File.file?(skill_path)
  text = File.read(skill_path)
  frontmatter = text.match(/\A---\n(.*?)\n---\n/m)
  abort "#{slug} 缺少 frontmatter" unless frontmatter
  metadata = YAML.safe_load(frontmatter[1], aliases: false)
  abort "#{slug} 的 name 不一致" unless metadata["name"] == slug
  abort "#{slug} 的 description 为空" if metadata["description"].to_s.strip.empty?
  abort "#{slug} 的 version 必须是 major.minor 字符串" unless metadata["version"].is_a?(String) &&
    metadata["version"].match?(/\A(?:0|[1-9]\d*)\.(?:0|[1-9]\d*)\z/)
  abort "#{slug} 的 version 必须在 SKILL.md 中显式加双引号" unless frontmatter[1].match?(
    /^version: "(?:0|[1-9]\d*)\.(?:0|[1-9]\d*)"$/
  )
  abort "#{slug} 未声明 typed artifact 判定" unless text.include?("aevatar_read_workflow_run_artifact") && text.include?("pending")

  abort "#{slug} 不得包含 Ornn validator 禁止的根目录 workflows/" if File.directory?(
    File.join(directory, "workflows")
  )
  workflow_files = Dir[File.join(directory, "assets", "*.yaml")].sort
  inline_assets = INLINE_WORKFLOW_ASSETS.fetch(slug, {})
  expected_asset_count = 1 + inline_assets.length
  abort "#{slug} 的 assets/*.yaml 数量必须为 #{expected_asset_count}" unless workflow_files.length == expected_asset_count
  main_asset = workflow_files.find do |path|
    YAML.safe_load(File.read(path), aliases: false).fetch("name") == slug.tr("-", "_")
  end
  abort "#{slug} 缺少与公开 workflow 同名的主 asset" unless main_asset
  workflow = YAML.safe_load(File.read(main_asset), aliases: false)
  asset_names << workflow.fetch("name")
  abort "#{slug} 的内嵌 workflow 与公开 workflow 不一致" unless File.read(main_asset) == File.read(
    Dir[File.join(ROOT, "workflows", "*.workflow.yaml")].find do |path|
      YAML.safe_load(File.read(path), aliases: false).fetch("name") == workflow.fetch("name")
    end
  )
  inline_assets.each do |asset_name, fixture_path|
    asset_path = File.join(directory, "assets", asset_name)
    fixture = File.join(ROOT, fixture_path)
    abort "#{slug} 缺少 inline workflow asset #{asset_name}" unless File.file?(asset_path)
    abort "#{slug} 的 inline workflow asset 与 fixture 不一致" unless File.read(asset_path) == File.read(fixture)
  end
  puts "通过 #{slug} workflow=#{workflow.fetch('name')}"
end

abort "skill 未一一覆盖全部 workflow" unless asset_names.sort == workflow_names.sort
puts "通过 skill 总数=#{skill_directories.length}"
