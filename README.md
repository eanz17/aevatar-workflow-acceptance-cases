# Aevatar 工作流验收案例

[![验证工作流](https://github.com/eanz17/aevatar-workflow-acceptance-cases/actions/workflows/validate.yml/badge.svg)](https://github.com/eanz17/aevatar-workflow-acceptance-cases/actions/workflows/validate.yml)

本仓库提供 17 个公开、安全、可复现的 Aevatar workflow，以及与它们一一对应的 Ornn skill。案例覆盖基础原语、文件与图片输入、Base、Lark 审批、Lark 消息、contact、通用代码执行、`codex_exec`、schedule、NyxID provider receipt 和 typed tool approval resume 等能力，并使用不同于源目录的实际业务场景。

公开 YAML 只保存占位符和合成数据，不包含组织专属 Base、用户、审批、NyxID 资源标识或未脱敏运行 ID。工作流 `name`、步骤 `id`、工具名、API 字段、错误码等技术契约保留英文，其余说明使用中文。

## 当前结论

验证日期：2026-08-05。

- 17/17 个 workflow 通过本地 YAML、步骤图、安全边界和专用契约校验。
- 17/17 个已配置定义通过 Aevatar 主网 `interactive` explicit-request preview。
- 直接 workflow 运行中，15/17 取得 committed `completed` 终态；12 和 14 取得 committed `failed` 终态及 typed blocker，全部 17 个案例均已有 committed terminal evidence。
- 本地 17/17 个 Ornn skill 与 workflow 字节一致；原有 15/17 个线上 `.1` 版本已 public 并回读，新增两个 skill 尚未发布。
- `/api/chat` 已用自然语言验证 01、12、13、14、15：3/5 取得 committed `completed` 与业务断言，2/5 取得 committed `failed` 与稳定 typed blocker。
- 五个代表案例均按 `ornn_search_skills -> use_skill -> mount approval -> aevatar_start_workflow -> committed observation` 到达可判定终态，未出现重复 tool start call ID。
- `~/workflows` 中除 n8n 外的 41 个可解析定义已按 7 个版本族比较；剩余边界明确落在 `code_execute` 授权、Lark contact 权限、durable schedule、Lark Bot transport、#3161 的 published-operation authority 分支，以及 #3184 的拒绝终止与 durable preview 分支。

`preview`、`202 Accepted`、Assistant 正常结束、模型文案和 pending artifact 都不等于 workflow 成功。逐案例证据见 [生产验证摘要](validation/production-validation-2026-08-05.json)，完整对比见 [分析页面](report/index.html)。

## 工作流矩阵

| # | 工作流 | 步骤 | 主要能力 | 直接生产验证 | 副作用 |
|---:|---|---:|---|---|---|
| 01 | `release_readiness_review` | 13 | `assign`、解析、分支、并行 `foreach` | committed 通过，`ready_for_review=true` | 无 |
| 02 | `candidate_document_compliance_preview` | 3 | 类型化文件、并行 `document_extract`、受约束 LLM | committed 通过，五类材料字段均为 true | 无 |
| 03 | `email_access_approval_audit` | 5 | 审批列表、ID 提取、动态详情 GET | committed 通过，`instance_reachable=true` | 无 |
| 04 | `saas_license_utilization_review` | 10 | 六路 Base 汇聚、确定性利用率与成本聚合 | committed 通过，全部合计命中 | 无 |
| 05 | `asset_inventory_attestation` | 7 | preview/submit、受保护 Base POST | committed 通过，`accepted=true` | 新增一条验收 Base 记录 |
| 06 | `project_shared_mailbox_approval` | 8 | Base GET、审批 POST、实例回读 | committed 通过，回读为 `PENDING` | 创建一条验收审批 |
| 07 | `quarterly_access_review_reminder` | 7 | preview/submit、受保护 Lark 私信 | committed 通过，`message_sent=true` | 发送一条验收私信 |
| 08 | `saas_license_optimization_digest` | 19 | 六路 Base、标准化、摘要、interactive card | committed 通过，六源汇总与卡片发送成功 | 发送一条验收卡片 |
| 09 | `contractor_access_package_approval` | 25 | 附件、LLM、身份目录、历史去重、审批创建与验证 | 创建/回读和幂等复跑均通过 | 诊断期间创建两条同键 `PENDING` 审批 |
| 10 | `monthly_access_certification` | 23 | 月末门禁、聚合、审批、提醒与完成通知 | 月末、跳过、提醒预览和提醒发送均通过 | 创建一条审批并发送两条私信 |
| 11 | `complex_codex_exec_validation` | 32 | 固定 managed probe、五项 gate、receipt 恢复、并行证据 | committed 通过，`parallel_check_count=5` | 无 |
| 12 | `safe_code_execute_validation` | 4 | 固定 JavaScript、结构化 receipt、金额断言 | 平台阻塞，`NYXID_PROXY_UNAUTHORIZED` | 无 |
| 13 | `invoice_ocr_policy_review` | 10 | 合成 PDF、字段提取、SGD/金额归一化、历史去重 | committed 通过，`stateVersion=82` | 无 |
| 14 | `lark_contact_batch_resolution` | 3 | `contact/v3/users/batch_get_id`、标识脱敏 | 平台阻塞，Lark `99991672` | 无 |
| 15 | `weekly_budget_variance_digest` | 11 | 六路 Base、预算差异、周报/月报、schedule 契约 | committed 通过，`stateVersion=73` | 无 |
| 16 | `nyxid_read_receipt_probe` | 4 | 单次 Base GET、provider receipt、首步输出与终态 | committed 通过，`stateVersion=31` | 无 |
| 17 | `lark_post_search_approval_probe` | 4 | 语义只读 POST、typed pending、nested resume | 批准路径 committed 通过，`stateVersion=34` | 无 |

12 和 14 的失败是验收结果，不是缺少测试：两条 run 均进入 workflow 并产生 committed terminal evidence。12 暴露 `chrono-sandbox /execute` 的生产认证契约与 catalog 不一致；14 暴露绑定 Lark Bot 缺少 `contact:user.id:readonly`。

## 新增能力证据

### 12 安全 `code_execute`

固定 JavaScript 只计算合成结算金额，不接收任意代码、路径、凭据或环境变量输入。静态契约和 production preview 通过；真实 run 在 `calculate_settlement` 失败，Observatory committed read model 为 `status=failed`、`stateVersion=12`，错误是 `NYXID_PROXY_UNAUTHORIZED`。因此本仓库覆盖了调用定义和失败诊断，但不能声明生产执行能力可用。

### 13 发票 OCR 与规则审查

使用仓库内合成 PDF/PNG，提取供应商、金额、币种、日期和发票号，断言 `vendor_key=harbor-cloud`、`amount_minor=123450`、`currency=SGD`，并读取审批历史验证精确发票号和同供应商匹配数。真实 run committed `completed`，`stateVersion=82`，没有创建审批。

### 14 Lark contact 批量解析

工作流精确调用 `POST /open-apis/contact/v3/users/batch_get_id`，只输出解析计数和布尔值，不输出真实联系人 ID。真实 run committed `failed`，下游 Lark 返回 `99991672`，缺少 `contact:user.id:readonly`。这证明调用链和错误传播有效，不证明 contact 权限已开通。

### 15 周度/月度预算差异摘要

六路 Base GET 后对合成财务数据计算周度实际、预算、超支与观察类别，并生成四周月度投影。真实 run committed `completed`，`stateVersion=73`；周度 2340/2400、月度 9360/9600、`over_count=1`、`watch_count=1` 均命中。schedule 示例同时提供每周一和每月一日的 Cron，但 schedule API 当前返回 HTTP 502，未产生 schedule receipt。

### 16 NyxID 只读 provider receipt

单次读取验收 Base 的一页记录。Production preview 精确确认一个 `get` 调用点、`effectiveRisk=read_only` 且无需批准；真实 run committed `completed`，`stateVersion=31`，4/4 步完成，首个 tool step 输出非空，最终 artifact 同时包含 `success=true`、`provider_response_verified=true` 和 `side_effects=false`。它回归了 #3161 最初的 managed-workflow `tool_outcome_unknown`，但根据本仓库规则使用 `capability.nyxid_request`，不能替代 `capability.nyxid_operation` 的 authority revalidation 证明。

### 17 POST 搜索批准恢复

调用语义只读的 Lark Base `records/search` POST，不创建或修改记录。Production preview 确认单次 `post`、`effectiveRisk=write`、`approvalRequired=true`；真实 run 收到 typed pending 后，使用 `stepId` 及 nested `toolApproval.executionId/toolCallId/approvalRequestId` 恢复，最终 committed `completed`，`stateVersion=34`，4/4 步完成。首步输出与 approval identity 均非空，artifact 为 `success=true`、`approval_resumed=true`、`side_effects=false`。这证明 #3184 的批准恢复主路径在当前 scope 可用；拒绝终止和 durable preview 仍需独立运行。

## Ornn skills

`skills/` 下有 17 个与 workflow 一一对应的 skill。Ornn 服务端只接受 `SKILL.md`、`scripts/`、`references/`、`assets/` 等根目录，因此 workflow 放在 `assets/*.yaml`。本地同步器保证 asset 与公开 workflow 字节一致。

已完成的生产发布证据：

- 原有 15 个 ZIP 均通过 Ornn `/api/v1/skill-format/validate`；
- 原有 15 个 skill 均上传或更新成功；
- 权限均设置为 public；
- 15 个名称均回读到预期版本和 `isPrivate=false`。

新增 16、17 已通过本地 skill validator，但尚未调用 Ornn 服务端校验或发布。

发布命令：

```bash
ruby scripts/materialize_workflows.rb config.local.yaml
ruby scripts/sync_skills.rb config.local.yaml
ruby scripts/package_skills.rb config.local.yaml
ruby scripts/publish_skills.rb
ruby scripts/publish_skills.rb --verify-only
```

## 自然语言调用示例

以下提示适用于 Lark Bot 或 `/api/chat`。为避免模型只回答业务问题，每条都明确要求搜索 Ornn skill、实际运行 workflow，并以 typed artifact 为准。

| # | 示例提示 |
|---:|---|
| 01 | 帮我做一次上线准备度审查，寻找合适的 Ornn skill，实际运行 workflow，并以 typed artifact 报告结果。 |
| 02 | 检查这组候选人材料是否齐全，使用 Ornn skill 运行材料合规预览，不要输出敏感原文。 |
| 03 | 审计最近一条邮箱访问审批，使用 Ornn skill 读取实例详情，只做只读检查。 |
| 04 | 分析 SaaS 许可证利用率和成本，运行对应 Ornn workflow，给出机器断言。 |
| 05 | 预览资产盘点确认，不要提交；使用 Ornn skill 并报告是否会触发写入。 |
| 06 | 为共享邮箱申请创建审批并回读状态，使用对应 Ornn skill；需要平台批准时先停下。 |
| 07 | 预览季度访问审查提醒，不发送消息，使用 Ornn skill 实际运行 workflow。 |
| 08 | 生成 SaaS 许可证优化摘要，不发送卡片，使用 Ornn skill 并读取 typed artifact。 |
| 09 | 检查外包人员访问资料并判断是否重复，不创建审批，使用对应 Ornn skill。 |
| 10 | 预览本月访问认证结果，不发审批和消息，运行对应 Ornn workflow。 |
| 11 | 运行复杂 codex_exec 验收，只接受 `CODEX_EXEC_READY` 和五项 typed gate 作为成功证据。 |
| 12 | 用安全代码执行验收案例核对合成结算，失败时原样返回 typed blocker。 |
| 13 | 从这张合成发票图片提取字段、归一化金额和日期并检查重复，必须使用 Ornn workflow。 |
| 14 | 把验收入职邮箱解析为 Lark 联系人 ID，只返回成功与数量，缺权限时报告 typed blocker。 |
| 15 | 生成合成预算的周度和月度差异摘要，不发送消息，使用 Ornn skill 并读取 typed artifact。 |
| 16 | 运行 NyxID 只读回执探针，只接受 committed typed artifact，不执行写入。 |
| 17 | 运行语义只读的 Base POST 搜索批准恢复探针；等待 typed pending 后再决定是否批准。 |

可复现 `/api/chat` 验证：

```bash
ruby scripts/assistant_validate.rb --cases 01,12,13,14,15 --approve 01,12,13,14,15
```

`--approve` 只会批准验证器从 current state 匹配到的 typed tool approval，不会批准未声明的工具或案例。验证器只保存哈希、工具名、typed 错误码和脱敏摘要，并显式输出 `chatCompleted`、`workflowValidationStatus`、`workflowValidated`。它不会把 Assistant 回合完成写成 workflow 通过。

## `/api/chat` 与 Lark Bot 的区别

两者会进入相同的 Assistant/AgentRun、工具目录、Ornn 和 workflow 能力，但入口与回传链不同。

| 层次 | `/api/chat` | Lark Bot |
|---|---|---|
| 入站 | 已登录用户经 NyxID 代理直接 POST SSE | Lark webhook 经 NyxID channel relay |
| 身份 | 当前 NyxID 用户和 scope | Bot 注册、会话映射、发送者解析与 agent identity |
| 输入 | 文本和类型化 `inputParts` | Lark 消息、附件与平台事件转换 |
| 回传 | SSE 直接返回调用方 | Agent 回复经 relay 再发送到 Lark |
| 能证明 | Assistant、Ornn、tool、workflow 核心链 | 还需额外证明 webhook、relay、映射和 Lark 回传 |

所以 `/api/chat` 成功仍不能证明 Lark Bot transport 成功；反过来，Lark 中出现一段自然语言回复也不能证明 workflow completed。

## 当前 `/api/chat` 结果

- 01：严格状态 `validated`，13/13 步完成，`ready_for_review=true`，`stateVersion=80`。
- 12：严格状态 `typed-failure`，workflow 已启动并提交 `failed`，`stateVersion=12`，blocker 为 `NYXID_PROXY_UNAUTHORIZED`。
- 13：严格状态 `validated`，图片 file ref 进入真实执行，12/12 步完成，`success=true`，`stateVersion=82`。
- 14：严格状态 `typed-failure`，workflow 已启动并在 `resolve_contact` 提交 `failed`，`stateVersion=15`，blocker 为 `NYXID_PROXY_HTTP_400` / Lark `99991672`。
- 15：严格状态 `validated`，六路 Base 读取与周/月差异断言通过，11/11 步完成，`stateVersion=73`。

五个案例都先搜索 Ornn，再加载精确 skill、完成 typed mount approval、启动 workflow 并读取 committed current state。公开 SSE 中成功工具结果仍可能只有通用 `completed`，所以验证器使用 typed run identity 查询 workflow current state；它不会把 Assistant 文案中的 pending 改写成成功。

issue #3182 的历史症状不能再作为“当前未验证”的替代证据：上述五个代表案例已在生产镜像 `7ba3fa3e` 上重跑。这个结论只覆盖 `/api/chat` 核心链，不覆盖 Lark webhook、NyxID channel relay 和 Lark 回传。

## 配置与本地验证

将 `config.example.yaml` 复制为已忽略的 `config.local.yaml`，替换 16 个占位符，然后执行：

```bash
ruby scripts/materialize_workflows.rb config.local.yaml
ruby scripts/validate_workflows.rb
ruby scripts/sync_skills.rb config.local.yaml
ruby scripts/validate_skills.rb
ruby scripts/package_skills.rb config.local.yaml
ruby scripts/validate_report.rb
```

新增案例的 production preview 与只读运行入口：

```bash
ruby scripts/materialize_workflows.rb config.local.yaml
ruby scripts/production_validate.rb --cases 16,17
ruby scripts/production_validate.rb --cases 16 --run
ruby scripts/production_validate.rb --cases 17 --run --approve-read-only 17 --approve
```

Case 17 必须逐行消费 SSE 并在 pending 出现时立即发送 nested `toolApproval` resume；`202 Accepted` 不是终态成功证据。拒绝路径和 durable preview 需要单独的新 run，不能复用批准路径的终态。

`build/`、`tmp/` 和 `config.local.yaml` 均被忽略。合成附件位于 `fixtures/`，schedule 示例位于 `schedules/`。

## 生产验证边界

- 所有生产请求必须使用 `nyxid proxy request aevatar ...`；不得直连后端、复制 bearer 或借用浏览器 session。
- 一律先 preview。写入分支需要明确的用户意图、允许列表和 typed tool approval。
- 平台工具批准不等于 Lark 业务审批；新建审批通常仍是 `PENDING`。
- 只有 typed receipt、run ID、业务断言和 committed terminal evidence 齐全，才可写成 workflow 通过。
- `code_execute`、contact 和 schedule 的现有阻塞不得通过 mock 成功结果掩盖。
- #3161 已关闭，Case 16 已覆盖共同 receipt/runtime 平面，但不覆盖 published-operation authority 分支；原报告方旧 scope 的最终复测不能由本次正向结果替代。
- #3184 仍开放；Case 17 已证明批准 resume 被运行时消费并 committed 完成，但拒绝终止和 durable preview 仍需独立证据。
- 不得提交 token、真实组织标识、业务载荷、审批表单或未脱敏运行证据。

新增和维护案例的完整规则见 [AGENTS.md](AGENTS.md)。

## 许可证

MIT。`LICENSE` 保留标准英文法律原文。
