# Aevatar 工作流验收案例

[![验证工作流](https://github.com/eanz17/aevatar-workflow-acceptance-cases/actions/workflows/validate.yml/badge.svg)](https://github.com/eanz17/aevatar-workflow-acceptance-cases/actions/workflows/validate.yml)

本仓库提供 19 个公开、安全、可复现的 Aevatar workflow，以及与它们一一对应的 Ornn skill。案例覆盖基础原语、文件与图片输入、Lark Bot 入站附件、Base、Lark 审批、Lark 消息、contact、通用代码执行、`codex_exec`、schedule、NyxID provider receipt 和 typed tool approval resume 等能力，并使用不同于源目录的实际业务场景。

公开 YAML 只保存占位符和合成数据，不包含组织专属 Base、用户、审批、NyxID 资源标识或未脱敏运行 ID。工作流 `name`、步骤 `id`、工具名、API 字段、错误码等技术契约保留英文，其余说明使用中文。

## 当前结论

验证基线日期：2026-08-05；状态更新：2026-08-06。

- 19/19 个 workflow 通过本地 YAML、步骤图、安全边界和专用契约校验。
- 19/19 个已配置定义通过 Aevatar 主网 `interactive` explicit-request preview；案例 19 preview 为 0 个外部 call site。
- 最近一次回归在生产镜像 `20d9ba41` 上覆盖 01-05、07-19 共 18 个案例，均取得 committed `completed` 与业务 artifact 断言；案例 06 会真实创建 Lark 审批，本轮未重跑，沿用 `0c4ff023` 的既有证据并已在表中标注。当前验收脚本对 14、16、17、18、19 强制 typed artifact 契约；其余案例的 artifact 由人工逐条复核。
- 案例 19 direct synthetic fixture run 为 committed `completed`、`stateVersion=30`、4/4 步，核心文件登记、抽取与内容契约通过，按设计 `lark_bot_ingress_validated=false`。真实 Lark canary 已证明文件卡片、附件解析和回复 relay，但 `aevatar_start_workflow` 因 current-scope catalog 缺少可启动定义而稳定返回 `service_catalog_missing`，运行目录增量为 0，因此严格状态为 `start-blocked`，不是 Lark workflow E2E 通过。
- 本地 19/19 个 Ornn skill 与 workflow 字节一致；原有 15 个线上 `.1` 版本已 public 并回读，新增的 16、17、18、19 四个 skill 尚未发布。
- `/api/chat` 已用自然语言验证 01、12、13、14、15：4/5 取得 committed `completed` 与业务断言，1/5 取得 committed `failed` 与稳定 typed blocker。
- 案例 15 又在生产镜像 `d7844b5e` 上完成 artifact actor identity 回归：Assistant 读取到 committed typed artifact 并明确报告 `Completed`，没有再把最终结果误报为 pending。
- 五个代表案例均按 `ornn_search_skills -> use_skill -> mount approval -> aevatar_start_workflow -> committed observation` 到达可判定终态，未出现重复 tool start call ID。
- 源财务 P2 no-send、P1 v5 sanitized image + `submit=false` 和 PDF attachment probe 的既有 `71a38ff5` 证据分别为 8/8、14/14、2/2 completed，均有 `lastSuccess=true` 和非空 final output。
- Durable schedule 修复提交 `748f98e7d` 的 actor-owned provisioning 链和 `7a7781067` 的 binder-attested 只读窄放行均包含在当前生产镜像 `b010ba61`。2026-08-06 SGT 的 fresh NyxID 验证先完成六个只读 GET 的 interactive run，取得 11/11 committed `completed` 和精确预算 artifact；随后取得 HTTP 200 `confirmation_required` 与 HTTP 202 typed `pending_binding` receipt，binding committed `succeeded`（state 7）、provisioning committed `succeeded`（state 11），schedule/operation ID 均非空。每分钟 schedule 回读为 enabled，六次真实 cron 触发均完成，`fireCount=6`、`failureCount=0`；抽查 run 为 workflow 11/11 committed `completed`（state 73），六路 Base 与预算断言全部命中。NyxID DELETE 返回 typed accepted receipt 后 list 为空，跨下一分钟 workflow run count 保持 `6 -> 6`。`f7f543c5` 上的 `NyxIdOperationAuthorityContractUnavailable` 只作为历史回归背景保留；POST、WRITE 与 DESTRUCTIVE 仍 fail-closed。编译修复提交 `b010ba614` 已普通推送 `origin/feature/integrate`，Release publish、真实 `linux/amd64` Docker build、镜像内 `.NET 10.0.10 linux-x64`、完整架构/稳定性门禁和排除 3 个本机 Redis 版本契约用例后的 solution tests 均通过。
- `~/workflows` 中除 n8n 外的 41 个可解析定义已按 7 个版本族比较；剩余边界明确落在 per-run typed approval、Lark sender binding/channel canary，以及受安全约束未运行的源发送、审批和排程定义。公开案例 15 的 Durable schedule 已通过，不替代未运行的源财务 schedule 分支。
- 已检查 #3161 作者此前在 `aevatarAI/aevatar` 提交的全部 11 条 issue，并用 13、15、16 做新一轮只读 committed 回归；没有为 channel/scheduler 外层缺口复制无效 workflow。详见 [定向回归报告](report/2026-08-05-issue-3161-author-regression.md) 与 [机器摘要](validation/issue-3161-author-regression-2026-08-05.json)。

`preview`、`202 Accepted`、Assistant 正常结束、模型文案和 pending artifact 都不等于 workflow 成功。逐案例证据见 [生产验证摘要](validation/production-validation-2026-08-05.json)，完整对比见 [分析页面](report/index.html)。

## 财务源工作流 post-fix 验收

这组结果独立于下方公开案例统计，使用当前 `~/workflows` 源定义和脱敏生产输入取得。它们证明功能主链已在线执行成功，但不代表安全限制下的发送、审批和排程分支也已运行。

| 源定义 | Preview / 输入边界 | 真实终态 | 副作用与结论 |
|---|---|---|---|
| `budget_monitor_weekly.shared-base.nosend.yaml` | exact YAML；6 个唯一 GET；全部 read-only；0 approval | 单次 invoke，run catalog +1，8/8 completed，`lastSuccess=true`；首个 Base 输出与 final output 非空 | 未发送消息，未创建 schedule；#3161 authority/receipt 主链通过 |
| `invoice_file_chain.v5.workflow.json` | exact JSON；5 个唯一 call site；sanitized PNG；`submit=false` | 一次瞬时 524 经无副作用单步探针对照后仅重跑一次；最终 14/14 实际步骤 completed，`lastSuccess=true`，final output 非空 | 图片抽取、只读 lookup、preview presentation 通过；提交三步未执行，无 approval、无 Lark 写入 |
| PDF attachment probe | 无副作用 PDF 输入 | run catalog +1，2/2 completed，`lastSuccess=true`；extract 与 final output 非空 | PDF 附件接收与抽取主链通过 |

源目录中明确未运行：P2 send workflow、P1 v6、durable/weekly schedule、P1 v2 旧定义，以及修复后的真实 Lark attachment/skill lookup canary。前四项受安全或 authority 边界限制；公开验收案例 15 的 schedule 成功不能替代源排程定义证据。最后一项仍是 `#3087` 的独立 channel E2E 缺口，不能从 `/api/chat` 或 member invoke 外推。

## 工作流矩阵

| # | 工作流 | 步骤 | 主要能力 | 直接生产验证 | 副作用 |
|---:|---|---:|---|---|---|
| 01 | `release_readiness_review` | 13 | `assign`、解析、分支、并行 `foreach` | committed 通过，`ready_for_review=true` | 无 |
| 02 | `candidate_document_compliance_preview` | 3 | 类型化文件、并行 `document_extract`、受约束 LLM | committed 通过，五类材料字段均为 true | 无 |
| 03 | `email_access_approval_audit` | 5 | 审批列表、ID 提取、动态详情 GET | committed 通过，`instance_reachable=true` | 无 |
| 04 | `saas_license_utilization_review` | 10 | 六路 Base 汇聚、确定性利用率与成本聚合 | committed 通过，全部合计命中 | 无 |
| 05 | `asset_inventory_attestation` | 7 | preview/submit、受保护 Base POST | 最新 preview 分支 completed，`mutation_executed=false` | 无；历史 submit 分支另有通过证据 |
| 06 | `project_shared_mailbox_approval` | 8 | Base GET、审批 POST、实例回读 | committed 通过，回读为 `PENDING`，`stateVersion=55` | 创建一条合成验收审批 |
| 07 | `quarterly_access_review_reminder` | 7 | preview/submit、受保护 Lark 私信 | 最新 preview 分支 completed，`message_sent=false` | 无；历史 submit 分支另有通过证据 |
| 08 | `saas_license_optimization_digest` | 19 | 六路 Base、标准化、摘要、interactive card | 最新 preview 分支 completed，六源汇总正确 | 无；未发送卡片 |
| 09 | `contractor_access_package_approval` | 25 | 附件、LLM、身份目录、历史去重、审批创建与验证 | 最新 preview 分支 completed，`approval_created=false` | 无；历史 submit/idempotent 分支另有通过证据 |
| 10 | `monthly_access_certification` | 23 | 月末门禁、聚合、审批、提醒与完成通知 | 最新 preview 分支 completed，审批和消息均未创建 | 无；历史写入分支另有通过证据 |
| 11 | `complex_codex_exec_validation` | 32 | 固定 managed probe、五项 gate、receipt 恢复、并行证据 | committed 通过，30/30 步，`parallel_check_count=5` | 无 |
| 12 | `safe_code_execute_validation` | 4 | 固定 JavaScript、结构化 receipt、金额断言 | 连续两次 committed 通过，`total_cents=16623` | 无 |
| 13 | `invoice_ocr_policy_review` | 10 | 合成 PDF、字段提取、SGD/金额归一化、历史去重 | committed 通过，`stateVersion=82` | 无 |
| 14 | `lark_contact_batch_resolution` | 3 | `contact/v3/users/batch_get_id`、标识脱敏 | committed 通过，`stateVersion=25`；preview `approvalEnforcement=bind_time_confirmation` | 无 |
| 15 | `weekly_budget_variance_digest` | 11 | 六路 Base、预算差异、周报/月报、schedule 契约 | committed 通过，`stateVersion=73` | 无 |
| 16 | `nyxid_read_receipt_probe` | 4 | 单次 Base GET、provider receipt、首步输出与终态 | committed 通过，`stateVersion=31` | 无 |
| 17 | `lark_post_search_approval_probe` | 4 | 语义只读 POST、bind-time 批准契约、nested resume | committed 通过，`stateVersion=31`；preview `approvalEnforcement=bind_time_confirmation` | 无 |
| 18 | `supplier_control_attestation_review` | 15 | `guard`、`conditional`、`while` 三个确定性原语 | committed 通过，`stateVersion=92`，15/15 步 | 无 |
| 19 | `lark_bot_file_upload_validation` | 3 | Lark 入站 file ref、单次 `document_extract`、SHA-256 与 transport 证据分层 | preview 通过；direct committed 4/4，`stateVersion=30`；Lark canary `start-blocked` | `service_catalog_missing`；附件 transport 已验证，workflow 未启动 |

最新全量回归使用部署镜像 `0c4ff023`。其中 11 曾在账号 managed credential 已显示 `execution_ready=true` 的情况下连续两次于 `execute_probe` 以 `codex_execution_admission_denied` 失败；修复镜像 `f7f543c5` 部署后，11 的定向复验已 committed `completed`。12 的连续两次成功证据继续保留。14 和 17 的业务 artifact 均成功，但没有出现 preview 所要求的 per-run typed approval identity，因此不能把终态完成写成严格通过；历史批准路径证据继续保留。

## 新增能力证据

### 11 managed `codex_exec`

固定 probe 与公开 canonical sample payload 完全一致，账号 readiness 为 enabled、eligible、active、`execution_ready=true`。历史镜像 `0c4ff023` 上两次真实运行都在 `execute_probe` 以 `codex_execution_admission_denied` committed failed；根因是 Aevatar 把 managed Agent Key 放入 `Authorization: Bearer`，NyxID 的 `forward_access_token` 策略漂移后又把同一 bearer 转发到 chrono-sandbox。提交 `f7f543c51` 改为专用 `X-API-Key` 入口认证并保持 `Authorization` 缺失。镜像 `f7f543c5` 上的定向复验 committed `completed`，`stateVersion=179`，30/30 步完成，固定输出 `CODEX_EXEC_READY`、五项 typed gate、脱敏 `diagnostic_id` 与 `parallel_check_count=5` 全部命中，`side_effects=false`。

### 12 安全 `code_execute`

固定 JavaScript 只计算合成结算金额，不接收任意代码、路径、凭据或环境变量输入。静态契约和 production preview 通过；最新镜像上连续两次真实运行均 committed `completed`，`stateVersion=31`，4/4 步完成，最终 artifact 精确命中 `structured_receipt=true`、`total_cents=16623`、`side_effects=false`。

### 13 发票 OCR 与规则审查

使用仓库内合成 PDF/PNG，提取供应商、金额、币种、日期和发票号，断言 `vendor_key=harbor-cloud`、`amount_minor=123450`、`currency=SGD`，并读取审批历史验证精确发票号和同供应商匹配数。真实 run committed `completed`，`stateVersion=82`，没有创建审批。

### 14 Lark contact 批量解析

工作流精确调用 `POST /open-apis/contact/v3/users/batch_get_id`，只输出解析计数和布尔值，不输出真实联系人 ID。最新 run committed `completed`，`stateVersion=25`，3/3 步完成，业务 artifact 仍正确；但 preview 明确 `approvalRequired=true`，本轮却没有观察到 typed pending/resume，所以严格判定为 `TOOL_APPROVAL_IDENTITY_NOT_OBSERVED`。镜像 `8cf280e2` 上 state 28 的历史批准路径仍保留为对照证据。

### 15 周度/月度预算差异摘要

六路 Base GET 后对合成财务数据计算周度实际、预算、超支与观察类别，并生成四周月度投影。镜像 `b010ba61` 上的直接 run committed `completed`，`stateVersion=73`；周度 2340/2400、月度 9360/9600、`over_count=1`、`watch_count=1` 均命中。schedule 示例仍提供每周一和每月一日的正式 Cron，本次生产 canary 使用每分钟 Cron 完成 confirmation、HTTP 202 typed receipt、binding/provisioning committed success 与 schedule 回读。六次真实 cron 触发均无失败，抽查 workflow 11/11 committed `completed`，最终 artifact 与直接运行断言一致；DELETE 后 list 消失，跨下一分钟 run count 未增长。

### 16 NyxID 只读 provider receipt

单次读取验收 Base 的一页记录。Production preview 精确确认一个 `get` 调用点、`effectiveRisk=read_only` 且无需批准；真实 run committed `completed`，`stateVersion=31`，4/4 步完成，首个 tool step 输出非空，最终 artifact 同时包含 `success=true`、`provider_response_verified=true` 和 `side_effects=false`。它回归了 #3161 最初的 managed-workflow `tool_outcome_unknown`；随后源 P2 no-send 又补齐了 published-operation authority 分支的 6 个只读调用和 8/8 committed 完成证据。

### 17 POST 搜索批准恢复

调用语义只读的 Lark Base `records/search` POST，不创建或修改记录。Production preview 仍确认单次 `post`、`effectiveRisk=write`、`approvalRequired=true`；最新 run 却未出现 typed pending/resume 即 committed `completed`，`stateVersion=31`。即使 artifact 写有 `approval_resumed=true`，也不能替代运行时身份链证据，因此严格判定为 `TOOL_APPROVAL_IDENTITY_NOT_OBSERVED`。历史 state 34 run 曾完整消费 nested `toolApproval`，继续保留；当前回归使拒绝路径不可达，durable preview 仍未验证。

### 19 Lark Bot 文件上传验证

使用仓库内 114 字节合成 JSON，通过 `input_file_refs -> document_extract` 验证文件名、媒体类型、字节数和固定 SHA-256，全程不调用 Lark 写接口。Production preview 已通过且为 0 个外部 call site；direct run committed `completed`、`stateVersion=30`、4/4 步，`file_ref_registered=true`、`document_extract_succeeded=true`、`content_contract_matches=true`，并按入口分层得到 `lark_bot_ingress_validated=false`。真实 Lark Bot canary 已观察到文件卡片、合成内容解析和回复 relay，但三次启动尝试均以稳定 `service_catalog_missing` 在 workflow 创建前终止，运行目录增量为 0。因而当前结论是“核心文件链通过、Lark 附件 transport 已验证、Lark workflow `start-blocked`”；没有 committed `lark_bot_ingress_validated=true`，不能写成 Lark workflow E2E 通过。公开摘要不保存文件消息、resource key 或其他 opaque ID。

## Ornn skills

`skills/` 下有 19 个与 workflow 一一对应的 skill。Ornn 服务端只接受 `SKILL.md`、`scripts/`、`references/`、`assets/` 等根目录，因此 workflow 放在 `assets/*.yaml`。本地同步器保证 asset 与公开 workflow 字节一致。

已完成的生产发布证据：

- 原有 15 个 ZIP 均通过 Ornn `/api/v1/skill-format/validate`；
- 原有 15 个 skill 均上传或更新成功；
- 权限均设置为 public；
- 15 个名称均回读到预期版本和 `isPrivate=false`。

新增 16、17、18、19 已通过本地 skill validator，但尚未调用 Ornn 服务端校验或发布。

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
| 17 | 运行语义只读的 Base POST 搜索批准恢复探针；批准由 bind 时的 explicit-request confirmation 兑现。 |
| 18 | 运行无副作用的供应商控制项自证审查，覆盖 guard、conditional 与 while 三个确定性原语。 |
| 19 | 验证当前消息中的 `lark-bot-upload-manifest.json`，运行对应 Ornn workflow；只有 typed artifact 的 `lark_bot_ingress_validated=true` 才报告 Lark Bot 入站通过。 |

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

所以 `/api/chat` 成功仍不能外推 Lark Bot transport；反过来，Lark 中出现回复也不能证明 workflow completed。17:44 的 Aevatar Bot 实测已经补齐 transport 证据：NyxID committed Bot 为 `active`、`webhook_registered=true`，生产日志观察到 inbound callback、发送者绑定、channel agent run、Ornn 搜索、Lark 回传和 conversation turn completed。该次 workflow 本身未通过，Bot 返回 skill mount、`AgentNotFound` 和 capability admission 三类失败回执。

失败后在生产镜像 `8cf280e2` 上重新验证：案例 14 直接 run 与 `/api/chat` 的 Ornn mount/run 均 committed `completed`、3/3，artifact 为 `success=true`。随后两次 Lark Bot 重试都真实启动 workflow、进入 `awaiting_tool_approval` 且接受 typed resume，最终均在 `resolve_contact` 以 `NYXID_PROXY_SERVICE_SCOPE_FORBIDDEN` committed `failed`；run 哈希分别为 `1436a2852f8d`（当前 `stateVersion=18`）和 `e491a2690b03`（`stateVersion=17`）。生产 `aevatar` Developer App 随后保留原有四个默认项并追加 `api-lark-bot`。fresh `/init` 已在 `11:34Z` 生成新的 allow-all consent 与 sender binding，但镜像 `e30fdd94` 上的新 run `93ece1c36951` 仍在 `resolve_contact` 以同一稳定错误码 committed `failed`（`stateVersion=14`）。源码契约核对解释了这一结果：Aevatar authorize URL 显式携带 Aevatar、LLM、Ornn 和 Sandbox resource，未携带 Lark；NyxID 会把授权码与 binding 缩窄到显式 resource，即使 consent 是 allow-all。`default_service_catalog_slugs` 只影响 consent 提示/预选，不能扩展 authorization-code resource grant。因此当前结论是“transport 与审批恢复已验证，fresh `/init` 已复现平台 resource-narrowing blocker”，不是 Lark Bot 全链 PASS。channel-only 还同时保留 `ornn.skill` mount failure、`scope_workflows_get/list` outcome unverified，以及后续 fallback 的 `InvalidWorkflowYaml`，不能把其他启动成功外推为这些辅助工具健康。

## 当前 `/api/chat` 结果

- 01：严格状态 `validated`，13/13 步完成，`ready_for_review=true`，`stateVersion=80`。
- 12：严格状态 `typed-failure`，workflow 已启动并提交 `failed`，`stateVersion=12`，blocker 为 `NYXID_PROXY_UNAUTHORIZED`。
- 13：严格状态 `validated`，图片 file ref 进入真实执行，12/12 步完成，`success=true`，`stateVersion=82`。
- 14：严格状态 `validated`，workflow committed `completed`，`stateVersion=28`，3/3 步完成，`success=true`、`resolved_count=1` 且联系人标识未回显。Assistant 最终文案仍误写为 pending，严格判定只采用 committed artifact。
- 15：在生产镜像 `d7844b5e` 上严格状态 `validated`，六路 Base 读取与周/月差异断言通过，11/11 步完成，`stateVersion=73`。Assistant 最终读取并报告 committed typed artifact，`artifactPendingReportedAsFinal=false`。

五个案例都先搜索 Ornn，再加载精确 skill、完成 typed mount approval、启动 workflow 并读取 committed current state。公开 SSE 中成功工具结果仍可能只有通用 `completed`，所以验证器使用 typed run identity 查询 workflow current state；它不会把 Assistant 文案中的 pending 改写成成功。

issue #3182 的历史症状不能再作为“当前未验证”的替代证据：五个代表案例已在生产镜像 `7ba3fa3e` 上重跑，案例 14 在 `8cf280e2` 上完成 Ornn mount/run 复测，案例 15 又在 `d7844b5e` 上关闭短 run ID 到 artifact actor identity 的最终 pending 误报。Lark webhook、NyxID channel relay 和 Lark 回传已由 17:44 的独立 Bot 消息验证；新镜像 Bot 重试也已取得 committed 终态，但当前因 sender binding 的 Lark UserService grant 缺失而失败。

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
ruby scripts/production_validate.rb --cases 16,17,19
ruby scripts/production_validate.rb --cases 16 --run
ruby scripts/production_validate.rb --cases 17 --run --approve-read-only 17 --approve
ruby scripts/production_validate.rb --cases 19 --run
```

Case 17 必须逐行消费 SSE 并在 pending 出现时立即发送 nested `toolApproval` resume；`202 Accepted` 不是终态成功证据。如果 preview 要求批准但运行没有产生 typed pending，必须记为契约回归，不能用 artifact 的 `approval_resumed=true` 代替。拒绝路径和 durable preview 需要单独的新 run。

Case 19 的 `--run` 使用 direct synthetic fixture，只能验证文件登记、抽取与内容契约，预期 `lark_bot_ingress_validated=false`。本轮真实 canary 已在 Lark Bot 会话上传同一 fixture 并取得附件解析与回复 relay，但由于 19 的 Ornn skill 尚未发布，current-scope catalog 没有可启动定义，`aevatar_start_workflow` 稳定返回 `service_catalog_missing`，没有新增 run。只有后续 canary 从 committed typed artifact 读取到 `lark_bot_ingress_validated=true` 才能升级为通过；Bot 回复文案、文件卡片或 direct run 均不能替代该证据。

`build/`、`tmp/` 和 `config.local.yaml` 均被忽略。合成附件位于 `fixtures/`，schedule 示例位于 `schedules/`。

## 生产验证边界

- 所有生产请求必须使用 `nyxid proxy request aevatar ...`；不得直连后端、复制 bearer 或借用浏览器 session。
- 一律先 preview。写入分支需要明确的用户意图、允许列表和 typed tool approval。
- 平台工具批准不等于 Lark 业务审批；新建审批通常仍是 `PENDING`。
- 只有 typed receipt、run ID、业务断言和 committed terminal evidence 齐全，才可写成 workflow 通过。
- managed `codex_exec`、typed approval 和 schedule 的现有边界不得通过 mock 成功结果或业务 artifact 掩盖；contact 的业务成功必须同时核对批准身份链与脱敏断言。
- #3161 已关闭；Case 16 覆盖共同 receipt/runtime 平面，源 P2 no-send 又在当前部署上覆盖 published-operation authority 主链并 committed 完成。该结论只适用于 no-send 只读执行，不外推到消息发送或 durable schedule。
- #3184 仍开放；Case 17 的历史 run 证明过批准 resume，但最新 `0c4ff023` run 未观察到 typed pending/resume，当前记为契约回归。拒绝路径在此状态下不可达，durable preview 仍需独立证据。
- Case 19 已有静态、preview、direct committed 与 Lark 文件 transport 证据；direct fixture 和 Bot 附件解析都不证明 Lark workflow committed 成功。当前 `service_catalog_missing` / run 增量 0 必须保持为 `start-blocked`，直到 typed artifact 明确给出 `lark_bot_ingress_validated=true`。
- 不得提交 token、真实组织标识、业务载荷、审批表单或未脱敏运行证据。

新增和维护案例的完整规则见 [AGENTS.md](AGENTS.md)。

## 许可证

MIT。`LICENSE` 保留标准英文法律原文。
