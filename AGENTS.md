# 仓库协作说明

本仓库只保存用于验证 Aevatar 工作流能力的公开、安全、可复现案例。所有说明、角色名称、用户提示、业务示例和验证输出默认使用中文；工作流 `name`、步骤 `id`、API 字段、工具名、错误码与外部协议枚举保持原始技术名称，避免破坏运行契约。

## 使用现有工作流

1. 阅读 `README.md` 的能力矩阵和安全边界，先确认案例是只读、预览还是可能产生写入。
2. 将 `config.example.yaml` 复制为不会提交的 `config.local.yaml`，把 `replacements` 下的 14 个占位符替换为当前组织真实资源。不得把令牌、密钥、租户数据或审批内容写入仓库。
3. 执行 `ruby scripts/materialize_workflows.rb config.local.yaml`，在 `build/workflows/` 生成可提交给 Aevatar 的定义。
4. 执行 `ruby scripts/validate_workflows.rb`。它会检查文件集合、YAML、步骤图、外部调用计数、占位符、敏感标识以及 `codex_exec` 固定探针契约。
5. 生产验证必须先通过已认证的 NyxID CLI 进入 Aevatar。只能使用 `nyxid proxy request aevatar ...`，不得绕过 NyxID 直连后端或复用浏览器 bearer。
6. 先执行 `interactive` explicit-request preview，确认解析和能力准入。preview 通过不等于工作流运行通过。
7. 需要证明运行可用时，必须真实启动工作流，并保留 typed receipt、run ID 和 committed terminal evidence。`202 Accepted`、等待人工授权、模型自然语言或控制台显示“已发送”都不是终态成功证据。

默认不得执行会写 Base、创建 Lark 审批、发送消息或创建 schedule 的分支。只有用户明确要求、数据为可清理的验证数据、目标资源已复核且平台授权可见时，才能执行写入分支。

## 生产验证入口

使用 `scripts/production_validate.rb` 统一完成 production preview、绑定、执行、typed tool approval/resume 和 committed read model 查询。不得编写临时脚本绕过 NyxID，或把 SSE 文本、`202 Accepted`、模型文案当成成功证据。

- 默认只做 preview；真实运行必须显式加 `--run`。
- 有副作用的案例必须同时出现在 `--allow-side-effects`，并通过 `--approve` 才能依据 typed receipt 恢复。
- SSE 必须逐行消费；收到 `aevatar.tool_approval.pending` 后立即使用其中的 `stepId`、`executionId`、`toolCallId`、`approvalRequestId` 和已取得的 run ID 调用 resume，禁止等 SSE 结束后再批准。
- `--prompt` 只允许和单个 `--cases` 一起使用，用于验证同一定义的预览、提交、跳过或提醒分支。
- 验证器仅保留有界诊断输出；不得把完整 SSE、业务 payload 或未脱敏 receipt 写入仓库。

## `codex_exec` 验证规则

`workflows/11-complex-codex-exec-validation.workflow.yaml` 验证 operator-managed sandbox 全链路。它必须始终只调用一次 `codex_exec`，并拥有以下固定参数：

```json
{
  "target": {"kind": "managed_sandbox"},
  "workspace": {"kind": "empty_git"},
  "prompt": "Reply with exactly CODEX_EXEC_READY",
  "timeout_secs": 180
}
```

不得加入调用方指定的仓库、路径、镜像、模型、provider、sandbox flag、token、key、`auth.json` 或 `CODEX_HOME`。成功必须同时满足：`status=succeeded`、`target=managed_sandbox`、裁剪后的 `output=CODEX_EXEC_READY`、`exit_code=0`，且 `diagnostic_id` 非空并已脱敏。任何字段缺失、额外模型文本或 typed failure 都算失败。

`codex_exec` 步骤的 `timeout_ms` 必须为 `360000`。截止时间应保持“内部探针 180 秒 < Aevatar 托管请求 300 秒 < NyxID/ingress 至少 315 秒 < 工作流 canary 360 秒”的顺序，避免外层提前结束造成假阴性。

五项证据名称必须通过一个并行 `foreach` 归一化。当前运行时使用四行 `---` 连接五个结果，所以汇总文本应为 9 个物理行，成功终态则必须继续报告 `parallel_check_count=5`。修改这段编排时必须同步更新并通过 `scripts/validate_workflows.rb`，不得只凭 preview 判断格式正确。

除案例 11 外，01-10 禁止使用通用 `code_execute` 或 `codex_exec` 代替确定性工作流节点。业务解析、分支、聚合和格式化应使用原生 `assign`、`transform`、`switch`、`conditional`、`foreach` 或 bounded template。案例 11 也只能保留一次上述固定 `codex_exec` 探针。

## 新增验证专用工作流

新增案例时按以下规则执行：

1. 使用下一个两位数字前缀，文件名采用 `NN-业务场景.workflow.yaml`，工作流 `name` 使用稳定的 `snake_case`。
2. 选择与现有案例不同、但确有业务意义的场景。验证的是可复用工作流能力，不要只换标题后复制同一数据。
3. 默认设计为无副作用或预览模式。写入分支必须由显式输入开启，并继续受平台工具授权保护。
4. 外部请求必须声明完整 `capability.nyxid_request`：固定 `user_service_id`、HTTP method、`path_template`、允许的 query/header 字段、body 模式和 response 模式。不得让输入控制 service、method、host 或任意 path。
5. 组织资源只使用 `__UPPER_SNAKE_CASE__` 占位符，并在 `config.example.yaml` 声明。fixture 只能包含合成数据。
6. 步骤 `id` 必须唯一；所有 `next` 和 `switch` 分支必须指向存在的步骤；分支最终应汇入明确终态。
7. 结果必须可机器判断，至少包含稳定 `case`、`success` 或等价布尔值、执行模式和副作用状态。不要把模型描述当成通过条件。
8. 在 `scripts/validate_workflows.rb` 的 `EXPECTED` 中登记步骤数与 GET/POST 调用数；如使用非 NyxID 工具，增加该工具的精确契约断言。
9. 在 `README.md` 更新能力矩阵、逐流程证据和限制；在 `validation/` 只提交已脱敏的验证摘要，不提交运行输入或原始业务响应。
10. 本地校验、materialize 和生产 preview 都通过后，仍需按风险决定是否真实运行。README 必须分别陈述“静态校验”“preview”“真实终态”三类证据，禁止混写为一个 PASS。
11. 真实验证状态变化后，同步更新 `validation/production-validation-YYYY-MM-DD.json`、`report/YYYY-MM-DD-workflow-coverage-report.md`、`report/index.html` 和 README。报告必须区分“覆盖”“语义替换”“部分覆盖”“未覆盖”。
12. 对比源工作流时按版本族归并，不能把旧副本、Ornn 内嵌资产和独立业务定义当成同等的新增能力，也不能用文件覆盖率代替功能覆盖率。

## 提交前检查

至少执行：

```bash
ruby scripts/validate_workflows.rb
ruby -c scripts/production_validate.rb
ruby scripts/materialize_workflows.rb config.example.yaml
ruby -ryaml -e 'Dir["build/workflows/*.yaml"].sort.each { |f| YAML.safe_load(File.read(f), aliases: false) }'
ruby scripts/validate_report.rb
git diff --check
```

最后检查 `git status`，确保 `config.local.yaml`、`build/`、凭据、真实组织标识和未脱敏运行证据没有进入提交。推送后等待 GitHub Actions 的“验证工作流”任务成功。
