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
  "lark-bot-file-upload-validation" => ["19-lark-bot-file-upload-validation.workflow.yaml", "Lark Bot 文件上传验证", "验证通过 Lark Bot 上传的文件、附件引用或 document_extract 主链", "验证当前消息中的合成上传文件，不执行任何外部写入。", "success=true；通过 Lark Bot 运行时还必须 lark_bot_ingress_validated=true"]
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
  "lark-bot-file-upload-validation" => "1.0"
}.freeze

SKILLS.each do |slug, (workflow_file, title, trigger, prompt, expected)|
  workflow_name = File.basename(workflow_file, ".workflow.yaml").sub(/^\d+-/, "").tr("-", "_")
  directory = File.join(ROOT, "skills", slug)
  asset_directory = File.join(directory, "assets")
  FileUtils.rm_rf(File.join(directory, "workflows"))
  FileUtils.mkdir_p(asset_directory)

  attachment_note = case slug
                    when "candidate-document-compliance-preview", "contractor-access-package-approval"
                      "当前请求必须带合成文本附件；让 aevatar_start_workflow 使用会话已登记的 input file refs。"
                    when "invoice-ocr-policy-review"
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
                  when "lark-post-search-approval-probe"
                    "必须从 typed pending event 或 read model 取得完整 approval identity；用户明确批准后只能发送 nested toolApproval resume，未批准或拒绝时不得执行 POST。"
                  when "safe-code-execute-validation", "lark-contact-batch-resolution"
                    "平台可能要求 typed tool approval，但业务契约无副作用；未得到明确批准时保持 pending。"
                  else
                    "不得根据模型文案推断额外授权。"
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

    1. 优先使用 `use_skill` 已挂载的 workflow；只有挂载不可用时，才把随 skill 返回的 YAML 作为 inline fallback。
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
  puts "已同步 #{slug}"
end
