#!/usr/bin/env ruby

require "fileutils"

ROOT = File.expand_path("..", __dir__)

SKILLS = {
  "release-readiness-review" => ["01-release-readiness-review.workflow.yaml", "发布准备度审查", "检查上线准备、备份、监控或回滚控制", "运行发布准备度审查。", "ready_for_review=true、side_effects=false"],
  "candidate-document-compliance-preview" => ["02-candidate-document-compliance-preview.workflow.yaml", "候选人材料完整性预览", "检查候选人附件、材料完整性或隐私约束", "检查当前消息中的合成候选人附件。", "五项材料布尔值全部为 true"],
  "email-access-approval-audit" => ["03-email-access-approval-audit.workflow.yaml", "邮箱访问审批审计", "只读检查邮箱访问审批列表和实例详情", "审计一条邮箱访问审批。", "instance_reachable=true、side_effects=false"],
  "saas-license-utilization-review" => ["04-saas-license-utilization-review.workflow.yaml", "SaaS 许可证利用率审查", "复核软件席位、许可证利用率或订阅成本", "生成 SaaS 许可证利用率审查。", "live_base_reads_ok=true 且合计值通过"],
  "asset-inventory-attestation" => ["05-asset-inventory-attestation.workflow.yaml", "资产盘点确认", "预览或明确提交 IT 资产盘点记录", "{\"submit\":false}", "preview 不写入；submit 仅在明确授权后写入"],
  "project-shared-mailbox-approval" => ["06-project-shared-mailbox-approval.workflow.yaml", "项目共享邮箱审批", "从 Base 申请创建并回读共享邮箱审批", "创建并验证共享邮箱审批。", "创建与回读都成功；这是有副作用操作"],
  "quarterly-access-review-reminder" => ["07-quarterly-access-review-reminder.workflow.yaml", "季度访问审查提醒", "预览或明确发送季度访问审查私信", "{\"submit\":false}", "preview 不发送；submit 仅在明确授权后发送"],
  "saas-license-optimization-digest" => ["08-saas-license-optimization-digest.workflow.yaml", "SaaS 许可证优化摘要", "汇总多路 Base 数据并预览或发送许可证优化卡片", "{\"submit\":false}", "六源汇总成功；发送分支需要明确授权"],
  "contractor-access-package-approval" => ["09-contractor-access-package-approval.workflow.yaml", "外包人员访问资料审批", "检查外包人员附件、历史去重并预览或创建审批", "{\"submit\":false}", "资料完整且 preview 无写入；submit 需要明确授权"],
  "monthly-access-certification" => ["10-monthly-access-certification.workflow.yaml", "月度访问认证", "执行月末访问认证、提醒预览或明确发送提醒", "{\"mode\":\"preview\",\"run_date\":\"2026-08-31\",\"period\":\"2026-08\"}", "预览只读；提交和消息分支需要明确授权"],
  "complex-codex-exec-validation" => ["11-complex-codex-exec-validation.workflow.yaml", "复杂 codex_exec 验证", "验证 managed sandbox、固定输出和多分支 receipt", "运行固定的 codex_exec 验收探针。", "五项 checks 为 true、parallel_check_count=5"],
  "safe-code-execute-validation" => ["12-safe-code-execute-validation.workflow.yaml", "安全 code_execute 验证", "验证通用 JavaScript 执行和结构化结算 receipt", "校验合成结算金额。", "success=true、total_cents=16623、side_effects=false"],
  "invoice-ocr-policy-review" => ["13-invoice-ocr-policy-review.workflow.yaml", "发票 OCR 与策略审查", "从发票图片或 PDF 提取字段、归一化并检查历史重复", "提取当前消息中的合成发票，归一化并检查重复；不要创建审批。", "字段和归一化通过、精确重复 1 条、同供应商 2 条"],
  "lark-contact-batch-resolution" => ["14-lark-contact-batch-resolution.workflow.yaml", "Lark 联系人批量解析", "通过 contact batch_get_id 解析入职邮箱身份", "解析验收入职邮箱，只返回结果数量。", "success=true、resolved_count=1、标识不回显"],
  "weekly-budget-variance-digest" => ["15-weekly-budget-variance-digest.workflow.yaml", "周度预算差异摘要", "生成预算周报、月度投影或配置 recurring schedule", "生成预算周度与月度差异摘要，不发送消息。", "六路 Base 可达且周/月差异断言通过"],
  "nyxid-read-receipt-probe" => ["16-nyxid-read-receipt-probe.workflow.yaml", "NyxID 只读回执探针", "验证 managed workflow 的 NyxID provider receipt、首步输出或 issue 3161 回归", "运行单次只读 NyxID receipt 探针，不执行任何写入。", "success=true、provider_response_verified=true、side_effects=false"],
  "lark-post-search-approval-probe" => ["17-lark-post-search-approval-probe.workflow.yaml", "Lark POST 搜索批准恢复探针", "验证 POST 搜索的 typed tool approval pending、resume 或 issue 3184 回归", "运行语义只读的 Base POST 搜索批准恢复探针，不修改任何记录。", "preview 为 effectiveRisk=write 且 approvalRequired=true；终态 success=true、approval_resumed=true、side_effects=false"],
  "supplier-control-attestation-review" => ["18-supplier-control-attestation-review.workflow.yaml", "供应商控制项自证审查", "验证 guard、conditional 与 while 三个确定性工作流原语的真实运行行为", "运行无副作用的供应商控制项自证审查。", "attested=true、control_count=3、leading_control=breach_notice、replay_iterations=3、side_effects=false"],
  "supplier-risk-tier-aggregation" => ["20-supplier-risk-tier-aggregation.workflow.yaml", "供应商风险分档汇总", "验证 map_reduce 与 cache 两个确定性工作流原语的真实运行行为", "{\"probe_nonce\":\"<当前 UTC 时间戳，8-14 位纯数字，例如 20260807>\"}", "aggregated=true、mapped_tier_count=3、merged_line_count=5、cache_hit_returned_first_value=true、side_effects=false"],
  "lark-bot-file-upload-validation" => ["19-lark-bot-file-upload-validation.workflow.yaml", "Lark Bot 文件上传验证", "验证通过 Lark Bot 上传的文件、附件引用或 document_extract 主链", "验证当前消息中的合成上传文件，不执行任何外部写入。", "success=true；通过 Lark Bot 运行时还必须 lark_bot_ingress_validated=true"],
  "approval-window-integrity-audit" => ["21-approval-window-integrity-audit.workflow.yaml", "审批窗口完整性审计", "审计审批查询时间窗口是否过期、历史窗口陷阱或窗口重基线", "{\"epoch_now_ms\":<当前 UTC 毫秒时间戳，例如 1786000000000>}", "success=true、reads_ok=true、active_window_covers_now=true；legacy_window_expired 如实上报"],
  "acceptance-fixture-drift-attestation" => ["22-acceptance-fixture-drift-attestation.workflow.yaml", "验收 fixture 漂移体检", "只读体检验收 canary 数据是否漂移、fixture 是否完好", "运行验收 fixture 漂移体检，不执行任何写入。", "reads_completed=true、fixtures_intact=true、side_effects=false"],
  "readonly-attested-post-probe" => ["23-readonly-attested-post-probe.workflow.yaml", "只读声明 POST 探针", "验证声明 read_only 风险的语义只读 POST 免运行时审批执行", "运行只读声明 POST 探针，不修改任何记录。", "success=true、attested_readonly_executed=true、side_effects=false"],
  "runtime-tool-approval-write-probe" => ["24-runtime-tool-approval-write-probe.workflow.yaml", "运行时工具审批写入探针", "验证未声明风险 POST 的运行时 tool approval 挂起、恢复与真实写入回执", "{\"probe_note\":\"<当前 UTC 时间戳，8-14 位纯数字，例如 20260806>\"}", "mutation_executed=true、record_created=true；这是有副作用操作"],
  "sequential-tool-approval-write-probe" => ["25-sequential-tool-approval-write-probe.workflow.yaml", "顺序工具审批写入探针", "验证一次运行内连续两次写入的 tool approval 挂起与恢复组合", "{\"probe_note\":\"<当前 UTC 时间戳，8-14 位纯数字，例如 20260806>\"}", "first_mutation_executed=true、second_mutation_executed=true、sequential_mutations=2；这是有副作用操作"],
  "vendor-policy-inline-delegation" => ["26-vendor-policy-inline-delegation.workflow.yaml", "供应商政策 inline 委派审查", "验证 workflow_call 的 inline 子定义绑定、子运行与结果回传", "运行合成供应商政策 inline 委派审查，不执行任何外部写入。", "success=true、inline_definition_bound=true、child_definition_resolved=true、child_workflow_completed=true、side_effects=false"],
  "deterministic-parallel-evidence-review" => ["27-deterministic-parallel-evidence-review.workflow.yaml", "确定性并行证据审查", "验证 deterministic parallel 三路 worker、receipt 与 dispatch index 合并", "并行核对三份合成供应商证据，不执行任何外部写入。", "success=true、worker_count=3、all_worker_receipts_observed=true、merged_output_order_verified=true、side_effects=false"],
  "deterministic-race-policy-review" => ["28-deterministic-race-policy-review.workflow.yaml", "确定性竞速政策审查", "验证 deterministic race 的首成功 winner 与后续完成忽略语义", "运行三路合成政策评估并采用首个成功结果，不执行任何外部写入。", "success=true、worker_count=3、winner_in_candidate_set=true、first_success_selected=true、later_completions_ignored=true、side_effects=false"],
  "invoice-approval-routing-preview" => ["29-invoice-approval-routing-preview.workflow.yaml", "发票审批路由预览", "验证当前发票附件、审批历史去重和 contact 路由的 no-submit 集成契约", "提取合成发票，检查历史重复并解析审批路由；只生成预览，不创建审批或发送消息。", "success=true、execution_mode=preview、exact_duplicate_found=true、approval_route_resolved=true、approval_created=false、external_writes=false、side_effects=false"]
}.freeze

VERSIONS = {
  "release-readiness-review" => "2.1",
  "candidate-document-compliance-preview" => "2.1",
  "email-access-approval-audit" => "2.1",
  "saas-license-utilization-review" => "2.1",
  "asset-inventory-attestation" => "2.1",
  "project-shared-mailbox-approval" => "2.1",
  "quarterly-access-review-reminder" => "2.1",
  "saas-license-optimization-digest" => "4.1",
  "contractor-access-package-approval" => "2.1",
  "monthly-access-certification" => "3.1",
  "complex-codex-exec-validation" => "1.1",
  "safe-code-execute-validation" => "1.1",
  "invoice-ocr-policy-review" => "1.1",
  "lark-contact-batch-resolution" => "1.1",
  "weekly-budget-variance-digest" => "1.1",
  "nyxid-read-receipt-probe" => "1.1",
  "lark-post-search-approval-probe" => "1.1",
  "supplier-control-attestation-review" => "1.0",
  "supplier-risk-tier-aggregation" => "1.1",
  "lark-bot-file-upload-validation" => "1.1",
  "approval-window-integrity-audit" => "1.0",
  "acceptance-fixture-drift-attestation" => "1.0",
  "readonly-attested-post-probe" => "1.0",
  "runtime-tool-approval-write-probe" => "1.0",
  "sequential-tool-approval-write-probe" => "1.0",
  "vendor-policy-inline-delegation" => "1.0",
  "deterministic-parallel-evidence-review" => "1.0",
  "deterministic-race-policy-review" => "1.0",
  "invoice-approval-routing-preview" => "1.0"
}.freeze

INLINE_WORKFLOW_ASSETS = {
  "vendor-policy-inline-delegation" => [
    "fixtures/inline-workflows/vendor-policy-inline-evaluator.workflow.yaml"
  ]
}.freeze

SKILLS.each do |slug, (workflow_file, title, trigger, prompt, expected)|
  workflow_name = File.basename(workflow_file, ".workflow.yaml").sub(/^\d+-/, "").tr("-", "_")
  directory = File.join(ROOT, "skills", slug)
  asset_directory = File.join(directory, "assets")
  FileUtils.rm_rf(File.join(directory, "workflows"))
  FileUtils.mkdir_p(asset_directory)
  Dir[File.join(asset_directory, "*.yaml")].each { |path| File.delete(path) }

  attachment_note = case slug
                    when "candidate-document-compliance-preview", "contractor-access-package-approval"
                      "当前请求必须带合成文本附件；让 aevatar_start_workflow 使用会话已登记的 input file refs。"
                    when "invoice-ocr-policy-review", "invoice-approval-routing-preview"
                      "当前请求必须带发票图片或文件；Assistant /api/chat 使用图片，direct workflow 验证可使用 PDF。"
                    when "lark-bot-file-upload-validation"
                      "当前请求必须带 `lark-bot-upload-manifest.json`；直接入口只验证文件主链，只有同一 typed artifact 的 `lark_bot_ingress_validated=true` 才能证明 Lark Bot 入站附件链。"
                    else
                      "此案例不需要附件。"
                    end
  approval_note = case slug
                  when "asset-inventory-attestation", "project-shared-mailbox-approval",
                       "quarterly-access-review-reminder", "saas-license-optimization-digest",
                       "contractor-access-package-approval", "monthly-access-certification"
                    "写入、审批或发消息分支必须由用户明确提出，并等待 typed tool approval；一般的检查请求只能走预览。"
                  when "runtime-tool-approval-write-probe", "sequential-tool-approval-write-probe"
                    "本 workflow 没有预览分支：每次启动都会真实写入 Base 验收表（分别 1 条、2 条带探针前缀的可清理记录），" \
                      "并在每次写入前挂起等待 typed tool approval。必须由用户明确要求运行写入探针才可启动，" \
                      "并逐次等待用户批准；未获批准时保持 pending，不得代为批准或改走其他分支。"
                  when "lark-post-search-approval-probe"
                    "必须从 typed pending event 或 read model 取得完整 approval identity；用户明确批准后只能发送 nested toolApproval resume，未批准或拒绝时不得执行 POST。"
                  when "safe-code-execute-validation", "lark-contact-batch-resolution"
                    "平台可能要求 typed tool approval，但业务契约无副作用；未得到明确批准时保持 pending。"
                  else
                    "不得根据模型文案推断额外授权。"
                  end
  workflow_source_note = if slug == "vendor-policy-inline-delegation"
                           "优先使用 `use_skill` 已挂载的完整定义集；只有挂载不可用时，才把父定义和 `vendor_policy_inline_evaluator` 子定义两个 YAML 同时作为 `workflow_yamls` inline fallback。禁止只传父定义。"
                         else
                           "优先使用 `use_skill` 已挂载的 workflow；只有挂载不可用时，才把随 skill 返回的 YAML 作为 inline fallback。"
                         end

  content = <<~MARKDOWN
    ---
    name: #{slug}
    description: #{trigger}。用户提到“#{title}”、对应英文名称或要求运行该验收 workflow 时使用。
    version: "#{VERSIONS.fetch(slug)}"
    metadata:
      category: mixed
      output-type: text
      runtime:
        - aevatar-workflow
      tool-list:
        - aevatar_start_workflow
        - aevatar_read_workflow_run_artifact
      tag:
        - workflow
        - acceptance
        - aevatar
    ---

    # #{title}

    使用随 skill 提供的 `#{workflow_name}` workflow。

    ## 执行

    1. #{workflow_source_note}
    2. 调用 `aevatar_start_workflow`，`workflow_id` 设为 `#{workflow_name}`，`inputs.prompt` 设为 `#{prompt}`。
    3. #{attachment_note}
    4. #{approval_note}
    5. 使用返回的 `run_id` 调用 `aevatar_read_workflow_run_artifact`。只有 typed artifact 为 completed 且满足 `#{expected}`，才能报告通过。

    如果短 `run_id` 的 artifact 仍为 pending，必须如实报告 pending；不得把 accepted receipt、工具批准等待态或模型总结改写成成功。
  MARKDOWN

  File.write(File.join(directory, "SKILL.md"), content)
  FileUtils.cp(
    File.join(ROOT, "workflows", workflow_file),
    File.join(asset_directory, "#{workflow_name}.yaml")
  )
  INLINE_WORKFLOW_ASSETS.fetch(slug, []).each do |relative_path|
    FileUtils.cp(
      File.join(ROOT, relative_path),
      File.join(asset_directory, File.basename(relative_path).sub(".workflow", ""))
    )
  end
  puts "已同步 #{slug}"
end
