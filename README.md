# Aevatar 工作流验收案例

[![验证工作流](https://github.com/eanz17/aevatar-workflow-acceptance-cases/actions/workflows/validate.yml/badge.svg)](https://github.com/eanz17/aevatar-workflow-acceptance-cases/actions/workflows/validate.yml)

本仓库采用“25 个 workflow + 3 个 Lark channel E2E case + 21 个风险验收 case”的口径：25 个公开、安全、可复现的 Aevatar workflow 与 Ornn skill 一一对应；channel case 独立验证 Lark 回调；risk case 验证 catalog、Assistant、源定义、runtime 原语、准入负例和报告一致性。案例覆盖基础原语、文件与图片输入、Lark Bot 入站附件、Base、Lark 审批、Lark 消息、contact、通用代码执行、`codex_exec`、schedule、NyxID provider receipt 和 typed tool approval resume 等能力。

公开 YAML 只保存占位符和合成数据，不包含组织专属 Base、用户、审批、NyxID 资源标识或未脱敏运行 ID。工作流 `name`、步骤 `id`、工具名、API 字段、错误码等技术契约保留英文，其余说明使用中文。

## 当前结论

验证基线日期：2026-08-05；状态更新：2026-08-06。

- 25/25 个 workflow 通过本地 YAML、步骤图、安全边界和专用契约校验；`production_validate.rb` 与 `assistant_validate.rb` 共用 25/25 个严格业务 artifact contract，committed `completed` 本身不再足以判绿。
- 25/25 个已配置定义通过 Aevatar 主网 `interactive` explicit-request preview。旧 01-20 保留既有 committed 基线；21/22/23 在用 `config.local.yaml` 重新物化后 fresh committed `completed`，分别为 7/7、8/8、4/4 且 artifact 精确命中。此前三项同时出现的 `NYXID_PROXY_HTTP_400` 已确认来自共享 `build/workflows/` 被示例配置覆盖，不是 Aevatar 回归；24/25 保留最近一次 5/5、8/8 completed 的 typed approval 证据。
- 新增 21/22/23 无副作用；24/25 在本轮显式授权和 typed approval 下分别完成 1 次、2 次 resume。三轮成功副作用复验累计新增 9 条固定合成前缀的 Base 探针记录，尚未清理；未传 `--allow-side-effects` 时即使指定 `--run` 仍只停在 preview。
- 3/3 个既有 Lark channel E2E case 通过静态契约校验，但仍是 0/3 严格通过；当前部署的额外风险实测见 Risk Case 23/25：拒绝链缺 typed code，另一次 Lark turn 未启动 AgentRun，不能从 direct workflow 的绿色结果外推。
- 案例 19 direct synthetic fixture run 为 committed `completed`、`stateVersion=30`、4/4 步，核心文件登记、抽取与内容契约通过，按设计 `lark_bot_ingress_validated=false`。真实 Lark canary 已证明文件卡片、附件解析和回复 relay，但 `aevatar_start_workflow` 因 current-scope catalog 缺少可启动定义而稳定返回 `service_catalog_missing`，运行目录增量为 0，因此严格状态为 `start-blocked`，不是 Lark workflow E2E 通过。
- 本地 25/25 个 Ornn skill 与 workflow 字节一致，25/25 通过服务端格式校验并按精确名称、版本公开回读。本轮 missing-only 发布只创建并公开了原先缺失的 Case 19 与 21-25 六个 skill，19 个既有精确匹配项未上传、未改权限。
- `/api/chat` 已用自然语言验证 01、12、13、14、15：4/5 取得 committed `completed` 与业务断言，1/5 取得 committed `failed` 与稳定 typed blocker。
- 案例 15 又在生产镜像 `d7844b5e` 上完成 artifact actor identity 回归：Assistant 读取到 committed typed artifact 并明确报告 `Completed`，没有再把最终结果误报为 pending。
- 五个代表案例均按 `ornn_search_skills -> use_skill -> mount approval -> aevatar_start_workflow -> committed observation` 到达可判定终态，未出现重复 tool start call ID。
- 本轮 fresh direct runtime 的固定 managed `codex_exec` 探针 committed `failed`，稳定错误为 `codex_execution_admission_denied`，4/4 已观测步骤后无 final artifact；同批其余基础、文件、`code_execute` 和确定性原语 case 全部严格通过。历史镜像 `f7f543c5` 的恢复证据继续保留，但不能覆盖当前回归。
- 本轮 14 和 17 均真实进入 `awaiting_tool_approval`，验证器从 SSE 取得完整 typed identity 后各 resume 一次，最终 committed 3/3、4/4 且 artifact 命中；旧的“当前运行未观察到 per-run pending/resume”结论已被 fresh 证据取代。
- 当前生产已补充验证 scope 特定的 sandbox bearer 转发修复：单步 `code_execute`、可访问 Base 的 P2 no-send 同类链、exact P1 v5 sanitized image + `submit=false` 均为 committed completed、`lastSuccess=true` 且 final output 非空；既有 PDF attachment probe 2/2 completed 证据继续有效。
- Durable schedule 的完整生产闭环证据来自历史镜像 `b010ba61`；相关修复提交 `748f98e7d`、`7a7781067` 和 `b010ba614` 已包含在当前 `6df43b83` 的提交历史中，但本轮未在当前镜像重跑该副作用链。历史 fresh NyxID 验证先完成六个只读 GET 的 interactive run，取得 11/11 committed `completed` 和精确预算 artifact；随后取得 HTTP 200 `confirmation_required` 与 HTTP 202 typed `pending_binding` receipt，binding committed `succeeded`（state 7）、provisioning committed `succeeded`（state 11），schedule/operation ID 均非空。每分钟 schedule 回读为 enabled，六次真实 cron 触发均完成，`fireCount=6`、`failureCount=0`；抽查 run 为 workflow 11/11 committed `completed`（state 73），六路 Base 与预算断言全部命中。NyxID DELETE 返回 typed accepted receipt 后 list 为空，跨下一分钟 workflow run count 保持 `6 -> 6`。`f7f543c5` 上的 `NyxIdOperationAuthorityContractUnavailable` 只作为历史回归背景保留；POST、WRITE 与 DESTRUCTIVE 仍 fail-closed。编译修复提交 `b010ba614` 的 Release publish、真实 `linux/amd64` Docker build、镜像内 `.NET 10.0.10 linux-x64`、完整架构/稳定性门禁和排除 3 个本机 Redis 版本契约用例后的 solution tests 均通过。
- `~/workflows` 中除 n8n 外的 41 个可解析定义已按 7 个版本族比较；剩余边界明确落在 per-run typed approval、Lark sender binding/channel canary，以及受安全约束未运行的源发送、审批和排程定义。公开案例 15 的 Durable schedule 已通过，不替代未运行的源财务 schedule 分支。
- 风险验收 21 个 case 的已保存严格汇总为：8 passed、4 blocked、4 failed、0 pending-execution、5 not-configured。新增 37-43 将 `workflow_call`、`parallel_fanout`、`race`、P2 send、P1 v6 submit、P1 v2 legacy 和 materialized output 隔离全部转成可追踪 case；21-23 的 provider HTTP 400 已由 Risk 43 的 clean isolated materialization 复验关闭，剩余重点是 Risk 23 的拒绝结果缺 typed code/Run ID 回显、Risk 37 的子工作流定义解析超时，以及 38/39 缺 deterministic probe。
- 已检查 #3161 作者此前在 `aevatarAI/aevatar` 提交的全部 11 条 issue，并用 13、15、16 做新一轮只读 committed 回归；没有为 channel/scheduler 外层缺口复制无效 workflow。详见 [定向回归报告](report/2026-08-05-issue-3161-author-regression.md) 与 [机器摘要](validation/issue-3161-author-regression-2026-08-05.json)。

`preview`、`202 Accepted`、Assistant 正常结束、模型文案和 pending artifact 都不等于 workflow 成功。逐案例证据见 [历史生产验证摘要](validation/production-validation-2026-08-05.json)、[21-25 生产证据](validation/production-validation-2026-08-06-cases-21-25.json) 与 [风险机器摘要](validation/risk-validation-2026-08-06.json)，完整对比见 [分析页面](report/index.html)。

### 本轮验证日志

| 时间（SGT） | 验证层 | 目标 | 结果 | 证据 / blocker | 下一步 |
|---|---|---|---|---|---|
| 2026-08-06 17:32 | 本地静态、打包与报告 | 当前工作树 | 部分通过 | workflow、channel、risk、Ornn skill、脚本语法、Agent skill 双入口、HTML 与 `git diff --check` 通过；`validate_report.rb` 以“分析页缺少新增 workflow 21 的严格通过状态”失败；`config.example.yaml` materialize 后发现 `build/workflows/` 留有一个旧生成文件 | 修复报告覆盖与 materialize 的 stale-output 清理，再重跑完整静态批次 |
| 2026-08-06 17:34 | materialize 定向复验 | `config.example.yaml` / 当前工作树 | 通过 | 已清理不再对应源定义的旧 `*.workflow.yaml`；source/build 文件集合逐字匹配，全部生成 YAML 可解析，脚本语法与 diff 检查通过 | 用 `config.local.yaml` 重新物化后执行全量 production preview；报告状态随 fresh 证据统一更新 |
| 2026-08-06 17:36 | Production explicit-request preview | Aevatar 主网；scope hash `237314c29964` | 通过 | 使用 `config.local.yaml` 物化；动态 registry 中全部 workflow preview 通过，method、path template、risk、approval enforcement 与 execution mode 契约均匹配；未启动 workflow、未产生外部写入 | 执行无副作用及只读批准的 direct runtime 批次 |
| 2026-08-06 17:38 | Direct runtime 定向复验 | Aevatar 主网；21/22/23 | 通过 | 三项分别 committed 7/7、8/8、4/4，`stateVersion` 49/55/31，strict artifact contract 全部命中且无副作用；旧 HTTP 400 未复现 | 更新脱敏机器摘要并继续其余 direct runtime；报告统一撤销该环境假回归 |
| 2026-08-06 17:43 | Direct runtime 基础/文件/执行原语 | Aevatar 主网；01/02/11/12/18/19/20 | 部分通过 | 01/02/12/18/19/20 committed completed 且 strict artifact 命中；11 committed failed，`codex_execution_admission_denied`，无 final artifact；本批无业务写入 | 完成其余 direct runtime 后，核对 case 11 readiness、当前部署和 Aevatar admission/log 证据 |
| 2026-08-06 17:46 | Direct runtime 外部只读与受保护只读 POST | Aevatar 主网；03/04/13/14/15/16/17 | 部分通过 | 03/04/13/14/15/17 committed completed 且 strict artifact 命中；14/17 各取得 1 次 typed pending/resume；16 在创建可判定 run 前遇到 HTTP 502 transport failure | 单独重试 16；不得把 502 记为 workflow typed failure |
| 2026-08-06 17:47 | Direct runtime transport 重试 | Aevatar 主网；16 | 通过 | fresh request committed 4/4，`stateVersion=31`，`provider_response_verified=true`、`side_effects=false`；前次 HTTP 502 未复现 | 将 502 归为已恢复的瞬时 transport 故障，继续 preview-mode direct 分支 |
| 2026-08-06 17:50 | Direct runtime 无副作用业务分支 | Aevatar 主网；05/07/08/09/10 | 通过 | 五项均 committed completed 且 strict artifact 命中；`mutation_executed=false`、`message_sent=false`、`approval_created=false`，未产生外部写入 | 保留 06 的既有 committed 审批证据，避免重复创建不可清理对象；评估并执行可清理写探针 |
| 2026-08-06 17:53 | Direct runtime 写探针证据复核 | Aevatar 主网；24/25 | 通过 | 最近一轮分别 committed 5/5、8/8，typed resume=1/2；三轮成功复验累计新增 9 条固定前缀合成 Base 记录，尚未清理 | 保留脱敏运行事实；未获清理授权前不删除，也不重复写入 |
| 2026-08-06 17:55 | Ornn public catalog verify-only | `ornn-api`；本地打包集合 | 阻塞 | 全部 ZIP 通过服务端格式校验；19 个名称/public/version 精确回读，6 个线上不存在；`uploadsPerformed=false`、`permissionsChanged=false` | 使用正式发布器的 missing-only 模式只补缺失项，再做全量精确回读 |
| 2026-08-06 17:58 | 动态 case 盘点 | 当前工作树与三个仓库边界 | 通过 | 动态发现 25 个 workflow、25 个一一对应 Ornn skill、3 个 channel case、21 个 risk case；新增 Risk 43 已纳入范围；Aevatar 既有工作树为脏，平台修复必须使用最新 `origin/feature/integrate` 的隔离 worktree | 补充正式发布器的 missing-only 模式并只发布 6 个缺失 skill |
| 2026-08-06 18:01 | Ornn missing-only 发布 | `ornn-api`；25 个本地包 | 通过 | 25/25 服务端格式通过；19 个线上名称/version/public 精确匹配并跳过；仅创建并公开原缺失的 6 个 skill，逐项回读一致；README 未保存 GUID | 独立执行全目录 verify-only，确认 25/25 最终 catalog 状态 |
| 2026-08-06 18:02 | Ornn 全目录 verify-only | `ornn-api`；25 个本地包 | 通过 | 正式发布器与独立 catalog 验证器均确认 25/25 服务端格式、名称、version、public 精确一致；missing/private/version mismatch 均为空；未上传、未改权限 | 同步 Risk 27 机器证据和 Markdown/HTML 报告，再诊断 Case 11 |

## 财务源工作流 post-fix 验收

这组结果独立于下方公开案例统计，使用当前 `~/workflows` 源定义、同结构安全变体和脱敏生产输入取得。财务 scope 的同一 run 对照显示 Base 读取成功、随后 `code_execute` 401；源码契约将根因定位为 sandbox UserService 未转发 caller bearer。Aevatar execution delegation 已包含所需执行权限，只调整 sandbox 转发策略且未添加静态 credential。下列结果证明功能主链已在线执行成功，但不代表安全限制下的发送、审批和排程分支也已运行。

| 源定义 | Preview / 输入边界 | 真实终态 | 副作用与结论 |
|---|---|---|---|
| 单步 `code_execute` probe | 新 member；一个固定输出的无副作用步骤 | 单次 invoke，run catalog `0 -> 1`，1/1 completed，`lastSuccess=true`，final output 非空 | scope 特定 sandbox bearer 转发链通过 |
| P2 shared-Base no-send 同结构运行定义 | 基于 `budget_monitor_weekly.shared-base.nosend.yaml` 刷新 live selector，不是当前文件的逐字副本；6 个唯一 GET；全部 read-only；0 approval | 单次 invoke，run catalog `0 -> 1`，8/8 completed，`lastSuccess=true`；首个 Base 输出与 final output 非空 | 未发送消息，未创建 schedule；#3161 `nyxid_proxy -> code_execute` 功能主链通过，不外推到当前文件或旧 Base |
| `invoice_file_chain.v5.workflow.json` | exact JSON；5 个唯一 call site；sanitized PNG；`submit=false` | 只 invoke 一次；14/14 实际步骤 completed，`lastSuccess=true`，final output 非空 | 图片抽取、只读 lookup、preview presentation 通过；完整提交分支未执行，无 approval、无 Lark 写入 |
| PDF attachment probe | 无副作用 PDF 输入 | run catalog +1，2/2 completed，`lastSuccess=true`；extract 与 final output 非空 | PDF 附件接收与抽取主链通过 |

源目录中明确未运行：P2 send workflow、P1 v6、durable/weekly schedule、P1 v2 旧定义，以及修复后的真实 Lark attachment/skill lookup canary。它们不是“没有 case”：分别由 Risk 40、41、30、42 和 Risk 24/channel case 约束。前三个源副作用定义缺一次性目标、显式授权或清理闭环；P1 v2 还需先隔离旧硬编码集成语义。公开验收案例 15 的 schedule 成功不能替代源排程定义证据。

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
| 20 | `supplier_risk_tier_aggregation` | 12 | `map_reduce` 与 `cache` 两个确定性原语 | committed 通过，`stateVersion=89`，15/15 步 | 无 |
| 21 | `approval_window_integrity_audit` | 7 | 审批时间窗口审计、legacy/active 双窗口对照、过期陷阱上报 | clean isolated materialization 后 7/7 completed，`stateVersion=49`，artifact 命中 | 无 |
| 22 | `acceptance_fixture_drift_attestation` | 8 | 四组 canary fixture 只读体检、漂移显式化 | clean isolated materialization 后 8/8 completed，`stateVersion=55`，artifact 命中 | 无 |
| 23 | `readonly_attested_post_probe` | 4 | `risk: read_only` 声明 POST、免运行时审批执行 | clean isolated materialization 后 4/4 completed，`stateVersion=31`，artifact 命中 | 无 |
| 24 | `runtime_tool_approval_write_probe` | 5 | 未声明风险 POST、运行时 tool approval 单次挂起-恢复、写入回执 | committed 通过，`approvalResumeCount=1`，`mutation_executed=true` | 新增一条可清理探针记录 |
| 25 | `sequential_tool_approval_write_probe` | 8 | 一次运行内连续两次审批挂起-恢复组合 | committed 通过，`approvalResumeCount=2`，`sequential_mutations=2` | 新增两条可清理探针记录 |

## Lark channel E2E 矩阵

这三项不是新的 workflow，也不增加 25 个 Ornn skill 的数量。它们复用 Case 14 的 `lark-contact-batch-resolution`，分别覆盖 `/api/chat` 和 direct runtime 无法证明的 Lark AgentRun skill mount 审批，以及 skill 已挂载后的 workflow 运行期工具审批回调边界。

| # | Channel case | 用户决策 | 严格通过条件 | 当前状态 |
|---:|---|---|---|---|
| 20 | `lark_agent_run_skill_approval_approved` | 批准 | 真实 Lark inbound/relay；审批卡可见；`Approval pending` 不进入模型回复；回调精确匹配 run/request/call/hash/sender/scope/conversation 且只分发一次；同一 AgentRun 恢复；`use_skill=Completed`；workflow 只启动一次；取得精确 committed artifact | `pending-execution` |
| 21 | `lark_agent_run_skill_approval_rejected` | 拒绝 | 真实 Lark inbound/relay；审批卡可见；回调只分发一次；同一挂起调用返回 typed `Denied` / `approval_denied`；不执行 mount；workflow start=0；run catalog 增量=0 | `pending-execution` |
| 22 | `lark_workflow_runtime_tool_approval_approved` | 批准 | skill 已挂载且不出现新 mount 审批；workflow start=1；新 run 必须晚于本次 Lark inbound 启动；run 到达 `awaiting_tool_approval`；workflow 审批卡回调精确携带 actor/run/step/execution/tool-call/approval-request identity；同一 workflow run 恢复；最终 artifact 精确命中 | `pending-deployment` |

Case 20/21 的目标修复提交 `9f67c528174ac477bb144d6bd1525444e7c971cf` 已包含在 Ready 生产镜像 `6df43b83` 中，当前仅缺真实 Lark 操作和严格证据，因此状态是 `pending-execution`。Case 22 已提升目标提交到 `3f62ff62bcb32f7fb7c97aea8a7920aadd29d398`，在 Ready 生产 workload 可追溯到该提交前保持 `pending-deployment`。Bot 自然语言、`[tool receipt] Approval pending`、审批卡本身或 direct workflow 成功都不能把 Case 20/21/22 判为通过。

最新全量回归使用部署镜像 `0c4ff023`。其中 11 曾在账号 managed credential 已显示 `execution_ready=true` 的情况下连续两次于 `execute_probe` 以 `codex_execution_admission_denied` 失败；修复镜像 `f7f543c5` 部署后，11 的定向复验已 committed `completed`。12 的连续两次成功证据继续保留。14 和 17 的业务 artifact 均成功，但没有出现 preview 所要求的 per-run typed approval identity，因此不能把终态完成写成严格通过；历史批准路径证据继续保留。

## 可靠性探针系列（workflow 21-25 与 Risk 23-43，2026-08-06）

针对证据不足或容易假绿的边界建立三类 case：可安全重放的能力用 direct workflow；Lark transport/callback 用 channel case；依赖外部副作用目标、不可确定性 runtime 或已知失败的能力用 risk case。当前 `origin/feature/integrate` 与 Ready 镜像均为 `6df43b83`。机器证据：`validation/production-validation-2026-08-06-cases-21-25.json` 与 `validation/risk-validation-2026-08-06.json`。

- 静态校验：25/25 workflow 通过 `validate_workflows.rb`（含 21 窗口常量、23 `risk: read_only` 契约、24/25 探针标记与 `side_effects: true` 诚实断言）；25/25 skill 通过 `validate_skills.rb`；risk-cases 21/21 通过 `validate_risk_cases.rb`。
- Preview：21-25 全部通过 interactive explicit-request preview。关键契约：23 被准入封为 `effectiveRisk=read_only`、`approvalRequired=false`、`approvalEnforcement=none`；24/25 为 `write` + `bind_time_confirmation_and_run_time_tool_approval`（`92cc7bc81` 后的新枚举值，`production_validate.rb` 以双值集合兼容新旧部署并记录实测值）。
- 真实终态按 clean isolated materialization 的最新运行计算为 5/5：21/22/23 分别达到 7/7、8/8、4/4 committed completed 且严格 artifact 命中；24/25 最近一次仍分别以 1 次、2 次 typed approval resume 达到 5/5、8/8 completed。共享 `build/workflows` 被示例配置覆盖时的三次 `NYXID_PROXY_HTTP_400` 只保留为无效物化负面对照，不再作为平台回归。
- 准入探针（`scripts/run_admission_probes.rb`，risk-cases 33-36）：33 缺失 capability 在 provision 即被 `NYXID_OPERATION_SELECTION_REQUIRED` 拒绝（passed）；35 合成 n8n 导出在 preview 被 `Unsupported workflow YAML root field 'nodes'` 类型化拒绝（passed）；36 durable 写准入保持 `DURABLE_AUTHORIZATION_UNAVAILABLE` fail-closed（passed）。**34 已由红转绿并改写期望契约**：平台把 path 拆成两个单义字段——selector 的 `path_template` 必须逐字静态且进入 `request_contract_digest`，运行期只为其中已声明的槽位提供值，值本身允许来自 workflow 表达式（canon `workflow-primitives.md` 的示例即 `{"path_params":{"object_id":"${input}"}}`）。issue #2944 当年被拒的是 legacy 的 raw `path` 运行参数（同一字段既当准入模板又当具体路径），修复方案 #2984 方案 C / PR #2996 明确保留 `path_params` 取值模板化，#3071 的 `nyxid_request` 契约示例同样如此。因此 2026-08-06 的观测（放行到 provider、仅 `NYXID_PROXY_HTTP_400`、无外部写入）是契约一致行为。三条子探针已于 `09:14:57Z` 全部实测：正例槽位取值经准入放行；内联表达式的 `path_template` 在 preview 被 `NYXID_OPERATION_SELECTION_REQUIRED` 拒绝（模板化 selector 匹配不到精确 operation，等价于"selector 必须逐字静态"）；含分隔符与 dot segment 的槽位值在调用 provider 之前被 `NYXID_OPERATION_PATH_PARAMETER_INVALID` 拦下。即"路由由 admitted `path_template` 固定、运行期只能填已声明槽位且槽位不可越段"三条同时成立。
- 维护注记：21 的 active 窗口常量止于 2027-08-03，到期前必须重基线（`validate_workflows.rb` 钉住常量，改动需同步）；24/25 每次真实运行会在资产盘点表新增带 `runtime-approval-probe-` / `sequential-approval-probe-` 前缀的可清理记录，仅在显式 `--allow-side-effects` + `--approve` 下执行。三轮成功复验累计 9 条，本轮未获清理授权。
- 独立多模型审查后的加固（均已在生产重跑复验，24/25 仍 `approvalResumeCount=1/2` 通过，33/35/36 在全新 member 上复现 fail-closed）：preview 契约的多值断言改用显式 `AcceptedValues` 封装，避免把 14/17 的精确数组 `allowedExecutionModes: ["interactive"]` 误判成成员包含而永久判红；`probe_note` 由长度校验升级为 `number()` 数值守卫（bounded 模板只提供 `append/data/date/get/number/json/keys/round`，无 `string.*`，而 `number()` 可解析字符集不含引号、反斜杠与花括号，从而封死注入 tool arguments 的路径），并由 `validate_workflows.rb` 钉住；探针 sanitizer 补齐 Lark `tbl/rec/vew` ID 脱敏并在截断前还原稳定错误码，`validate_risk_cases.rb` 的原始身份扫描同步扩到该 ID 类且覆盖 `validation/` 下全部机器证据；准入探针每轮使用新 nonce 建 member 并对绑定投影延迟重试，避免复用旧绑定或把传输层失败误记为"平台已拦截"。

| Risk Case | 验证目标 | 严格状态 | 关键证据 / 缺口 |
|---:|---|---|---|
| 23 | Lark workflow 工具拒绝 | `failed` | committed failed，但无 typed `approval_denied`；Bot 回显完整 Run ID，卡片按钮未失效 |
| 24 | Lark 附件经 catalog 启动 | `blocked` | Case 19 skill 未 public；未重复上传、未自动发布 |
| 25 | Lark sender service scope | `failed` | 消息可见，但 AgentRun/workflow run 增量均为 0，`CHANNEL_AGENT_RUN_NOT_STARTED` |
| 26 | `/api/chat` 安全 code_execute | `failed` | 原入口以 `NYXID_PROXY_UNAUTHORIZED` failed；配置修正后 direct member-stream 单步已通过，但 `/api/chat` 原 case 未重跑，不能借用证据改判 |
| 27 | Ornn public catalog 完整性 | `passed` | 25/25 格式、精确名称、version 与 public readback 全部一致，独立 verify-only 未做写入 |
| 28 | 当前部署精确源 P1 v5 `submit=false` | `passed` | exact source + sanitized PNG 只 invoke 一次；14/14 completed，写入/审批分支未执行 |
| 29 | P2 四表 schema 保真 no-send | `not-configured` | 未配置 disposable 合成财务表，拒绝 shared Base 语义替代 |
| 30 | 源 no-send Durable schedule cleanup | `not-configured` | 源 target/authority 未配置，公开 Case 15 不作替代 |
| 31 | 全 direct artifact contract | `passed` | 25/25 strict contracts，Assistant 复用同一契约 |
| 32 | 报告与仓库计数一致性 | `passed` | workflow、skill、contract、README、Markdown、HTML、机器摘要统一为 25 |
| 33 | 缺 capability 的 provision 准入 | `passed` | `NYXID_OPERATION_SELECTION_REQUIRED` fail-closed，无外部写入 |
| 34 | path 槽位契约（路由由 template 固定） | `passed` | 三条子探针实测：槽位取值放行且路由未改写（仅 provider 侧 `NYXID_PROXY_HTTP_400`）；模板化 selector 被 `NYXID_OPERATION_SELECTION_REQUIRED` 拒绝；越段槽位值被 `NYXID_OPERATION_PATH_PARAMETER_INVALID` 拦下；无外部写入 |
| 35 | n8n 导出摄入拒绝 | `passed` | preview 类型化拒绝 root field `nodes` |
| 36 | Durable write fail-closed | `passed` | `DURABLE_AUTHORIZATION_UNAVAILABLE`；interactive 对照可准入 |
| 37 | `workflow_call` inline definition resolution | `failed` | 历史真实 run 在 30 秒 definition resolution 超时后 failed；Studio provision 入口未携带 inline 子定义 |
| 38 | `parallel_fanout` 确定性 runtime | `blocked` | worker step 被模块硬编码为 `llm_call`，无法构造不含模型随机性的生产断言 |
| 39 | `race` 确定性 runtime | `blocked` | race 分支同样硬编码 `llm_call`，首成功/迟到完成时序无法稳定复现 |
| 40 | 源 P2 send | `not-configured` | exact source/hash 已钉住；缺一次性接收目标和本次显式发送授权，未执行 |
| 41 | 源 P1 v6 submit | `not-configured` | exact source/hash 已钉住；缺安全合成审批目标与清理方案，未执行 |
| 42 | 源 P1 v2 legacy | `not-configured` | exact source/hash 已钉住；旧 `code_execute` 集成语义与硬编码目标尚未隔离，未执行 |
| 43 | materialized workflow 输出隔离 | `passed` | example/local 分别输出到独立目录；stale 文件清理、源/产物集合一致，isolated local 目录的 21-23 preview 全部通过 |

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

`skills/` 下有 25 个与 workflow 一一对应的 skill。Ornn 服务端只接受 `SKILL.md`、`scripts/`、`references/`、`assets/` 等根目录，因此 workflow 放在 `assets/*.yaml`。本地同步器保证 asset 与公开 workflow 字节一致。

截至 2026-08-06 的 missing-only 发布证据：

- 25/25 个 ZIP 均通过 Ornn `/api/v1/skill-format/validate`；
- 原 19 个名称回读到预期版本和 `isPrivate=false` 后精确跳过；
- 只创建并公开原先缺失的 `lark-bot-file-upload-validation` 和本轮新增五个 skill；
- 新增 6 个逐项回读名称、版本和 `isPrivate=false` 一致，未记录 GUID。
- 发布后的正式 verify-only 与独立 catalog 验证器均确认 25/25 精确一致，缺失、private 和版本不匹配集合均为空。

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
| 20 | 运行无副作用的供应商风险分档汇总，覆盖 map_reduce 与 cache 两个确定性原语。 |

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
ruby scripts/validate_channel_cases.rb
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
- Case 20/21 分别覆盖 #3210 的 skill mount 批准和拒绝路径；Case 22 覆盖 skill 已挂载后的 workflow 运行期工具批准路径。提交 `9f67c5281` 已随当前镜像部署，三项现为 `pending-execution`；仍需真实 Lark 审批卡、对应层级的精确 callback identity 和 typed receipt/committed artifact 证据，不能用 Bot 文案或 direct Case 14 结果代替。
- 不得提交 token、真实组织标识、业务载荷、审批表单或未脱敏运行证据。

新增和维护案例的完整规则见 [AGENTS.md](AGENTS.md)。

## 许可证

MIT。`LICENSE` 保留标准英文法律原文。
