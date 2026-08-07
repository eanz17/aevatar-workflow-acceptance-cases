# 工作流验证与能力覆盖报告

报告基线日期：2026-08-05；状态更新：2026-08-07（当前 Ready 生产镜像 `eead35c0`；历史证据所在祖先镜像按段落单独标注）。

> **最新全量观测：**2026-08-07 13:15-13:49 SGT 的 append-only fresh 快照与本报告历史基线并存。该批次为 preview 29/29、direct 25 passed / 1 platform-blocked / 3 skipped、Ornn 28/29 版本一致、Assistant 4/5 validated、Lark channel 2/3 passed；Case 19 文件 canary 与 R01 `/init` 通过。窗口后 13:56 在 Ready `5f51f6d0`、14:34 在当前 Ready `eead35c0` 两次复验 Case 11，均 committed `failed` / `codex_execution_capacity_unavailable`，不回算全量批次；最新 run 为 `106ecf7b750a`。另据 [#3290](https://github.com/aevatarAI/aevatar/issues/3290)，源 P2 在 14:09 完成 14/14 并通过业务复算后，于 14:18 出现 `code_execute` 502，14:20-14:42 同一定义连续 5 次准入失败；P1 同期在第 1/27 步 `Forwarding failed`。该 issue 证据不回算本仓库 fresh 批次，但把两条迁移主链的当前状态降为 `regression-blocked`。详见 [当前状态报告](2026-08-07-current-status-report.md) 与 [机器快照](../validation/full-revalidation-2026-08-07.json)。下文原有统计是带时间戳的历史证据，不应被解释为这次 fresh 批次全绿。

## 路径与统计口径

用户最初提到的 `~/Code/workflows` 当前不存在。本报告实际比较：

- 验收仓库：`/Users/chronoai/Code/aevatar-workflow-acceptance-cases`；
- 源目录：`/Users/chronoai/workflows`。

源目录共有 43 个带 workflow 形态的可解析定义，其中两个是带 `nodes/connections` 契约的 n8n JSON。本轮按要求排除 n8n，只比较其余 41 个定义。41 个定义包含旧版本、派生版本和 Ornn 内嵌副本，不能用文件数直接计算功能覆盖率；本报告将它们归并为 7 个版本族。

## 总结

- 29/29 个公开 workflow 通过本地静态校验和 production explicit-request preview；`production_validate.rb` 与 `assistant_validate.rb` 共用 29/29 个 strict artifact contract。
- 当前直接 runtime 严格结果为 28/29：Case 11 在 Ready `eead35c0` 上的 fresh run `106ecf7b750a` committed `failed`，稳定错误为 `codex_execution_capacity_unavailable`；Case 12 在祖先 Ready `6558db8d` 的 fresh direct run `6659aabee079` committed `completed`、state 31、4/4，严格命中 `total_cents=16623`、`side_effects=false`。同部署首次 524 保留为瞬时 capacity 对照，历史 `f7f543c5` 的 Case 11 30/30 只作为恢复对照，不能覆盖当前 blocker。
- 另有 3 个既有 Lark channel E2E case 和 21 个 risk case。Channel fresh 严格结果为 3/3 passed；risk 汇总为 16 passed、0 blocked、0 failed、0 pending-execution、4 not-configured、1 skipped-expired。
- 旧 01-10、13-20 保留既有 committed 基线；Case 11 使用当前部署的 committed capacity failure，Case 12 使用当前部署的 committed success；新增 21-25 当前最新结果为 5/5 completed，26-28 在 Ready `4c0596c7` 上为 3/3 completed，Case 29 在 Ready `6a656d75` 上为 11/11 completed。Cases 05/24/25 fresh 写探针共创建 4 条固定合成记录，随后连同 2 条同契约历史残留精确清理；回读匹配数为 0，未匹配记录未触碰。
- 本地与线上 29/29 个 Ornn skill 与 workflow 一一对应；本轮 missing-only 只创建并公开 Case 29 的 `invoice-approval-routing-preview` 1.0，既有 28 项精确跳过；发布后的正式 verify-only 与独立 catalog 验证器均确认 29/29 format、精确名称、版本与 public readback 一致。
- 13 已补齐合成图片/PDF、发票字段归一化与财务去重规则；14 精确覆盖 Lark contact API；15 补齐预算周报/月报公式与 schedule 契约；16、17 分别针对 #3161 和 #3184 增加最小回归探针。
- `/api/chat` 在 Ready 镜像 `ee031038` 上的历史 5 个代表案例为 5/5 committed `completed`。最近代表对照为 2/2：Case 01 run `535e9029486f` 保留严格 `validated`；Ready `6558db8d` 上 Case 12 run `6fa89cd62b15` fresh 完成 Ornn search、精确 mount、workflow start 和 committed artifact，严格 `validated`。
- 五个案例均按 search-first 顺序经过精确 skill 加载、typed mount approval、workflow 启动和 committed observation，重复 tool start call ID 为 0。
- `/api/chat` 与 Lark Bot 共用 Assistant/Ornn/workflow 核心；Lark Bot 已独立覆盖 webhook、NyxID channel relay、会话映射、Lark 回传和 typed approval resume。Cases 20/21/22 当前均严格通过；早期 sender scope 失败只保留为历史 authorization-code resource narrowing 诊断，不再作为当前 channel blocker。
- Aevatar 提交 `6558db8db` 已允许共享 `chrono-sandbox` UserService 开启 bearer forwarding，同时继续强制 delegation injection 与 scope=`proxy:*`；当前策略为 `true/true/proxy:*`。Managed transport 仍使用 `X-API-Key` 且不发送 `Authorization`。固定无副作用 `/execute`、Case 12 direct 和 `/api/chat` 均 fresh 严格通过，普通执行 authority 已恢复。
- Durable schedule 已在当前 Ready `4c0596c7` fresh 完成全闭环：1 workflow / 6 GET 的 read-only Durable confirmation，typed `accepted/pending_binding`，binding state 7 与 provisioning state 11 / attempt 2 committed `succeeded`；owner-scoped detail 回读 schedule enabled，每分钟 Cron 自然触发 1 次，run hash `b9859494e2a9` 为 11/11 committed `completed`、`stateVersion=73`，预算 artifact 全部精确命中。Typed DELETE 后 detail 消失、owner list 为 0，跨下一分钟 run count 保持 `1 -> 1`。历史 `b010ba614` / `b010ba61` 上的六次 Cron 闭环和 `f7f543c5` 的 `NyxIdOperationAuthorityContractUnavailable` 回归背景继续保留，但不代替当前 fresh 证据。
- 源迁移连续性当前未覆盖且已观察到回归：#3290 的同一 P2 member/binding/definition 在 9 分钟内经历 6/10 failed -> 14/14 completed -> 7/8 `NYXID_PROXY_HTTP_502`，之后 byte-identical preview 连续 5 次 `NYXID_ADMISSION_SOURCE_CREDENTIAL_REQUIRED`；P1 在第 1/27 步 `Forwarding failed`。历史成功仍有效，但不能证明当前 availability 或 silo continuity。

## 判定口径与覆盖边界

必须先看清"通过"在本报告里代表什么，否则会高估覆盖面。

- 验收脚本现在为 01-29 全部注册 strict artifact contract；terminal `completed`、read model `success=true` 或模型文案均不能替代业务字段精确匹配。
- 案例 18 初版曾出现 terminal completed 但业务 artifact 失败的假绿；该教训现由共享 `RuntimeContracts` 自动门禁，不再依赖人工逐条兜底。
- 案例 05、07、08、09、10 的 submit 分支已单独运行并取得 committed 证据（见下节）；preview 分支的既有结论同时保留。
- 05、06、07、08、09、10 六个副作用分支已在 `20d9ba41` 上显式授权后真实执行，不再是"未运行"。
- `build/workflows` 是共享可变产物：并行验收时若他人用 `config.example.yaml` 重新 materialize，运行中的案例会绑定到占位符 service 并以 `NYXID_PROXY_HTTP_400` 失败。判定平台回归前必须先用 `config.local.yaml` 干净重跑一次。

## Lark channel E2E 案例（#3210）

既有 Case 14 证明 direct workflow 和 `/api/chat` 可以运行 `lark_contact_batch_resolution`，但无法证明 Lark channel AgentRun 收到 `use_skill` 的 `ApprovalRequired` 后会挂起、发卡、处理回调并继续同一调用，也无法证明 skill 已挂载时 workflow 内部 `tool_approval` 会通过同一 channel 发卡并恢复原 workflow run。#3210 暴露的 `[tool receipt] Approval pending` 最终回复和“workflow 已挂起但无审批卡”分别落在这两个空白里，因此新增三个独立 channel case，而不是复制新的 workflow。

| Case | 决策 | 必须观察到的通过证据 | 当前状态 |
|---|---|---|---|
| Case 20 | approved | 显式“挂载”进入 typed recovery；mount 卡/callback 各 1 次并恢复同一 AgentRun；`use_skill=Completed`、`mount_executed=true`；workflow 工具卡/callback 各 1 次并恢复同一 run；普通 AgentRun 可见回复与 awaiting 文本均为 0；唯一新 run `e18081f2211b` committed state 30、3/3，脱敏 artifact 命中 | `passed` |
| Case 21 | rejected | 显式“挂载”进入 typed recovery；mount 卡/callback 各 1 次；同一挂起 AgentRun 返回 typed `Denied` / `approval_denied`；`mount_executed=false`；workflow 卡、start 与目标 run 增量均为 0 | `passed` |
| Case 22 | approved | skill 已挂载且不出现新 mount 审批；workflow start 恰好 1 次且新 run 晚于 Lark inbound；run committed 到 `awaiting_tool_approval`；workflow 审批卡与 callback 各一次；同一 workflow run 恢复；普通 AgentRun 可见回复为 0；3/3 steps、stateVersion 30、脱敏 committed artifact 精确命中 | `passed` |

Case 20/21 已在 Ready 镜像 `de801ca7` 上执行真实 Lark 入站。Case 20 先出现唯一 `use_skill` mount 卡，批准后同一 AgentRun 恢复并启动唯一 workflow run；该 run 再经唯一 `nyxid_proxy` 卡批准后 committed `completed`、state 30、3/3，公开 hash 为 `e18081f2211b`，request/output/timeline 联系人标识均已脱敏。Case 21 只拒绝唯一 mount 卡，得到 typed `Denied` / `approval_denied`，未 mount、未启动 workflow，目标 run catalog 增量为 0；拒绝窗口发生的生产前滚 `49244090` 直接包含 `de801ca70`，未产生重复 callback。旧 `ee031038` / `InvalidWorkflowYaml` 结果继续作为历史负证据。Case 22 的已挂载路径公开 run hash `08cdd96d61dd` 继续证明 workflow 运行期批准恢复。

## 可靠性与准入风险验收（2026-08-07）

新增 workflow 21-29 与 risk case 23-43 专门验证此前证据不足、容易假绿或已经过期的路径。所有生产 API 均经 `nyxid proxy request aevatar`；公开机器摘要只保存 run hash。本轮 Base 写探针及同契约历史残留已精确清理，回读匹配数为 0。

| Risk Case | 目标 | 状态 | 生产证据 / 仍不可靠处 |
|---:|---|---|---|
| 23 | Lark workflow 工具拒绝 | `passed` | Ready `4c0596c7` 上唯一 fresh run 从 `awaiting_tool_approval` 进入 committed failed；拒绝只分发一次，稳定 `approval_denied`，下游未执行、无 final artifact、未保存 raw ID |
| 24 | Lark 附件经 public catalog 启动 | `passed` | public skill `1.1` 精确解析；目标 run 基线 `6 -> 7`，唯一新 run `03c3f4ded68e` committed 4/4、state 32；114 字节文件卡片归一化为 113 字节 descriptor/extraction，Lark ingress、文件内容/SHA、脱敏和无副作用 artifact 精确命中 |
| 25 | Lark sender scope | `passed` | 同 sender 的 fresh Case 22 已启动 AgentRun、解析精确 skill/workflow、完成同一 run 的 typed approval resume，并以 contact artifact committed completed；精确 UserService grant 已由真实调用证明 |
| 26 | `/api/chat` code_execute | `passed` | Ready `6558db8d` 上 search-first、精确 skill mount、workflow start 与 committed artifact 均成功；run `6fa89cd62b15` 和 direct run `6659aabee079` 都为 state 31、4/4 completed，固定 `/execute` 探针同步通过 |
| 27 | Ornn catalog 完整性 | `passed` | 29/29 format、精确名称、版本与 public readback 全部一致；独立 verify-only 未写入 |
| 28 | 当前部署精确源 P1 v5 | `passed` | 历史 exact source + sanitized PNG + `submit=false` 只 invoke 一次；14/14 completed，写入/审批分支未执行；不覆盖重新绑定、部署或 silo 切换后的时间连续性 |
| 29 | P2 四表 schema 保真 | `not-configured` | disposable 合成表未配置；shared Base 不作语义替代 |
| 30 | 源 Durable schedule cleanup | `not-configured` | 源 target/authority 未配置；公开 Case 15 不作替代 |
| 31 | direct artifact contracts | `passed` | 29/29，Assistant 共用同一 contract |
| 32 | 报告一致性 | `passed` | workflow/skill/contract/README/Markdown/HTML/机器摘要统一为 29 |
| 33 | 缺 capability 的 provision | `passed` | `NYXID_OPERATION_SELECTION_REQUIRED` fail-closed，无外部写入 |
| 34 | path 槽位契约（路由由 template 固定） | `passed` | 三条子探针均已实测：正例槽位取值经准入放行、仅 provider 侧 `NYXID_PROXY_HTTP_400`；内联表达式 `path_template` 在 preview 被 `NYXID_OPERATION_SELECTION_REQUIRED` 拒绝；含分隔符与 dot segment 的槽位值在调用 provider 前被 `NYXID_OPERATION_PATH_PARAMETER_INVALID` 拦下；0 external writes |
| 35 | n8n 导出拒绝 | `passed` | preview 类型化拒绝 root field `nodes` |
| 36 | Durable write fail-closed | `passed` | `DURABLE_AUTHORIZATION_UNAVAILABLE`；interactive 对照可准入 |
| 37 | `workflow_call` inline definition resolution | `passed` | Case 26 fresh run `07f1fc930866` committed completed、state 44、5/5；inline definition bound、child resolved/started、artifact 命中 |
| 38 | `parallel_fanout` 确定性 runtime | `passed` | Case 27 fresh run `5b0e99a928f5` committed completed、state 86、14/14；3 个 worker receipt 与 merge order 命中 |
| 39 | `race` 确定性 runtime | `passed` | Case 28 fresh run `ebe447a8479b` committed completed、state 38、6/6；first success 与 later completions ignored 命中 |
| 40 | 源 P2 send | `not-configured` | exact source/hash 已核对；缺一次性接收目标与显式发送授权，未执行 |
| 41 | 源 P1 v6 submit | `not-configured` | exact source/hash 已核对；缺安全合成审批目标与清理方案，未执行 |
| 42 | 源 P1 v2 legacy | `skipped-expired` | 源路径、SHA、5 步 legacy 定义和旧验收要求保留；无 capability 的 `code_execute`、硬编码 provider/审批/邮箱/表单契约已过期。Replacement Case 29 用原生节点与完整 capability 覆盖同类 no-submit feature，已完成 static、2-call-site preview、run `a729912ee5d9` 11/11 committed artifact 与 Ornn public readback |
| 43 | materialized workflow 输出隔离 | `passed` | example/local 分别输出到独立目录；stale 文件清理、源/产物集合一致，isolated local 目录的 21-23 preview 全部通过 |

新增 workflow 的最新 terminal 结果：21 为 7/7、state 49；22 为 8/8、state 55；23 为 4/4、state 31，三者均 committed `completed` 且 strict artifact contract 命中。24 最近一次为 5/5、resume 1 次；25 为 8/8、resume 2 次。26/27/28 在 Ready `4c0596c7` 上分别为 5/5 state 44、14/14 state 86、6/6 state 38。29 在 Ready `6a656d75` 上 preview 精确命中审批历史 GET 与 attested read-only contact POST，run `a729912ee5d9` 为 state 77、11/11 committed completed，no-submit artifact 精确命中且无副作用。此前 21-23 同时出现的 `NYXID_PROXY_HTTP_400` 已定位为共享 `build/workflows` 被 `config.example.yaml` materialization 覆盖，并由 clean isolated local materialization 重跑取代；Risk 43 将该隔离约束固化为本地验收门禁。机器证据见 `validation/production-validation-2026-08-06-cases-21-25.json`、`validation/production-validation-2026-08-07-cases-26-28.json`、`validation/production-validation-2026-08-07-case-29.json`、`validation/production-validation-2026-08-07-schedule.json` 与 `validation/risk-validation-2026-08-06.json`。

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
| `parallel_fanout` | 已覆盖（案例 27） | 三路 deterministic worker receipt、dispatch index 与 merge order 已在 14/14 committed read model 中精确断言 |
| `race` | 已覆盖（案例 28） | 三路 candidate、首成功 winner 与 later completion ignored 已在 6/6 committed artifact 中精确断言 |
| `workflow_call` | 已覆盖（案例 26） | provisioning 现携带固定 `InlineWorkflowYamls`；transient child 已解析、启动和完成，5/5 committed artifact 命中 |

## 源版本族映射

| 源版本族 | 非 n8n 定义数 | 新仓库案例 | 已覆盖语义 | 生产边界 | 判断 |
|---|---:|---|---|---|---|
| Base 探针 | 3 | 04、05、15-17 | 记录 GET、多源读取、受保护 POST、provider receipt、bind-time 批准契约 | 16、17 在 `20d9ba41` 上均 committed `completed` | 覆盖 |
| 原语与执行探针 | 5 | 01、03、11、12 | `assign`、`transform`、分支、`foreach`、managed `codex_exec`、固定 `code_execute` | 11 当前为 execute capacity blocker；12 当前为 sandbox delegation authority blocker；两者历史成功证据均单独保留 | 当前阻塞 / 历史覆盖 |
| Lark Onboarding | 1 | 06 | Base 申请、审批 payload、创建与实例回读 | 源 Aevatar e2e 语义已覆盖 | 覆盖 |
| 发票审批 | 7 | 02、03、09、13、14、29 + 源 P1 v5 | 图片/PDF、提取、SGD/金额/供应商规则、历史、去重、审批、contact | 源 v5 submit=false 与 Case 29 原生 no-submit 路由有历史完成证据；#3290 中 P1 当前第 1/27 步 `Forwarding failed`；审批提交、v6 未运行，旧 v2 已退休 | 历史功能覆盖 / 当前连续性阻塞 |
| 预算监控 | 5 | 04、08、15 + 源 P2 no-send | 六路 Base、预算差异、阈值、周/月摘要、消息、Durable schedule | 源 no-send 有历史 8/8；公开案例 15 schedule 有独立 fresh 闭环；#3290 中 exact P2 14/14 后同定义出现 runtime 502 和准入拒绝；源 send 与源 durable schedule 未运行 | 历史覆盖 / 当前连续性阻塞 |
| 旧验收案例副本 | 10 | 01-10 | 新仓库是修复、中文化并取得 committed 证据的权威版本 | 源副本仍保留旧契约 | 覆盖 |
| Ornn 资产副本 | 10 | 01-29 | 29/29 本地 asset 同步、服务端格式、精确名称、version 与 public 状态一致 | channel transport 由独立 Cases 20-22 验证 | catalog 覆盖 |

## 财务源工作流 post-fix 验收

本节不改写公开案例的逐案例统计，而是单独记录 `~/workflows` 源定义和同结构安全变体取得的脱敏证据。2026-08-06 的 scope 特定故障已通过同一 run 内的对照定位：Base `nyxid_proxy` 读取成功，紧接着 `code_execute` 401。源码契约确认 `code_execute` 调用 sandbox `/execute`，需要 Aevatar execution delegation 中的 `sandbox:execute`，且目标 sandbox UserService 必须开启 caller bearer 转发。账户前者已具备、后者随后回读为开启；只调整转发策略，未添加静态 sandbox credential。下表四项成功是带时间戳的历史证据，不再代表 2026-08-07 14:15 后的当前连续可用性。

| 源定义 / 探针 | Preview 与输入边界 | 真实运行证据 | 严格结论 |
|---|---|---|---|
| 单步 `code_execute` probe | 新 member；单个固定输出的无副作用工具步骤；binding succeeded、contract ready | run catalog `0 -> 1`；只 invoke 一次；terminal completed，`lastSuccess=true`，固定输出非空，audit 无 auth、admission、readiness 或 receipt error | scope 特定 sandbox bearer 转发链已在线验证 |
| P2 shared-Base no-send 同结构运行定义 | 基于 `budget_monitor_weekly.shared-base.nosend.yaml` 刷新 live selector，不是当前文件的逐字副本；6 个唯一 GET call site；全部 read-only；无需 approval；binding succeeded、contract ready、revision 一致 | 只 invoke 一次，run catalog `0 -> 1`；8/8 completed，`lastSuccess=true`；首个 Base 输出与 final output 非空；audit 无 auth、authority、receipt、readiness、admission 或重复启动错误 | #3161 的 `nyxid_proxy -> code_execute` 功能主链通过；未发消息、未建 schedule；不外推到当前文件或旧 Base 资源 |
| P1 `invoice_file_chain.v5.workflow.json` | exact current JSON；5 个唯一 call site，4 read-only + 1 write；sanitized PNG；`submit=false`；fresh binding/contract/revision 一致 | 只 invoke 一次；14/14 实际步骤 completed，`lastSuccess=true`，final output 非空；audit 无 auth、authority、receipt、readiness、admission 或 step error | 图片抽取、只读 lookup、preview presentation 通过；唯一 write call site 及完整提交分支均未执行，无 approval、无 Lark 写入 |
| PDF attachment probe | 无副作用 PDF 输入 | run catalog +1；2/2 completed，`lastSuccess=true`；extract output 与 final output 非空；audit 无错误 | PDF 附件接收与抽取功能通过 |
| #3290 时间连续性对照 | 同一 P2 member/binding/definition；同一 preview request body；另一个已绑定 P1 | P2 14:09:19 为 14/14 completed 且业务复算一致，14:18:27 为 7/8 / `NYXID_PROXY_HTTP_502`；14:20-14:42 同一 preview 连续 5 次 `NYXID_ADMISSION_SOURCE_CREDENTIAL_REQUIRED`；P1 0/27 / `Forwarding failed` | 当前 `regression-blocked`；证据来自 issue/同事运行记录，不冒充本仓库独立复验；历史成功保留但不证明当前 availability |

明确不能写成“当前已成功”的项：P2/P1 时间连续性、P2 send workflow、P1 v6、durable/weekly schedule 和 P1 v2 旧定义。前三类源副作用分支受安全、合成资源或 authority 边界限制未运行；时间连续性则已由 #3290 观察到回归。Risk 28 的一次 exact P1 成功、Risk 29 的未配置 P2 合成环境以及 Risk 40 与 Risk 41 的副作用约束都没有覆盖成功后重绑、member 变化、rollout 或 silo relocation。下一条连续性 case 必须同时证明 source-readable caller credential 与 delegation credential 分离可解析、同一 exact source 在切换前后两次 preview + run、P2 14/14 复算、P1 首步 forwarding 与 27 步进展，并保存脱敏 deployment/silo transition 证据。真实 Lark attachment/skill lookup canary 已由 Case 19 / Risk 24 严格验证，不属于该清单。

## Managed codex_exec 修复与生产复验

案例 11 的固定 managed probe 没有修改 workflow payload。历史失败与恢复证据继续保留，但当前判定只采用 Ready `eead35c0` 上的最新 committed read model；历史成功不能覆盖当前 capacity failure。

| 阶段 | 可审计证据 | 状态 |
|---|---|---|
| 历史回归 | 镜像 `0c4ff023` 上账号 readiness 为 enabled、eligible、active、`execution_ready=true`，但两次运行都在 `execute_probe` 以 `codex_execution_admission_denied` committed `failed`（state 31） | 排除 workflow 输入漂移与账号未就绪 |
| 根因 | Aevatar 把 managed Agent Key 放入 `Authorization: Bearer`；NyxID 的 `forward_access_token=true` 又把同一 bearer 转发给 chrono-sandbox，下游将其作为错误的访问令牌并返回 401 | 代理认证与下游 bearer 语义冲突 |
| 历史代码修复 | 提交 `f7f543c51` 增加 bounded `X-API-Key` 代理入口，managed transport 不再发送 `Authorization`，Agent Key 不进入 body；已直接推送 `origin/feature/integrate` | 已提交、推送并随 `f7f543c5` 部署 |
| 聚焦验证 | `NyxIdApiClientBoundedProxyTests` 3/3、`NyxIdManagedCodexChronoTransportTests` 16/16 通过；`test_stability_guards.sh`、docs lint 与 `git diff --check` 通过 | 认证 header、密钥边界与 transport 契约通过 |
| 历史生产恢复 | 通过 `scripts/production_validate.rb` 和 `nyxid proxy request aevatar` 完成 preview 与真实运行；run hash `fa77c0c49035`，committed `completed`、`terminalSuccess=true`、state 179、30/30 步 | 历史恢复证据保留 |
| 历史固定成功契约 | `status=succeeded`、`target=managed_sandbox`、裁剪后 `output=CODEX_EXEC_READY`、`exit_code=0`、非空且已脱敏 `diagnostic_id` 全部命中；五项证据由单个并行 `foreach` 归一化，`parallel_check_count=5`，`side_effects=false` | 仅说明该部署曾成功 |
| 当前兼容修正 | `6558db8db` 允许共享 UserService 使用 bearer forwarding，同时继续强制 `inject=true` 与 scope=`proxy:*`；Ready `6558db8d` 为 1/1、0 restart，UserService 独立回读为 `true/true/proxy:*` | 普通执行与 managed readiness 配置兼容 |
| 当前生产终态 | Ready `eead35c0` 为提交 `eead35c089758b26f7b0fd4c277dbbe71815b0cc`、1/1 Ready、0 restart；fresh run `106ecf7b750a` 在 `execute_probe` committed `failed`、state 31、4/4，稳定错误仍为 `codex_execution_capacity_unavailable`，且未观察到 allowlisted upstream code。此前 Ready `6558db8d` 的 run `39a374f8815a` 及 Ready `6a656d75` 的 `705a69901de5`、`4caa726585f6` 同码失败，有界日志将最近 transport 边界确认为 HTTP 502 / `managed_proxy_unavailable` | 当前 capacity blocker |
| Health 边界 | 同一 UserService 的 `/health` 返回 `status=healthy`、`opensandbox_connected=true`，只证明路由和 OpenSandbox 连接；不能外推 execute capacity | 停止无证据重复重试 |
| 当前严格结论 | 新 Ready 上 preview 通过，但 fresh run 无 final artifact、approval 或副作用，固定 output、五项 gate 与 parallel=5 无法在当前部署证明 | Case 11 已验证阻塞 |

## Durable schedule 修复进度

本节同时保留 2026-08-06 SGT 在 `b010ba614` / `b010ba61` 上的历史工程修复证据，以及 2026-08-07 SGT 在当前 Ready `4c0596c7` 上的 fresh NyxID 端到端复验。新证据证明当前部署，历史证据保留回归与构建上下文，两者不相互覆盖。

| 阶段 | 可审计证据 | 状态 |
|---|---|---|
| 当前 Ready fresh 复验 | `4c0596c7` 上 fresh 取得 1 workflow / 6 GET 的 read-only Durable confirmation 与 typed `accepted/pending_binding`；binding state 7、provisioning state 11 / attempt 2 committed `succeeded`。Owner-scoped detail 确认 schedule enabled、Cron `* * * * *`、`Asia/Singapore`；1 次自然触发的 run hash `b9859494e2a9` 为 11/11 committed `completed`（state 73），六路 live Base、周度 2340/2400、月度 9360/9600、over/watch 1/1 和无副作用全命中。Typed DELETE 后 detail 不存在、owner list 0，跨下一分钟 run `1 -> 1` | 当前生产端到端通过 |
| 历史基线 | 案例 15 schedule endpoint 返回 HTTP 502，没有 typed schedule receipt | 已被新入口证据替代，保留作回归对照 |
| Actor 实现 | 请求侧只提交无 secret 的 intent；`StudioMemberGAgent` 等待精确 binding revision，以 durable self-timeout 处理 projection lag；后台按 `VerifiedBindingId` 重签短期 token；拒绝 stale attempt completion，binding failed/rejected 会终止 provisioning | `748f98e7d` 已提交、推送并部署 |
| 真实验收入口 | 无 token请求返回 HTTP 200 `confirmation_required`，列出 6 个只读且允许 Durable 的固定 call site；相同 payload 加 fresh token 后返回 HTTP 202 typed receipt，状态为 `pending_binding`，binding run 和 provisioning ID 均非空 | 入口与 admission 通过 |
| 历史 authority 回归 | `f7f543c51` 部署只注册 `UnavailableNyxIdScheduledOperationAuthorizationPort`；binding succeeded 后 provisioning 以 `NyxIdOperationAuthorityContractUnavailable` committed failed，schedule/operation ID 为空 | 已由新镜像修复，保留作回归对照 |
| 源码后续修复 | `7a7781067` 已进入 `origin/feature/integrate`，并在历史 `b010ba614` / `b010ba61` 部署完成验证：完整 Durable proof、binder grant 与 service catalog 校验通过后，仅 binder-attested `READ_ONLY` GET/HEAD/OPTIONS 跳过独立 operation-authority preview；NyxID runtime proxy 仍逐次校验当前权限，POST、WRITE 与 DESTRUCTIVE 继续 fail-closed | 精确适用于案例 15 的 6 个 GET；历史生产已验证 |
| 查询与回执 | member read model 可见；binding committed `succeeded`（state 7），provisioning 第 2 次 attempt committed `succeeded`（state 11）；schedule/operation ID 均非空。schedule 回读为 enabled，canary Cron `* * * * *`、时区 `Asia/Singapore` | Durable 创建与读取通过 |
| 历史真实触发与清理 | 六次非 manual cron fire 后 `fireCount=6`、`failureCount=0`，六个 workflow run 均 completed；抽查 run 11/11 committed `completed`（state 73），最终 artifact 命中六路 live Base、周度 2340/2400、月度 9360/9600、over=1、watch=1。NyxID DELETE 返回 typed accepted receipt，list 归零，跨下一分钟 run count 保持 `6 -> 6` | 历史 Durable schedule 六次触发闭环通过 |
| 编译、镜像与门禁 | `b010ba614` 已普通推送 `origin/feature/integrate`；Release publish、真实 `linux/amd64` Docker build、镜像内 `.NET 10.0.10 linux-x64`、architecture/test-stability guards 和排除 3 个本机 Redis 版本契约用例后的 solution tests 均通过。旧 `7a7781067` 验证工作树的 23/23、1730/1730、152/152、Mainnet DI composition 1/1、Studio DI/executor 11/11、Capabilities 642/642 作为历史修复证据保留 | 历史部署可构建；新旧测试证据边界已标明 |
| 剩余边界 | 本次只证明公开案例 15 的六个 binder-attested GET；写入型 Durable 仍需正式 `INyxIdScheduledOperationAuthorizationPort`。`~/workflows` 的源 durable/weekly schedule 没有运行 | 不外推到源定义或写入型排程 |

## 新增案例与真实结果

| 案例 | 目标能力 | 静态/preview | 直接 runtime | 结论 |
|---|---|---|---|---|
| 11 | managed `codex_exec` | 当前 `eead35c0` preview 通过；payload 与 canonical sample 一致 | fresh run `106ecf7b750a` committed `failed`、state 31、4/4，`codex_execution_capacity_unavailable`，无 artifact；本次未观察到 allowlisted upstream code，`6558db8d` / `6a656d75` 的历史失败、HTTP 502 / `managed_proxy_unavailable` 诊断与 `f7f543c5` 30/30 成功均保留 | 当前已验证阻塞 |
| 12 | 通用 `code_execute` | Ready `6558db8d` preview 通过 | direct run `6659aabee079` committed `completed`、state 31、4/4；祖先 Ready `49cb76e4` 的 fresh Lark run `ebe0e10241f0` committed `completed`、state 33、4/4；两者均命中 `structured_receipt=true`、`total_cents=16623`、`side_effects=false` | direct 与 Lark 全链覆盖 |
| 13 | 图片/PDF OCR、发票规则、历史去重 | 通过 | committed `completed`，`stateVersion=82` | 覆盖 |
| 14 | Lark `contact/v3/users/batch_get_id` | preview 通过；`approvalRequired=true` 且 `approvalEnforcement=bind_time_confirmation` | committed `completed`，`stateVersion=25`，`resolved_count=1`、`identifiers_redacted=true` | 覆盖；批准在 bind 时兑现 |
| 15 | 六路 Base、预算周报/月报、schedule | 通过 | 当前 Ready `4c0596c7` 上 binding/provisioning succeeded，owner-scoped schedule detail 可读；1 次自然 cron 的 workflow 11/11 committed `completed`（state 73，`b9859494e2a9`），DELETE 后 detail 消失、list 0 且 run count `1 -> 1`；历史 `b010ba61` 六次触发证据保留 | 核心业务与公开 Durable schedule 当前端到端通过 |
| 16 | managed workflow NyxID provider receipt | 静态与 preview 通过；单次 `get`、read-only、无需批准 | committed `completed`，`stateVersion=31`，4/4 步 | #3161 receipt/runtime 最小回归通过；源 P2 no-send 另行补齐 authority 分支 |
| 17 | POST search bind-time 批准契约 | 静态与 preview 通过；单次 `post`、write、`approvalEnforcement=bind_time_confirmation` | committed `completed`，`stateVersion=31`，`approval_resumed=true`、`side_effects=false` | 覆盖；#3184 口径已澄清 |
| 18 | `guard`、`conditional`、`while` 三个确定性原语 | 静态与 preview 通过；无外部调用、无副作用 | committed `completed`，`stateVersion=92`，15/15 步，`leading_control=breach_notice` | 覆盖；并由此定位并修复 `while` 挂起缺陷 |
| 19 | Lark Bot 入站附件与确定性文件契约 | 静态与 preview 通过；0 个外部 call site；public skill `1.1` | direct run `e6d17331400b` committed `completed`、`stateVersion=30`、4/4；fresh Lark run `03c3f4ded68e` committed `completed`、`stateVersion=32`、4/4，typed artifact 精确命中 | direct 与 Lark workflow 均覆盖；114 字节文件卡片与 113 字节 committed extraction 分层记录；无副作用 |
| 20 | `map_reduce` 与 `cache` | 静态与 preview 通过 | committed `completed`，`stateVersion=89`，15/15 | 覆盖 |
| 21 | 审批窗口完整性 | 2 个只读 GET | committed `completed`，`stateVersion=49`，7/7；legacy 36 vs active 48 | 旧查询窗口已过期，需重基线 |
| 22 | fixture 漂移体检 | 4 个只读 GET | committed `completed`，`stateVersion=55`，8/8；`fixtures_intact=true` | 当前基线通过 |
| 23 | attested read-only POST | `effectiveRisk=read_only`、0 approval | committed `completed`，`stateVersion=31`，4/4 | 首次证明声明只读 POST 无运行期审批 |
| 24 | 单次 runtime tool approval | write；bind + run-time approval | committed `completed`，5/5；resume=1 | 通过；新增 1 条探针记录 |
| 25 | 连续 runtime tool approval | 2 个 write call site | committed `completed`，8/8；resume=2 | 通过；新增 2 条探针记录 |
| 26 | inline `workflow_call` definition bundle | 通过；1 个固定 inline definition；0 external call site | Ready `4c0596c7` 上 committed `completed`，state 44、5/5；run hash `07f1fc930866` | child definition resolved/completed，严格 artifact 命中，无副作用 |
| 27 | deterministic `parallel` fan-out/fan-in | 通过；三路固定 worker；0 external call site | Ready `4c0596c7` 上 committed `completed`，state 86、14/14；run hash `5b0e99a928f5` | 3 个 receipt 与 merge order 命中，无副作用 |
| 28 | deterministic `race` | 通过；三路固定 candidate；0 external call site | Ready `4c0596c7` 上 committed `completed`，state 38、6/6；run hash `ebe447a8479b` | first success 与 later completions ignored 命中，无副作用 |

## Ornn 发布证据

29 个 skill 均采用 Ornn validator 接受的 `SKILL.md + assets/*.yaml` 布局，且主 asset 与公开 workflow 字节一致；Case 26 另带固定 inline 子定义 asset。本轮 missing-only 发布前先校验全部 29 个包并精确跳过 28 个既有项，只创建并公开 Case 29；发布后的正式 verify-only 与独立 catalog 验证器均确认 29/29 服务端格式、精确名称、版本和 public 状态一致，缺失/private/version mismatch 均为空。

本地 Aevatar 源码的 `SkillWorkflowExtractor` 已包含 `assets/*.yaml` fallback。历史生产 `/api/chat` 中 01、12、13、14、15 都完成过 search、skill load、typed mount approval 和 workflow start；Ready `6558db8d` 上 Case 12 又 fresh 完成同一全链并读取严格 committed artifact，用户可见 Ornn/聊天阻塞已关闭。案例 15 又在镜像 `d7844b5e` 上验证 artifact 工具可使用 workflow start 同时返回的 actor identity 读取 committed artifact，不再依赖最终一致的短 run binding。

## `/api/chat` 自然语言证据

最近代表对照（Case 01 保留最近严格成功；Case 12 在 Ready `6558db8d` fresh 复验）：

| 案例 | Ornn / mount / start | committed 终态 | 严格判定 |
|---|---|---|---|
| 01 | 全部成功 | run `535e9029486f`，13/13 `completed` | `validated`，`ready_for_review=true`、`side_effects=false` |
| 12 | 全部成功 | run `6fa89cd62b15`，state 31、4/4 `completed` | `validated`，`total_cents=16623`、`side_effects=false` |

以下 5/5 表格为 Ready `ee031038` 的历史基线，用于证明同一路径曾严格通过；当前 Case 12 已有更新的 fresh 成功证据：

| 案例 | Assistant 回合 | Ornn/skill | workflow | typed artifact 判定 |
|---|---|---|---|---|
| 01 | completed | 搜索、精确加载、mount approval 成功 | 已启动 | `validated`，13/13，`stateVersion=80` |
| 12 | completed | 搜索、精确加载、mount approval 成功 | 已启动 | `validated`，4/4，`stateVersion=31`，`total_cents=16623`；模型文案陈旧但不覆盖 committed artifact |
| 13 | completed | 搜索、精确加载、图片 file ref 成功 | 已启动 | `validated`，12/12，`stateVersion=82` |
| 14 | completed | 搜索、精确加载、mount approval 成功 | 已启动 | `validated`，3/3，`stateVersion=28`，`resolved_count=1` |
| 15 | completed | 搜索、精确加载、mount approval 成功 | 已启动 | `validated`，11/11，`stateVersion=73`；最终 committed artifact 已由 Assistant 正确报告 |

`/api/chat` 的成功工具在公开 SSE 中仍可能只暴露 `TOOL_CALL_END.result="completed"`。验证器从 typed start receipt 保留 run identity，再查询 committed workflow current state；即使 Assistant 文案仍写 pending，也只按 committed 状态判定。当前 Case 12 正是按 committed `completed` 与严格 artifact 判绿，而不是按聊天回合或模型文案。`d7844b5e` 上的案例 15 进一步证明 Assistant 自身最终也读取并报告了 committed artifact，`artifactPendingReportedAsFinal=false`。

## `/api/chat` 与 Lark Bot

`/api/chat` 直接通过 NyxID 用户身份进入 Aevatar SSE，可验证 Assistant、工具目录、Ornn、workflow 启动和 artifact 查询。Lark Bot 在此基础上还包括：

- Lark webhook 验签和事件转换；
- NyxID channel relay 与 Bot 注册；
- platform conversation 到 agent 的映射；
- 发送者身份解析；
- Agent reply 经 relay 回传 Lark。

因此 `/api/chat` 成功不能替代 Lark transport 证据；Lark 中出现回复也不能证明 workflow 终态成功。本轮两类证据已经分别取得。Case 20/21/22 又分别证明 mount 批准、mount 拒绝和 workflow 运行期工具批准的 channel callback continuation；三项均按 typed receipt、启动计数与 committed artifact 判定，而不是按 Bot 文案判定。更早的 sender service scope 三次失败只作为历史 resource-narrowing 诊断保留，不覆盖当前 fresh channel 结果。

祖先 Ready `49cb76e4` 完成一次 Case 12 合成无副作用 Lark canary：发送前目标 workflow catalog 基线为 10，只批准 1 张新的非 destructive `use_skill` 卡；窗口内精确新增 1 个 `safe_code_execute_validation` run。run hash `ebe0e10241f0` committed `completed`、state 33、4/4，首个工具输出存在，typed artifact 精确命中 `case=safe_code_execute_validation`、`success=true`、`structured_receipt=true`、`total_cents=16623`、`side_effects=false`。Bot 回复 relay 可见，但严格成功只采用 committed detail；公开证据未保存 message、approval、run、member、actor 或 UUID 原值。

案例 19 的 114 字节合成 JSON 已完成 fresh Lark canary，public skill `1.1` 已精确回读。隔离基线有 6 条目标 run，执行后只新增 1 条；run hash `03c3f4ded68e` committed `completed`、state 32、4/4。Lark 文件卡片显示 114 字节，下载后的 committed descriptor/extraction 因尾随 LF 归一化为 113 字节；typed artifact 精确命中 `lark_bot_ingress_validated=true`、文件名/正文/SHA、脱敏与无副作用断言。历史 `service_catalog_missing` 与不完整 artifact 继续保留为恢复过程，不覆盖最新严格通过，也没有原始 run、message、file 或 actor ID 进入公开文件。

## 当前阻塞与待复测项

1. Managed `codex_exec` capacity：当前 Ready `eead35c0` 的 fresh run `106ecf7b750a` 仍以 `codex_execution_capacity_unavailable` committed failed，且本次未观察到 allowlisted upstream code；祖先 Ready `6558db8d` / `6a656d75` 的同码失败已将最近 transport 边界确认为 HTTP 502 / `managed_proxy_unavailable`。同 service health、普通 `/execute` 和祖先 Ready 的 fresh Lark Case 12 绿色都不证明 managed execute capacity。只有 deployment、远端或 capacity 证据变化后才重跑。
3. 步骤数据可在同一 template 内改选目标资源（尚无 issue）：Risk Case 34 的原判定已撤回——`path_params` 槽位取值模板化是平台契约允许形态（#2984 方案 C、PR #2996、#3071），selector 的 `path_template` 仍逐字静态并进入 `request_contract_digest`，运行期只做单段安全与 schema 校验。残留风险是槽位值本身不受绑定期约束：受上游数据影响的步骤输出可以在同一 template 下改选目标资源（例如任意 Base `app_token`），凭证边界仍是 NyxID 的 exact UserService。是否需要绑定期 pin 或槽位值白名单，待平台确认。
4. Lark Bot 历史 sender service grant：早期三次 contact workflow 在批准后以 `NYXID_PROXY_SERVICE_SCOPE_FORBIDDEN` committed failed，定位到 authorization-code resource narrowing；该历史诊断继续保留。当前 fresh Case 20/21/22 已分别严格通过 mount 批准、mount 拒绝和 workflow tool approval channel 契约，Risk 23 也在 Ready `4c0596c7` 上取得稳定 `approval_denied` 的运行期拒绝证据，因此不再把历史症状列为当前 blocker。
5. 财务源定义的安全边界：P2 send、P1 v6、源 durable/weekly schedule 和 P1 v2 旧定义仍未运行。公开验收案例 15 的 schedule 已通过，但不能替代这些源副作用或 authority 分支。Case 19/Risk 24 已关闭，不再列为待复测项。

## #3161 与 #3184 定向回归

截至 2026-08-05，[`#3161`](https://github.com/aevatarAI/aevatar/issues/3161) 已关闭，[`#3184`](https://github.com/aevatarAI/aevatar/issues/3184) 仍开放。二者都经历过“前一层修好后暴露下一层”的过程，因此不能只验 preview 或一个 HTTP ACK。

Case 16 的 production preview 确认只有一个 `get` 调用点、`effectiveRisk=read_only`、`approvalRequired=false`。真实 run committed `completed`，`stateVersion=31`，4/4 步完成，首个 tool step 输出非空，最终 typed artifact 为 `success=true`、`provider_response_verified=true`、`side_effects=false`，没有 auth、authority、receipt、readiness 或 admission error。随后 P2 no-send 同结构定义以 6 个唯一 read-only call site、单次 invoke 和 8/8 committed completion补齐过 `nyxid_proxy -> code_execute` 主链。当前 service 已恢复为 `true/true/proxy:*`，Case 12 direct、`/api/chat` 与 `/execute` 最小 probe 三层 fresh 成功，普通 `code_execute` 当前可用。

Case 17 使用不会修改数据的 Base `records/search` POST，但保留 POST 的保守 write 风险。Production preview 确认单次 `post`、`approvalRequired=true` 且 `approvalEnforcement=bind_time_confirmation`。历史 state 34 run 曾收到 `aevatar.tool_approval.pending` 并用 nested `toolApproval` 身份 resume；aevatar `5dd48629` 之后 proof-bound workflow 调用不再产生 per-run pending，批准改由 bind 时的 explicit-request confirmation 兑现，`20d9ba41` 上 committed `completed`（state 31）。拒绝分支因此不再经由 per-run resume 到达，durable preview 仍需单独验证。

Case 16、可访问 Base 的 P2 no-send 同结构链与 exact P1 v5 `submit=false` 的当前结论为通过。旧 Base 资源、P2 send、P1 submit、P1 v6 和 durable schedule 不由此外推。Case 17 在澄清后的 bind-time 契约下判定为通过；拒绝终止与 durable preview 也不由此外推。

## #3182 证据边界

`#3182` 未解决时，不能用直接 workflow committed 成功替代 Ornn + 自然语言链证据。Ready `ee031038` 的历史 `/api/chat` 基线为 5/5 严格 `validated`；Ready `6558db8d` 上 Case 12 又 fresh 完成 Ornn search、精确 mount、workflow start 与 committed artifact，最近代表对照现为 2/2 validated。

因此，`/api/chat` 的 mount/admission、run identity 和模型绕过已由当前镜像上的案例 14 新生产证据关闭；issue 是否关闭应由其验收范围决定，不能反过来否定本轮证据。Lark Bot transport 已独立验证，Case 20/21/22 已取得三条 fresh 严格证据；历史三次 sender scope 失败仅用于说明 authorization-code resource narrowing，不再覆盖当前 channel 状态。

## 证据位置

- Preview 摘要：`validation/production-preview-2026-08-04.json`
- Runtime、Ornn、`/api/chat` 与 schedule 摘要：`validation/production-validation-2026-08-05.json`
- 新增 21-25 生产证据：`validation/production-validation-2026-08-06-cases-21-25.json`
- 新增 26-28 生产证据：`validation/production-validation-2026-08-07-cases-26-28.json`
- 风险与准入机器摘要：`validation/risk-validation-2026-08-06.json`
- 交互分析页：`report/index.html`
