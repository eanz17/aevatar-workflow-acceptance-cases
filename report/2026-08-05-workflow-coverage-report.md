# 工作流验证与能力覆盖报告

报告日期：2026-08-05。

## 路径与统计口径

用户最初提到的 `~/Code/workflows` 当前不存在。本报告实际比较：

- 验收仓库：`/Users/chronoai/Code/aevatar-workflow-acceptance-cases`；
- 源目录：`/Users/chronoai/workflows`。

源目录共有 43 个带 workflow 形态的可解析定义，其中两个是带 `nodes/connections` 契约的 n8n JSON。本轮按要求排除 n8n，只比较其余 41 个定义。41 个定义包含旧版本、派生版本和 Ornn 内嵌副本，不能用文件数直接计算功能覆盖率；本报告将它们归并为 7 个版本族。

## 总结

- 17/17 个公开 workflow 通过本地静态校验和 production explicit-request preview。
- 最近一次 17-case 全量回归使用镜像 `0c4ff023`；案例 11 随后在修复镜像 `f7f543c5` 上完成定向复验。按逐案例最新证据，17 个终态均为 committed `completed`，严格判定为 15 个通过和 2 个审批契约回归；这不表示 `f7f543c5` 已整体重跑 17 个案例。
- 本地 17/17 个 Ornn skill 与 workflow 一一对应；原有 15/17 个通过服务端格式校验并公开回读，新增两个尚未发布。
- 13 已补齐合成图片/PDF、发票字段归一化与财务去重规则；14 精确覆盖 Lark contact API；15 补齐预算周报/月报公式与 schedule 契约；16、17 分别针对 #3161 和 #3184 增加最小回归探针。
- `/api/chat` 自然语言验证 5 个代表案例，4 个取得 committed `completed` 和业务断言，1 个取得 committed `failed` 和稳定 typed blocker。
- 五个案例均按 search-first 顺序经过精确 skill 加载、typed mount approval、workflow 启动和 committed observation，重复 tool start call ID 为 0。
- `/api/chat` 与 Lark Bot 共用 Assistant/Ornn/workflow 核心；Lark Bot 已独立覆盖 webhook、NyxID channel relay、会话映射、Lark 回传和 typed approval resume。Developer App 默认项追加 `api-lark-bot` 后的 fresh `/init` 已完成，但第三次新镜像重试仍在 `resolve_contact` 以 `NYXID_PROXY_SERVICE_SCOPE_FORBIDDEN` committed failed；根因已收敛到 authorization-code resource narrowing。
- 源财务定义在镜像 `71a38ff5` 上的 post-fix 证据继续有效：P2 no-send 8/8、P1 v5 sanitized image + `submit=false` 14/14 实际步骤、PDF probe 2/2，均为 terminal `completed`、`lastSuccess=true` 且 final output 非空。
- 当前部署 `f7f543c5` 健康，包含 managed Codex NyxID `X-API-Key` 修复和 Durable schedule 提交 `748f98e7d`；`0c4ff023` 的 17-case 全量回归仍作为其余案例基线。Fresh schedule 复验已把历史 HTTP 502 推进为 HTTP 200 confirmation、HTTP 202 typed receipt、binding succeeded 和 committed provisioning failure；新 blocker 是 `NyxIdOperationAuthorityContractUnavailable`，没有创建 schedule。

## 源版本族映射

| 源版本族 | 非 n8n 定义数 | 新仓库案例 | 已覆盖语义 | 生产边界 | 判断 |
|---|---:|---|---|---|---|
| Base 探针 | 3 | 04、05、15-17 | 记录 GET、多源读取、受保护 POST、provider receipt、typed approval resume | 16 通过；17 最新运行缺少 per-run approval identity，历史批准路径保留 | 覆盖 / 审批契约回归 |
| 原语与执行探针 | 5 | 01、03、11、12 | `assign`、`transform`、分支、`foreach`、managed `codex_exec`、固定 `code_execute` | 11 在 `f7f543c5` 上恢复；12 的连续成功证据保留 | 覆盖 |
| Lark Onboarding | 1 | 06 | Base 申请、审批 payload、创建与实例回读 | 源 Aevatar e2e 语义已覆盖 | 覆盖 |
| 发票审批 | 7 | 02、03、09、13、14 + 源 P1 v5 | 图片/PDF、提取、SGD/金额/供应商规则、历史、去重、审批、contact | 源 v5 的 sanitized image + `submit=false` 已 14/14 完成；审批提交、v6 和旧 v2 未运行 | 功能主链覆盖 / 写入边界未运行 |
| 预算监控 | 5 | 04、08、15 + 源 P2 no-send | 六路 Base、预算差异、阈值、周/月摘要、消息 | 源 no-send 已 8/8 完成；公开案例 15 schedule 在 authority contract 阶段 failed；源 send 与源 durable schedule 未运行 | 只读主链覆盖 / 排程已验证阻塞 / 源副作用边界未运行 |
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

## Durable schedule 修复进度

本节同时记录历史基线、已部署工程修复和 2026-08-06 SGT 的 fresh NyxID 定向复验。历史 production 证据仍保留 HTTP 502，最新机器摘要则明确记录 `f7f543c51` 上的新状态；新旧证据不会相互覆盖。

| 阶段 | 可审计证据 | 状态 |
|---|---|---|
| 历史基线 | 案例 15 schedule endpoint 返回 HTTP 502，没有 typed schedule receipt | 已被新入口证据替代，保留作回归对照 |
| Actor 实现 | 请求侧只提交无 secret 的 intent；`StudioMemberGAgent` 等待精确 binding revision，以 durable self-timeout 处理 projection lag；后台按 `VerifiedBindingId` 重签短期 token；拒绝 stale attempt completion，binding failed/rejected 会终止 provisioning | `748f98e7d` 已提交、推送并部署 |
| 真实验收入口 | 无 token请求返回 HTTP 200 `confirmation_required`，列出 6 个只读且允许 Durable 的固定 call site；相同 payload 加 fresh token 后返回 HTTP 202 typed receipt，状态为 `pending_binding`，binding run 和 provisioning ID 均非空 | 入口与 admission 通过 |
| 查询与回执 | member read model 可见；binding committed `succeeded`（state 7），provisioning 首次 attempt committed `failed`（state 9），失败码为 `NyxIdOperationAuthorityContractUnavailable`，schedule/operation ID 均为空 | 持久终态可审计，schedule 未创建 |
| 根因 | `AddScheduledInvocationAuthorization` 当前只注册 `UnavailableNyxIdScheduledOperationAuthorizationPort`，其固定返回 `AuthorityContractUnavailable`；生产日志确认 provisioning failed event 已提交 | Aevatar 缺少真实 operation authority provider |
| 测试与门禁 | 23/23、1730/1730、152/152、Mainnet DI composition 1/1、Studio DI/executor 11/11 通过；solution build、架构/边界门禁与 `slow_test_guards.sh` 通过。全量 solution test 发现的 fixture、boot、admitted terminal 修复尚待完整复测；3 个 Redis 测试仍要求 7.2.3 | 定向与静态门禁通过；全量测试未绿 |
| 下一步 | 实现并注册真实 `INyxIdScheduledOperationAuthorizationPort`，复跑全量测试并重新部署；之后必须使用新 payload 验证 provisioning `succeeded`、非空 schedule/operation ID 和至少一次真实触发 | 仍是生产已验证阻塞 |

## 新增案例与真实结果

| 案例 | 目标能力 | 静态/preview | 直接 runtime | 结论 |
|---|---|---|---|---|
| 11 | managed `codex_exec` | 通过；payload 与 canonical sample 一致，账号 readiness=ready | `f7f543c5` 上 committed `completed`，`stateVersion=179`，30/30 步，`CODEX_EXEC_READY` 与五项 gate 命中 | 已恢复 |
| 12 | 通用 `code_execute` | 通过 | 连续两次 committed `completed`，`stateVersion=31`，`total_cents=16623` | 已恢复 |
| 13 | 图片/PDF OCR、发票规则、历史去重 | 通过 | committed `completed`，`stateVersion=82` | 覆盖 |
| 14 | Lark `contact/v3/users/batch_get_id` | preview 通过且 `approvalRequired=true` | 业务 committed `completed`，`stateVersion=25`，但无 typed pending/resume | 契约回归；历史 state 28 批准路径保留 |
| 15 | 六路 Base、预算周报/月报、schedule | 通过 | workflow committed `completed`，`stateVersion=73`；schedule 入口与状态链通过，provisioning 因 authority provider 缺失而 committed `failed` | 核心业务覆盖，durable schedule 已验证阻塞 |
| 16 | managed workflow NyxID provider receipt | 静态与 preview 通过；单次 `get`、read-only、无需批准 | committed `completed`，`stateVersion=31`，4/4 步 | #3161 receipt/runtime 最小回归通过；源 P2 no-send 另行补齐 authority 分支 |
| 17 | POST search typed pending/resume | 静态与 preview 通过；单次 `post`、write、需要批准 | 业务 committed `completed`，`stateVersion=31`，但无 typed pending/resume | #3184 契约回归；历史 state 34 批准路径保留 |

## Ornn 发布证据

17 个 skill 均采用 Ornn validator 接受的 `SKILL.md + assets/*.yaml` 布局，且 asset 与公开 workflow 字节一致。原有 15 个线上 skill 已通过服务端格式校验，并逐个回读名称、`.1` 版本和 public 状态；新增 16、17 目前只有本地 validator 证据，尚未上传或公开。

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

## 当前阻塞与待复测项

1. Per-run typed approval：Cases 14、17 的 preview 都要求批准，最新运行却没有 typed pending/resume 即 completed；业务 artifact 不能替代批准身份链。Case 17 的拒绝分支因此当前不可达，durable preview 仍未验证。
2. Schedule：`f7f543c5` 已关闭历史 HTTP 502、无 receipt 和状态不可见缺口；fresh NyxID 请求取得 200 confirmation、202 typed receipt 和 binding succeeded，但 provisioning 以 `NyxIdOperationAuthorityContractUnavailable` committed failed。当前 Aevatar 只注册 unavailable fallback，未实现真实 operation authority provider，因此没有 schedule/operation ID，也不能验证真实触发。
3. Lark Bot sender service grant：Aevatar `1.0.10` 为 Released，Bot Enabled、Availability=All，NyxID committed Bot 为 `active`、`webhook_registered=true`。镜像 `8cf280e2` 上的案例 14 直接 run 和 `/api/chat` Ornn mount/run 均 committed `completed`；前两次 Lark Bot 重试也都启动 workflow，并在 typed approval resume 后从 `awaiting_tool_approval` 进入 committed `failed`。失败步骤均为 `resolve_contact`，稳定错误码均为 `NYXID_PROXY_SERVICE_SCOPE_FORBIDDEN`；run 哈希为 `1436a2852f8d`（state 18）和 `e491a2690b03`（state 17）。生产 `aevatar` Developer App 把 `api-lark-bot` 追加到 `default_service_catalog_slugs` 后，fresh `/init` 于 `11:34Z` 创建 allow-all consent 与新 sender binding；镜像 `e30fdd94` 上的第三次 run `93ece1c36951` 仍在 `resolve_contact` 以同一错误 committed `failed`（state 14）。源码契约确认 Aevatar authorize 仍只显式请求 core resources，NyxID 会在 authorization-code 阶段按这些 resources 缩窄 binding；默认项只提供 consent hints。因此该 blocker 已验证，不能再要求用户重复 `/init`。`ornn.skill` mount failure、`scope_workflows_get/list` outcome unverified 和后续 fallback 的 `InvalidWorkflowYaml` 继续作为独立 receipt 缺陷保留。
4. 财务源定义的安全边界：P2 send、P1 v6、源 durable/weekly schedule 和 P1 v2 旧定义仍未运行。上述生产失败来自公开验收案例 15 的 schedule，不是源排程定义；只读 workflow 成功和案例 15 的失败都不能替代这些源副作用或 authority 分支。

## #3161 与 #3184 定向回归

截至 2026-08-05，[`#3161`](https://github.com/aevatarAI/aevatar/issues/3161) 已关闭，[`#3184`](https://github.com/aevatarAI/aevatar/issues/3184) 仍开放。二者都经历过“前一层修好后暴露下一层”的过程，因此不能只验 preview 或一个 HTTP ACK。

Case 16 的 production preview 确认只有一个 `get` 调用点、`effectiveRisk=read_only`、`approvalRequired=false`。真实 run committed `completed`，`stateVersion=31`，4/4 步完成，首个 tool step 输出非空，最终 typed artifact 为 `success=true`、`provider_response_verified=true`、`side_effects=false`，没有 auth、authority、receipt、readiness 或 admission error。随后源 P2 no-send 在 `71a38ff5` 上以 exact YAML preview、6 个唯一 read-only call site、单次 invoke 和 8/8 committed completion 补齐 published-operation authority 主链；audit 同样没有 auth、authority、receipt、readiness、admission 或重复启动错误。

Case 17 使用不会修改数据的 Base `records/search` POST，但保留 POST 的保守 write 风险。Production preview 确认单次 `post`、`approvalRequired=true`。历史 state 34 run 收到 `aevatar.tool_approval.pending` 后，使用事件中的 `stepId` 和 nested `toolApproval.executionId/toolCallId/approvalRequestId` 调用 resume，并 committed `completed`。最新 `0c4ff023` run 则未观察到 pending/resume 即以 state 31 completed；artifact 中的 `approval_resumed=true` 不能替代事件身份链，因此记为 `TOOL_APPROVAL_IDENTITY_NOT_OBSERVED`。拒绝路径当前不可达，durable preview 仍需单独验证。

Case 16 与源 P2 no-send 的当前结论仍为通过。Case 17 保留历史批准路径成功，但最新回归严格判定为契约回归；拒绝终止与 durable preview 不由历史成功外推。

## #3182 证据边界

`#3182` 未解决时，不能用直接 workflow committed 成功替代 Ornn + 自然语言链证据。本轮没有做这种外推，而是在生产镜像 `7ba3fa3e` 上逐个重跑 `/api/chat`：4/5 为严格 `validated`，1/5 为有 committed blocker 的 `typed-failure`。随后在 `d7844b5e` 上再次通过自然语言运行案例 15，验证短 run ID 与 actor identity 分离时仍能读取 committed artifact。

因此，`/api/chat` 的 mount/admission、run identity 和模型绕过已由当前镜像上的案例 14 新生产证据关闭；issue 是否关闭应由其验收范围决定，不能反过来否定本轮证据。Lark Bot transport 已独立验证，三次 Bot 重试也已取得 committed 失败终态；fresh `/init` 已证明 Developer App 默认项不足以改变 authorization-code resource grant。当前边界是平台修复 resource narrowing，以及 channel-only 的 mount/get/list/invalid-YAML receipt 缺陷。

## 证据位置

- Preview 摘要：`validation/production-preview-2026-08-04.json`
- Runtime、Ornn、`/api/chat` 与 schedule 摘要：`validation/production-validation-2026-08-05.json`
- 交互分析页：`report/index.html`
