# 工作流验证与能力覆盖报告

报告基线日期：2026-08-05；状态更新：2026-08-06（生产镜像 `20d9ba41`）。

## 路径与统计口径

用户最初提到的 `~/Code/workflows` 当前不存在。本报告实际比较：

- 验收仓库：`/Users/chronoai/Code/aevatar-workflow-acceptance-cases`；
- 源目录：`/Users/chronoai/workflows`。

源目录共有 43 个带 workflow 形态的可解析定义，其中两个是带 `nodes/connections` 契约的 n8n JSON。本轮按要求排除 n8n，只比较其余 41 个定义。41 个定义包含旧版本、派生版本和 Ornn 内嵌副本，不能用文件数直接计算功能覆盖率；本报告将它们归并为 7 个版本族。

## 总结

- 19/19 个公开 workflow 通过本地静态校验和 production explicit-request preview。
- 另有 3 个 Lark channel E2E case 通过静态契约校验，但生产严格结果为 0/3；Case 20/21/22 都是 `pending-deployment`，不计入 19 个 workflow 或 19 个 Ornn skill。
- 镜像 `20d9ba41` 上已重跑 01-05、07-19 共 18 个案例，全部 committed `completed`；连同案例 06 的既有证据，19 个案例的 direct runtime 最新终态均为 committed `completed`。案例 06 会真实创建 Lark 审批，本轮未重跑，其证据仍来自 `0c4ff023`。
- 本地 19/19 个 Ornn skill 与 workflow 一一对应；原有 15 个通过服务端格式校验并公开回读，新增的 16、17、18、19 尚未发布。
- 13 已补齐合成图片/PDF、发票字段归一化与财务去重规则；14 精确覆盖 Lark contact API；15 补齐预算周报/月报公式与 schedule 契约；16、17 分别针对 #3161 和 #3184 增加最小回归探针。
- `/api/chat` 自然语言验证 5 个代表案例，4 个取得 committed `completed` 和业务断言，1 个取得 committed `failed` 和稳定 typed blocker。
- 五个案例均按 search-first 顺序经过精确 skill 加载、typed mount approval、workflow 启动和 committed observation，重复 tool start call ID 为 0。
- `/api/chat` 与 Lark Bot 共用 Assistant/Ornn/workflow 核心；Lark Bot 已独立覆盖 webhook、NyxID channel relay、会话映射、Lark 回传和 typed approval resume。Developer App 默认项追加 `api-lark-bot` 后的 fresh `/init` 已完成，但第三次新镜像重试仍在 `resolve_contact` 以 `NYXID_PROXY_SERVICE_SCOPE_FORBIDDEN` committed failed；根因已收敛到 authorization-code resource narrowing。
- 源财务定义在镜像 `71a38ff5` 上的 post-fix 证据继续有效：P2 no-send 8/8、P1 v5 sanitized image + `submit=false` 14/14 实际步骤、PDF probe 2/2，均为 terminal `completed`、`lastSuccess=true` 且 final output 非空。
- 当前部署 `b010ba614` / `b010ba61` 为 1/1 Ready、零重启，包含 managed Codex NyxID `X-API-Key`、actor-owned provisioning 和 binder-attested 只读窄放行；`0c4ff023` 的 17-case 全量回归仍作为其余案例基线。Fresh case 15 先取得六个 GET 的 interactive 11/11 committed `completed`，再从 HTTP 200 confirmation、HTTP 202 typed receipt、binding/provisioning committed success 覆盖到 schedule 回读与真实每分钟 cron。删除前 `fireCount=6`、`failureCount=0`，抽查 workflow 11/11 committed `completed`、`stateVersion=73`；NyxID DELETE typed accepted 后 list 消失，跨下一分钟 run count 保持 `6 -> 6`。`f7f543c5` 上的 `NyxIdOperationAuthorityContractUnavailable` 仅保留为历史回归背景。

## 判定口径与覆盖边界

必须先看清"通过"在本报告里代表什么，否则会高估覆盖面。

- 验收脚本 `production_validate.rb` **只对 14、16、17、18、19、20 强制 typed artifact 契约**。其余案例的"通过"仅等于 committed terminal `completed` 且 read model `success=true`。
- 因此工作流完全可能路由进自身的失败分支、仍被脚本判为"通过"。案例 18 初版就出现过这种情况：terminal `completed`、`success=true`，但 artifact 是 `attested=false`、`reason=while_replay_parity_mismatch`。本轮 17 份 artifact 已由人工逐条复核，未发现任何失败信号；但这是人工兜底，不是脚本门禁。
- 案例 05、07、08、09、10 的 submit 分支已单独运行并取得 committed 证据（见下节）；preview 分支的既有结论同时保留。
- 05、06、07、08、09、10 六个副作用分支已在 `20d9ba41` 上显式授权后真实执行，不再是"未运行"。
- `build/workflows` 是共享可变产物：并行验收时若他人用 `config.example.yaml` 重新 materialize，运行中的案例会绑定到占位符 service 并以 `NYXID_PROXY_HTTP_400` 失败。判定平台回归前必须先用 `config.local.yaml` 干净重跑一次。

## Lark channel E2E 案例（#3210）

既有 Case 14 证明 direct workflow 和 `/api/chat` 可以运行 `lark_contact_batch_resolution`，但无法证明 Lark channel AgentRun 收到 `use_skill` 的 `ApprovalRequired` 后会挂起、发卡、处理回调并继续同一调用，也无法证明 skill 已挂载时 workflow 内部 `tool_approval` 会通过同一 channel 发卡并恢复原 workflow run。#3210 暴露的 `[tool receipt] Approval pending` 最终回复和“workflow 已挂起但无审批卡”分别落在这两个空白里，因此新增三个独立 channel case，而不是复制新的 workflow。

| Case | 决策 | 必须观察到的通过证据 | 当前状态 |
|---|---|---|---|
| Case 20 | approved | 真实 Lark inbound/relay；Ornn 搜索并解析到精确 skill；Lark 审批卡出现；pending receipt 不进入模型回复；回调身份精确匹配且只分发一次；同一 AgentRun 恢复；`use_skill=Completed`；mount 执行；workflow start 恰好 1 次且 run 增量 1；最终 committed artifact 精确命中 `resolved_count=1`、`identifiers_redacted=true`、`side_effects=false` | `pending-deployment` |
| Case 21 | rejected | 真实 Lark inbound/relay；审批回调只分发一次；同一审批链返回 typed `Denied` / `approval_denied`；不执行 mount；workflow start 为 0；run catalog 增量为 0；不持久化原始身份 | `pending-deployment` |
| Case 22 | approved | skill 已挂载且不出现新 mount 审批；workflow start 恰好 1 次且 run 增量 1；run committed 到 `awaiting_tool_approval`；workflow 审批卡出现；callback 精确包含 `actor_id/run_id/step_id/execution_id/tool_call_id/approval_request_id` 且只分发一次；同一 workflow run 恢复；pending receipt 不进入最终回复；最终 committed artifact 精确命中 | `pending-deployment` |

三项都要求 Ready 生产 workload 可从 image/digest/revision 追溯到 `b7cacf1838a519e83fbfd70953be988b9696ee2b`，并确认其历史包含 `b3784feef`、`dd12cd6a6` 与 `452d72ec5`。部署证据、真实 Lark 点击和 committed terminal 尚未写入，因此机器摘要中的运行字段全部保持 `null`，`readyProductionWorkloadTraceable=false`。审批卡、Bot 文案、direct Case 14 或 `/api/chat` 成功都不能把它们升级为通过。

## while 迭代投递缺陷（由案例 18 发现）

案例 18 是本轮新增的确定性原语案例，只用 `guard`、`conditional`、`while`，无外部调用、无副作用。它的首次真实运行在 `replay_control_order` 永久挂起：生产日志只有 `While 循环 ... 开始`，之后没有任何迭代记录。

根因在 `WhileModule.DispatchIterationAsync`：迭代子步骤被投递到 `TopologyAudience.Children`，而 `foreach` 与 `map_reduce` 都投递到 `Self`。workflow run actor 没有子 actor 承接该 `StepRequestEvent`，循环因此永远等不到完成。两个既有单元测试直接调用模块并断言 `Children`，把缺陷固化成了期望值。

修复提交 `e1aedcae7` 改投 `Self` 并同步更新断言。修复后案例 18 在 `20d9ba41` 上 committed `completed`、15/15 步、`stateVersion=92`，read model 中三次迭代（`replay_control_order_iter_0/1/2`）全部可见，artifact 为 `attested=true`、`control_count=3`、`leading_control=breach_notice`、`replay_iterations=3`、`side_effects=false`。`leading_control=breach_notice` 是循环真实迭代了奇数次的证据：三行控制项经三次 `reverse_lines` 后首行必须是 `breach_notice`。

## 审批契约澄清（案例 14、17）

先前版本把案例 14、17 记为"审批契约回归"，理由是 preview 声明 `approvalRequired=true` 而运行期没有 typed pending/resume。复核 aevatar 源码后确认这是报告口径过期，不是平台回归：提交 `5dd48629`（2026-08-04）明确让 proof-bound workflow 调用跳过 per-run approval，`NyxIdProxyTool.GetCallSafety` 对 `WorkflowToolCall` 面直接返回 `RequiresApproval=false`，理由是 bind 时的 explicit-request confirmation 已完成风险 attestation。

真正的问题是 preview 与 runtime 的表述不一致。提交 `5a0b545d8` 为 explicit-request preview 增加 `approvalEnforcement` 字段，生产已确认返回 `bind_time_confirmation`；`approvalRequired` 保持单一语义（NyxID operation policy）。验收脚本相应改为断言 preview 同时返回 `approvalRequired=true` 与 `approvalEnforcement=bind_time_confirmation`，运行侧只校验 committed 终态与 typed artifact。案例 14、17 在 `20d9ba41` 上均为 committed `completed` 且契约匹配。

## 副作用分支实跑证据

先前报告把这些分支记为"未运行"。本轮在镜像 `20d9ba41` 上显式授权后真实执行，全部 committed `completed`。

| 案例 | 副作用 | run hash | state | 步骤 | 业务断言 |
|---|---|---|---:|---:|---|
| 05 | 新增一条 Base 资产盘点记录 | `8415fdd6cc7b` | 46 | 6/6 | `mutation_executed=true`、`accepted=true`、`downstream_code=0` |
| 06 | 创建一条 Lark 审批 | `7542b785f746` | 58 | 8/8 | 审批创建并回读，`approval_status=PENDING` |
| 07 | 发送一条 Lark 私信 | `8cffc03d2e0b` | 46 | 6/6 | `message_sent=true`、`downstream_code=0` |
| 08 | 发送一张 Lark 卡片 | `3e084cc92a37` | 112 | 17/17 | 六源汇总正确且 `message_sent=true`、`downstream_code=0` |
| 09 | 创建一条 Lark 审批 | `4c9bb41d415a` | 136 | 23/23 | `identity_resolved=true`、`history_checked=true`、`possible_duplicate=true`、`idempotent_skip=true` |
| 10 | 创建审批并发送完成私信 | `3b2e36d8608e` | 115 | 17/17 | 审批 `PENDING` 且 `message_sent=true` |

案例 09 的结果特别值得记录：submit 分支解析了身份、检查了审批历史，发现同一稳定键已存在，于是幂等跳过而没有重复创建审批。这正是先前 preview 证据里 `identity_resolved=false`、`history_checked=false` 未能覆盖的部分。所有对外消息都带 `[Aevatar 手工验收]` 前缀，接收方为配置中的单一验收 user_id。

## 尚未覆盖的原语与原因

| 原语 | 状态 | 原因 |
|---|---|---|
| `map_reduce` | 已覆盖（案例 20） | — |
| `cache` | 已覆盖（案例 20） | — |
| `guard`、`conditional`、`while` | 已覆盖（案例 18） | — |
| `parallel_fanout` | 未覆盖 | `ParallelFanOutModule` 把 worker 子步骤硬编码为 `llm_call`，不引入 LLM 就无法做确定性断言 |
| `race` | 未覆盖 | `RaceModule` 同样硬编码 `llm_call`，理由同上 |
| `workflow_call` | 未覆盖（已实测阻塞） | `WorkflowGAgent` 只能从 binding 的 `InlineWorkflowYamls` 解析子工作流，而 Studio `/provision-workflow` 契约只接受单个 `WorkflowYaml`。经该入口绑定的工作流调用 `workflow_call` 必然以 `workflow_call timed out waiting for definition resolution after 30000ms` 失败（run hash `4327dd64a0b0`）。要覆盖它需要给 provisioning 契约补 `InlineWorkflowYamls`，或让验收 harness 改走支持 inline 的 `workflows:save-and-bind` 入口 |

## 源版本族映射

| 源版本族 | 非 n8n 定义数 | 新仓库案例 | 已覆盖语义 | 生产边界 | 判断 |
|---|---:|---|---|---|---|
| Base 探针 | 3 | 04、05、15-17 | 记录 GET、多源读取、受保护 POST、provider receipt、bind-time 批准契约 | 16、17 在 `20d9ba41` 上均 committed `completed` | 覆盖 |
| 原语与执行探针 | 5 | 01、03、11、12 | `assign`、`transform`、分支、`foreach`、managed `codex_exec`、固定 `code_execute` | 11 在 `f7f543c5` 上恢复；12 的连续成功证据保留 | 覆盖 |
| Lark Onboarding | 1 | 06 | Base 申请、审批 payload、创建与实例回读 | 源 Aevatar e2e 语义已覆盖 | 覆盖 |
| 发票审批 | 7 | 02、03、09、13、14 + 源 P1 v5 | 图片/PDF、提取、SGD/金额/供应商规则、历史、去重、审批、contact | 源 v5 的 sanitized image + `submit=false` 已 14/14 完成；审批提交、v6 和旧 v2 未运行 | 功能主链覆盖 / 写入边界未运行 |
| 预算监控 | 5 | 04、08、15 + 源 P2 no-send | 六路 Base、预算差异、阈值、周/月摘要、消息、Durable schedule | 源 no-send 已 8/8 完成；公开案例 15 schedule 在 `b010ba61` 上已创建、回读、真实 cron 触发并删除清理；源 send 与源 durable schedule 未运行 | 公开主链与排程覆盖 / 源副作用边界未运行 |
| 旧验收案例副本 | 10 | 01-10 | 新仓库是修复、中文化并取得 committed 证据的权威版本 | 源副本仍保留旧契约 | 覆盖 |
| Ornn 资产副本 | 10 | 01-17 | 原有 15 个 skill 已 public 发布并回读；新增两个已本地同步 | 16、17 尚未服务端校验或发布；Lark channel 的 mount/get/list receipt 仍异常 | 部分覆盖 / 发布待完成 |

## 财务源工作流 post-fix 验收

本节不改写公开 17-case 的 `15 strict pass + 2 contract regressions` 最新逐案例统计，而是单独记录 `~/workflows` 源定义在镜像 `71a38ff5` 上取得的脱敏生产证据。

| 源定义 / 探针 | Preview 与输入边界 | 真实运行证据 | 严格结论 |
|---|---|---|---|
| P2 `budget_monitor_weekly.shared-base.nosend.yaml` | exact YAML；6 个唯一 GET call site；全部 read-only；无需 approval；binding succeeded、contract ready、revision 一致 | 只 invoke 一次，run catalog +1；8/8 completed，`lastSuccess=true`；首个 Base 输出与 final output 非空；audit 无 auth、authority、receipt、readiness、admission 或重复启动错误 | #3161 的真实 published-operation authority/receipt 主链通过；未发消息、未建 schedule |
| P1 `invoice_file_chain.v5.workflow.json` | exact current JSON；5 个唯一 call site，3 GET + 2 POST；4 read-only + 1 write；sanitized PNG；`submit=false`；fresh binding/contract/revision 一致 | 首次遇到瞬时 HTTP 524；小请求、短耗时且原 `readctx` 单步 probe 成功，故只做一次有证据的重跑；最终 14 个实际步骤全部 completed，`lastSuccess=true`，final output 非空 | 图片抽取、只读 lookup、preview presentation 通过；`submit_create/submit_verify/submit_present` 未执行，无 approval、无 Lark 写入 |
| PDF attachment probe | 无副作用 PDF 输入 | run catalog +1；2/2 completed，`lastSuccess=true`；extract output 与 final output 非空；audit 无错误 | PDF 附件接收与抽取功能通过 |

明确不能写成“已成功”的项：P2 send workflow、P1 v6、durable/weekly schedule、P1 v2 旧定义，以及修复后的真实 Lark attachment/skill lookup canary。前四项受安全或 authority 边界限制未运行；最后一项仍是 `#3087` 的独立 channel E2E 缺口。

## Managed codex_exec 修复与生产复验

案例 11 的固定 managed probe 没有修改 workflow payload。历史失败和恢复证据分别保留，成功结论只来自部署后的 NyxID 真实运行与 committed read model。

| 阶段 | 可审计证据 | 状态 |
|---|---|---|
| 历史回归 | 镜像 `0c4ff023` 上账号 readiness 为 enabled、eligible、active、`execution_ready=true`，但两次运行都在 `execute_probe` 以 `codex_execution_admission_denied` committed `failed`（state 31） | 排除 workflow 输入漂移与账号未就绪 |
| 根因 | Aevatar 把 managed Agent Key 放入 `Authorization: Bearer`；NyxID 的 `forward_access_token=true` 又把同一 bearer 转发给 chrono-sandbox，下游将其作为错误的访问令牌并返回 401 | 代理认证与下游 bearer 语义冲突 |
| 代码修复 | 提交 `f7f543c51` 增加 bounded `X-API-Key` 代理入口，managed transport 不再发送 `Authorization`，Agent Key 不进入 body；已直接推送 `origin/feature/integrate` | 已提交、推送并随 `f7f543c5` 部署 |
| 聚焦验证 | `NyxIdApiClientBoundedProxyTests` 3/3、`NyxIdManagedCodexChronoTransportTests` 16/16 通过；`test_stability_guards.sh`、docs lint 与 `git diff --check` 通过 | 认证 header、密钥边界与 transport 契约通过 |
| 生产终态 | 通过 `scripts/production_validate.rb` 和 `nyxid proxy request aevatar` 完成 preview 与真实运行；run hash `fa77c0c49035`，committed `completed`、`terminalSuccess=true`、state 179、30/30 步 | 生产恢复 |
| 固定成功契约 | `status=succeeded`、`target=managed_sandbox`、裁剪后 `output=CODEX_EXEC_READY`、`exit_code=0`、非空且已脱敏 `diagnostic_id` 全部命中；五项证据仍由单个并行 `foreach` 归一化，`parallel_check_count=5`，`side_effects=false` | 案例 11 严格通过 |

## Durable schedule 修复进度

本节同时记录历史基线、已部署工程修复和 2026-08-06 SGT 的 fresh NyxID 端到端复验。历史 HTTP 502 与 `f7f543c5` authority failure 仍作为回归背景保留，当前生产事实以 `b010ba614` / `b010ba61` 为准；新旧证据不会相互覆盖。

| 阶段 | 可审计证据 | 状态 |
|---|---|---|
| 历史基线 | 案例 15 schedule endpoint 返回 HTTP 502，没有 typed schedule receipt | 已被新入口证据替代，保留作回归对照 |
| Actor 实现 | 请求侧只提交无 secret 的 intent；`StudioMemberGAgent` 等待精确 binding revision，以 durable self-timeout 处理 projection lag；后台按 `VerifiedBindingId` 重签短期 token；拒绝 stale attempt completion，binding failed/rejected 会终止 provisioning | `748f98e7d` 已提交、推送并部署 |
| 真实验收入口 | 无 token请求返回 HTTP 200 `confirmation_required`，列出 6 个只读且允许 Durable 的固定 call site；相同 payload 加 fresh token 后返回 HTTP 202 typed receipt，状态为 `pending_binding`，binding run 和 provisioning ID 均非空 | 入口与 admission 通过 |
| 历史 authority 回归 | `f7f543c51` 部署只注册 `UnavailableNyxIdScheduledOperationAuthorizationPort`；binding succeeded 后 provisioning 以 `NyxIdOperationAuthorityContractUnavailable` committed failed，schedule/operation ID 为空 | 已由新镜像修复，保留作回归对照 |
| 源码后续修复 | `7a7781067` 已进入 `origin/feature/integrate`，并包含在当前 `b010ba614` / `b010ba61` 部署中：完整 Durable proof、binder grant 与 service catalog 校验通过后，仅 binder-attested `READ_ONLY` GET/HEAD/OPTIONS 跳过独立 operation-authority preview；NyxID runtime proxy 仍逐次校验当前权限，POST、WRITE 与 DESTRUCTIVE 继续 fail-closed | 精确适用于案例 15 的 6 个 GET；生产已验证 |
| 查询与回执 | member read model 可见；binding committed `succeeded`（state 7），provisioning 第 2 次 attempt committed `succeeded`（state 11）；schedule/operation ID 均非空。schedule 回读为 enabled，canary Cron `* * * * *`、时区 `Asia/Singapore` | Durable 创建与读取通过 |
| 真实触发与清理 | 六次非 manual cron fire 后 `fireCount=6`、`failureCount=0`，六个 workflow run 均 completed；抽查 run 11/11 committed `completed`（state 73），最终 artifact 命中六路 live Base、周度 2340/2400、月度 9360/9600、over=1、watch=1。NyxID DELETE 返回 typed accepted receipt，list 归零，跨下一分钟 run count 保持 `6 -> 6` | Durable schedule 创建、真实触发与清理端到端通过 |
| 编译、镜像与门禁 | `b010ba614` 已普通推送 `origin/feature/integrate`；Release publish、真实 `linux/amd64` Docker build、镜像内 `.NET 10.0.10 linux-x64`、architecture/test-stability guards 和排除 3 个本机 Redis 版本契约用例后的 solution tests 均通过。旧 `7a7781067` 验证工作树的 23/23、1730/1730、152/152、Mainnet DI composition 1/1、Studio DI/executor 11/11、Capabilities 642/642 作为历史修复证据保留 | 当前部署可构建；新旧测试证据边界已标明 |
| 剩余边界 | 本次只证明公开案例 15 的六个 binder-attested GET；写入型 Durable 仍需正式 `INyxIdScheduledOperationAuthorizationPort`。`~/workflows` 的源 durable/weekly schedule 没有运行 | 不外推到源定义或写入型排程 |

## 新增案例与真实结果

| 案例 | 目标能力 | 静态/preview | 直接 runtime | 结论 |
|---|---|---|---|---|
| 11 | managed `codex_exec` | 通过；payload 与 canonical sample 一致，账号 readiness=ready | `f7f543c5` 上 committed `completed`，`stateVersion=179`，30/30 步，`CODEX_EXEC_READY` 与五项 gate 命中 | 已恢复 |
| 12 | 通用 `code_execute` | 通过 | 连续两次 committed `completed`，`stateVersion=31`，`total_cents=16623` | 已恢复 |
| 13 | 图片/PDF OCR、发票规则、历史去重 | 通过 | committed `completed`，`stateVersion=82` | 覆盖 |
| 14 | Lark `contact/v3/users/batch_get_id` | preview 通过；`approvalRequired=true` 且 `approvalEnforcement=bind_time_confirmation` | committed `completed`，`stateVersion=25`，`resolved_count=1`、`identifiers_redacted=true` | 覆盖；批准在 bind 时兑现 |
| 15 | 六路 Base、预算周报/月报、schedule | 通过 | `b010ba61` 上 interactive 11/11 completed；binding/provisioning succeeded，每分钟 schedule 可读取；真实 cron fire=6/failure=0，抽查 workflow 11/11 committed `completed`，DELETE 后 list 消失且 run count 不增长 | 核心业务与公开 Durable schedule 端到端通过 |
| 16 | managed workflow NyxID provider receipt | 静态与 preview 通过；单次 `get`、read-only、无需批准 | committed `completed`，`stateVersion=31`，4/4 步 | #3161 receipt/runtime 最小回归通过；源 P2 no-send 另行补齐 authority 分支 |
| 17 | POST search bind-time 批准契约 | 静态与 preview 通过；单次 `post`、write、`approvalEnforcement=bind_time_confirmation` | committed `completed`，`stateVersion=31`，`approval_resumed=true`、`side_effects=false` | 覆盖；#3184 口径已澄清 |
| 18 | `guard`、`conditional`、`while` 三个确定性原语 | 静态与 preview 通过；无外部调用、无副作用 | committed `completed`，`stateVersion=92`，15/15 步，`leading_control=breach_notice` | 覆盖；并由此定位并修复 `while` 挂起缺陷 |
| 19 | Lark Bot 入站附件与确定性文件契约 | 静态与 preview 通过；0 个外部 call site | direct committed `completed`，`stateVersion=30`，4/4；Lark 文件卡片、解析与回复 relay 已观察，但 workflow start 为 `service_catalog_missing`、run 增量 0 | 核心文件链覆盖；Lark workflow `start-blocked` |

## Ornn 发布证据

19 个 skill 均采用 Ornn validator 接受的 `SKILL.md + assets/*.yaml` 布局，且 asset 与公开 workflow 字节一致。原有 15 个线上 skill 已通过服务端格式校验，并逐个回读名称、`.1` 版本和 public 状态；新增的 16、17、18、19 目前只有本地 validator 证据，尚未上传或公开。

本地 Aevatar 源码的 `SkillWorkflowExtractor` 已包含 `assets/*.yaml` fallback。生产 `/api/chat` 中 01、12、13、14、15 都能完成 search、skill load、typed mount approval 和 workflow start；复杂 capability 的 mount/admission 与模型绕过问题已在镜像 `7ba3fa3e` 上重跑关闭。案例 15 又在镜像 `d7844b5e` 上验证 artifact 工具可使用 workflow start 同时返回的 actor identity 读取 committed artifact，不再依赖最终一致的短 run binding。

## `/api/chat` 自然语言证据

| 案例 | Assistant 回合 | Ornn/skill | workflow | typed artifact 判定 |
|---|---|---|---|---|
| 01 | completed | 搜索、精确加载、mount approval 成功 | 已启动 | `validated`，13/13，`stateVersion=80` |
| 12 | completed | 搜索、精确加载、mount approval 成功 | 已启动 | `typed-failure`，`NYXID_PROXY_UNAUTHORIZED`，`stateVersion=12` |
| 13 | completed | 搜索、精确加载、图片 file ref 成功 | 已启动 | `validated`，12/12，`stateVersion=82` |
| 14 | completed | 搜索、精确加载、mount approval 成功 | 已启动 | `validated`，3/3，`stateVersion=28`，`resolved_count=1` |
| 15 | completed | 搜索、精确加载、mount approval 成功 | 已启动 | `validated`，11/11，`stateVersion=73`；最终 committed artifact 已由 Assistant 正确报告 |

本轮 `/api/chat` 的成功工具在公开 SSE 中仍可能只暴露 `TOOL_CALL_END.result="completed"`。验证器从 typed start receipt 保留 run identity，再查询 committed workflow current state；即使 Assistant 文案仍写 pending，也只按 committed 状态判定。`d7844b5e` 上的案例 15 进一步证明 Assistant 自身最终也读取并报告了 committed artifact，`artifactPendingReportedAsFinal=false`。

## `/api/chat` 与 Lark Bot

`/api/chat` 直接通过 NyxID 用户身份进入 Aevatar SSE，可验证 Assistant、工具目录、Ornn、workflow 启动和 artifact 查询。Lark Bot 在此基础上还包括：

- Lark webhook 验签和事件转换；
- NyxID channel relay 与 Bot 注册；
- platform conversation 到 agent 的映射；
- 发送者身份解析；
- Agent reply 经 relay 回传 Lark。

因此 `/api/chat` 成功不能替代 Lark transport 证据；Lark 中出现回复也不能证明 workflow 终态成功。本轮两类证据已经分别取得；前两次 Bot 重试证明 typed approval resume 被接受，但运行最终都以 `NYXID_PROXY_SERVICE_SCOPE_FORBIDDEN` committed failed。Developer App 默认项修复后的 fresh `/init` 又创建了 allow-all consent 和新 binding，第三次 run 仍以同一错误 committed failed。Aevatar authorize URL 的显式 core resource 不含 Lark；NyxID 会据此缩窄 authorization code/binding，所以默认项预选无法扩展实际 resource grant。

案例 19 又补充了文件消息维度的独立证据：Lark 中发送 114 字节合成 JSON 后，Bot 收到文件卡片、解析出合成内容并经 relay 回传回复。随后按 workflow name、slug 和已绑定 member descriptor 共发起三次 `aevatar_start_workflow`，均在创建 run 前以稳定 `service_catalog_missing` 拒绝；验收窗口内案例 19 run catalog 增量为 0。原因是 direct validator 的 member binding 不属于 Assistant current-scope workflow catalog，且案例 19 的 Ornn skill 尚未发布。该证据严格记为 `start-blocked`，不能由附件解析成功外推为 `lark_bot_ingress_validated=true`。

## 当前阻塞与待复测项

1. 验收脚本断言覆盖面：`production_validate.rb` 只对 14、16、17、18、19、20 强制 typed artifact 契约，01-13、15 的“通过”仅等于 committed `completed`。工作流走进自身失败分支仍会被判通过，目前靠人工复核 artifact 兜底。Case 17 的拒绝分支在 bind-time 契约下不再经由 per-run resume 到达，durable preview 仍未验证。
2. Lark Bot sender service grant：Aevatar `1.0.10` 为 Released，Bot Enabled、Availability=All，NyxID committed Bot 为 `active`、`webhook_registered=true`。镜像 `8cf280e2` 上的案例 14 直接 run 和 `/api/chat` Ornn mount/run 均 committed `completed`；前两次 Lark Bot 重试也都启动 workflow，并在 typed approval resume 后从 `awaiting_tool_approval` 进入 committed `failed`。失败步骤均为 `resolve_contact`，稳定错误码均为 `NYXID_PROXY_SERVICE_SCOPE_FORBIDDEN`；run 哈希为 `1436a2852f8d`（state 18）和 `e491a2690b03`（state 17）。生产 `aevatar` Developer App 把 `api-lark-bot` 追加到 `default_service_catalog_slugs` 后，fresh `/init` 于 `11:34Z` 创建 allow-all consent 与新 sender binding；镜像 `e30fdd94` 上的第三次 run `93ece1c36951` 仍在 `resolve_contact` 以同一错误 committed `failed`（state 14）。源码契约确认 Aevatar authorize 仍只显式请求 core resources，NyxID 会在 authorization-code 阶段按这些 resources 缩窄 binding；默认项只提供 consent hints。因此该 blocker 已验证，不能再要求用户重复 `/init`。`ornn.skill` mount failure、`scope_workflows_get/list` outcome unverified 和后续 fallback 的 `InvalidWorkflowYaml` 继续作为独立 receipt 缺陷保留。
3. 案例 19 Lark workflow catalog：文件上传、附件解析和 Lark 回复 relay 已验证；direct run 也 committed 4/4。但当前 scope 未公开案例 19 skill，Assistant catalog 无可启动定义，三次 start 均为 `service_catalog_missing` 且 run 增量为 0。发布或挂载属于独立副作用，本轮未执行。
4. 财务源定义的安全边界：P2 send、P1 v6、源 durable/weekly schedule 和 P1 v2 旧定义仍未运行。公开验收案例 15 的 schedule 已通过，但不能替代这些源副作用或 authority 分支。

## #3161 与 #3184 定向回归

截至 2026-08-05，[`#3161`](https://github.com/aevatarAI/aevatar/issues/3161) 已关闭，[`#3184`](https://github.com/aevatarAI/aevatar/issues/3184) 仍开放。二者都经历过“前一层修好后暴露下一层”的过程，因此不能只验 preview 或一个 HTTP ACK。

Case 16 的 production preview 确认只有一个 `get` 调用点、`effectiveRisk=read_only`、`approvalRequired=false`。真实 run committed `completed`，`stateVersion=31`，4/4 步完成，首个 tool step 输出非空，最终 typed artifact 为 `success=true`、`provider_response_verified=true`、`side_effects=false`，没有 auth、authority、receipt、readiness 或 admission error。随后源 P2 no-send 在 `71a38ff5` 上以 exact YAML preview、6 个唯一 read-only call site、单次 invoke 和 8/8 committed completion 补齐 published-operation authority 主链；audit 同样没有 auth、authority、receipt、readiness、admission 或重复启动错误。

Case 17 使用不会修改数据的 Base `records/search` POST，但保留 POST 的保守 write 风险。Production preview 确认单次 `post`、`approvalRequired=true` 且 `approvalEnforcement=bind_time_confirmation`。历史 state 34 run 曾收到 `aevatar.tool_approval.pending` 并用 nested `toolApproval` 身份 resume；aevatar `5dd48629` 之后 proof-bound workflow 调用不再产生 per-run pending，批准改由 bind 时的 explicit-request confirmation 兑现，`20d9ba41` 上 committed `completed`（state 31）。拒绝分支因此不再经由 per-run resume 到达，durable preview 仍需单独验证。

Case 16 与源 P2 no-send 的当前结论仍为通过。Case 17 在澄清后的 bind-time 契约下判定为通过；拒绝终止与 durable preview 不由此外推。

## #3182 证据边界

`#3182` 未解决时，不能用直接 workflow committed 成功替代 Ornn + 自然语言链证据。本轮没有做这种外推，而是在生产镜像 `7ba3fa3e` 上逐个重跑 `/api/chat`：4/5 为严格 `validated`，1/5 为有 committed blocker 的 `typed-failure`。随后在 `d7844b5e` 上再次通过自然语言运行案例 15，验证短 run ID 与 actor identity 分离时仍能读取 committed artifact。

因此，`/api/chat` 的 mount/admission、run identity 和模型绕过已由当前镜像上的案例 14 新生产证据关闭；issue 是否关闭应由其验收范围决定，不能反过来否定本轮证据。Lark Bot transport 已独立验证，三次 Bot 重试也已取得 committed 失败终态；fresh `/init` 已证明 Developer App 默认项不足以改变 authorization-code resource grant。当前边界是平台修复 resource narrowing，以及 channel-only 的 mount/get/list/invalid-YAML receipt 缺陷。

## 证据位置

- Preview 摘要：`validation/production-preview-2026-08-04.json`
- Runtime、Ornn、`/api/chat` 与 schedule 摘要：`validation/production-validation-2026-08-05.json`
- 交互分析页：`report/index.html`
