# 工作流验证与能力覆盖报告

报告日期：2026-08-05。

## 路径与统计口径

用户最初提到的 `~/Code/workflows` 当前不存在。本报告实际比较：

- 验收仓库：`/Users/chronoai/Code/aevatar-workflow-acceptance-cases`；
- 源目录：`/Users/chronoai/workflows`。

源目录共有 43 个带 workflow 形态的可解析定义，其中两个是带 `nodes/connections` 契约的 n8n JSON。本轮按要求排除 n8n，只比较其余 41 个定义。41 个定义包含旧版本、派生版本和 Ornn 内嵌副本，不能用文件数直接计算功能覆盖率；本报告将它们归并为 7 个版本族。

## 总结

- 17/17 个公开 workflow 通过本地静态校验；原有 15/17 个通过 production explicit-request preview，新增 16、17 尚未 production preview。
- 直接生产运行取得 13 个 committed `completed` 和 2 个 committed `failed`；新增 16、17 尚未真实运行，不能计入通过或平台阻塞。
- 本地 17/17 个 Ornn skill 与 workflow 一一对应；原有 15/17 个通过服务端格式校验并公开回读，新增两个尚未发布。
- 13 已补齐合成图片/PDF、发票字段归一化与财务去重规则；14 精确覆盖 Lark contact API；15 补齐预算周报/月报公式与 schedule 契约；16、17 分别针对 #3161 和 #3184 增加最小回归探针。
- `/api/chat` 自然语言验证 5 个代表案例，3 个取得 committed `completed` 和业务断言，2 个取得 committed `failed` 和稳定 typed blocker。
- 五个案例均按 search-first 顺序经过精确 skill 加载、typed mount approval、workflow 启动和 committed observation，重复 tool start call ID 为 0。
- `/api/chat` 与 Lark Bot 共用 Assistant/Ornn/workflow 核心，但不覆盖 Lark webhook、NyxID channel relay、会话映射和 Lark 回传。

## 源版本族映射

| 源版本族 | 非 n8n 定义数 | 新仓库案例 | 已覆盖语义 | 生产边界 | 判断 |
|---|---:|---|---|---|---|
| Base 探针 | 3 | 04、05、15-17 | 记录 GET、多源读取、受保护 POST、provider receipt、typed approval resume | 16、17 待 production preview/runtime | 覆盖 / 定向复测待完成 |
| 原语与执行探针 | 5 | 01、03、11、12 | `assign`、`transform`、分支、`foreach`、managed `codex_exec`、固定 `code_execute` | `code_execute` 真实运行被 `NYXID_PROXY_UNAUTHORIZED` 阻塞 | 部分覆盖 / 平台阻塞 |
| Lark Onboarding | 1 | 06 | Base 申请、审批 payload、创建与实例回读 | 源 Aevatar e2e 语义已覆盖 | 覆盖 |
| 发票审批 | 7 | 02、03、09、13、14 | 图片/PDF、提取、SGD/金额/供应商规则、历史、去重、审批、contact | contact 缺 `contact:user.id:readonly`；通用代码执行仍阻塞 | 部分覆盖 / 平台阻塞 |
| 预算监控 | 5 | 04、08、15 | 六路 Base、预算差异、阈值、周报/月报、卡片发送 | schedule endpoint 返回 HTTP 502 且无 receipt | 部分覆盖 / 平台阻塞 |
| 旧验收案例副本 | 10 | 01-10 | 新仓库是修复、中文化并取得 committed 证据的权威版本 | 源副本仍保留旧契约 | 覆盖 |
| Ornn 资产副本 | 10 | 01-17 | 原有 15 个 skill 已 public 发布并回读；新增两个已本地同步 | 16、17 尚未服务端校验或发布；Lark Bot transport 尚未验证 | 部分覆盖 / 发布待完成 |

## 新增案例与真实结果

| 案例 | 目标能力 | 静态/preview | 直接 runtime | 结论 |
|---|---|---|---|---|
| 12 | 通用 `code_execute` | 通过 | committed `failed`，`stateVersion=12`，`NYXID_PROXY_UNAUTHORIZED` | 定义与失败传播覆盖，平台执行阻塞 |
| 13 | 图片/PDF OCR、发票规则、历史去重 | 通过 | committed `completed`，`stateVersion=82` | 覆盖 |
| 14 | Lark `contact/v3/users/batch_get_id` | 通过 | committed `failed`，`stateVersion=15`，`NYXID_PROXY_HTTP_400` / Lark `99991672` | 精确调用覆盖，权限阻塞 |
| 15 | 六路 Base、预算周报/月报、schedule | 通过 | workflow committed `completed`，`stateVersion=73`；schedule HTTP 502 | 核心业务覆盖，durable schedule 阻塞 |
| 16 | managed workflow NyxID provider receipt | 静态通过；preview 待验证 | 未运行 | #3161 最小回归已定义，不能声明生产通过 |
| 17 | POST search typed pending/resume | 静态通过；preview 待验证 | 未运行 | #3184 批准继续与拒绝终止均待 committed 证据 |

## Ornn 发布证据

17 个 skill 均采用 Ornn validator 接受的 `SKILL.md + assets/*.yaml` 布局，且 asset 与公开 workflow 字节一致。原有 15 个线上 skill 已通过服务端格式校验，并逐个回读名称、`.1` 版本和 public 状态；新增 16、17 目前只有本地 validator 证据，尚未上传或公开。

本地 Aevatar 源码的 `SkillWorkflowExtractor` 已包含 `assets/*.yaml` fallback。生产 `/api/chat` 中 01、12、13、14、15 都能完成 search、skill load、typed mount approval 和 workflow start；复杂 capability 的 mount/admission、短 run identity 和模型绕过问题已在镜像 `7ba3fa3e` 上重跑关闭。

## `/api/chat` 自然语言证据

| 案例 | Assistant 回合 | Ornn/skill | workflow | typed artifact 判定 |
|---|---|---|---|---|
| 01 | completed | 搜索、精确加载、mount approval 成功 | 已启动 | `validated`，13/13，`stateVersion=80` |
| 12 | completed | 搜索、精确加载、mount approval 成功 | 已启动 | `typed-failure`，`NYXID_PROXY_UNAUTHORIZED`，`stateVersion=12` |
| 13 | completed | 搜索、精确加载、图片 file ref 成功 | 已启动 | `validated`，12/12，`stateVersion=82` |
| 14 | completed | 搜索、精确加载、mount approval 成功 | 已启动 | `typed-failure`，Lark `99991672`，`stateVersion=15` |
| 15 | completed | 搜索、精确加载、mount approval 成功 | 已启动 | `validated`，11/11，`stateVersion=73` |

本轮 `/api/chat` 的成功工具在公开 SSE 中仍可能只暴露 `TOOL_CALL_END.result="completed"`。验证器从 typed start receipt 保留 run identity，再查询 committed workflow current state；即使 Assistant 文案仍写 pending，也只按 committed 状态判定。

## `/api/chat` 与 Lark Bot

`/api/chat` 直接通过 NyxID 用户身份进入 Aevatar SSE，可验证 Assistant、工具目录、Ornn、workflow 启动和 artifact 查询。Lark Bot 在此基础上还包括：

- Lark webhook 验签和事件转换；
- NyxID channel relay 与 Bot 注册；
- platform conversation 到 agent 的映射；
- 发送者身份解析；
- Agent reply 经 relay 回传 Lark。

因此 `/api/chat` 成功不能证明 Lark transport 成功；Lark 中出现回复也不能证明 workflow 终态成功。

## 当前阻塞与待复测项

1. `code_execute`：`chrono-sandbox /execute` 生产要求 Bearer，与 catalog `auth_method=none` 不一致。
2. Lark contact：绑定 Bot 缺少 `contact:user.id:readonly`。
3. Schedule：案例 15 的 `/api/workflow/skills/{guid}/schedule` 返回 HTTP 502，没有 typed receipt。
4. Lark Bot transport：本轮只验证 `/api/chat`，未覆盖 webhook、NyxID channel relay、会话映射和 Lark 回传。
5. `#3161` 范围边界：issue 已关闭，正向环境和一个旧 binding 已证明 authority drift 消失；原报告方 proxy-delegation-only 旧 scope 的 post-fix 复测仍未出现。Case 16 使用仓库规定的 `nyxid_request`，只能回归共同 receipt/runtime 平面，不能替代 `nyxid_operation` authority 分支。
6. `#3184` resume：pending 状态已经 typed 化并可观察，但原报告方的 resume 在返回 `accepted=true` 后没有推进 state version。当前源码要求三项 approval identity 位于 nested `toolApproval`，并明确规定 `202` 只表示命令进入 actor inbox；仍需 Case 17 的 committed 终态证明。

## #3161 与 #3184 定向回归

截至 2026-08-05，[`#3161`](https://github.com/aevatarAI/aevatar/issues/3161) 已关闭，[`#3184`](https://github.com/aevatarAI/aevatar/issues/3184) 仍开放。二者都经历过“前一层修好后暴露下一层”的过程，因此不能只验 preview 或一个 HTTP ACK。

Case 16 只发出一次只读 Base GET。通过条件是 run committed `completed`、首个 tool step 输出非空、最终 typed artifact 为 `success=true` 和 `provider_response_verified=true`，且不存在 auth、authority、receipt、readiness 或 admission error。它精确回归 #3161 最初的 receiptless runtime 症状；因为新案例必须使用 `capability.nyxid_request`，报告不会把它写成 published `nyxid_operation` authority fallback 的完整覆盖。

Case 17 使用不会修改数据的 Base `records/search` POST，但保留 POST 的保守 write 风险。批准路径必须先收到 `aevatar.tool_approval.pending`，再用该事件的 `stepId` 和 nested `toolApproval.executionId/toolCallId/approvalRequestId` 调用 resume；只有 run committed `completed` 且 `approval_resumed=true` 才通过。拒绝路径必须使用新的 run，committed 终态应明确为 approval rejected，且没有 outbound request。Durable preview 预期仍应得到 typed `DURABLE_AUTHORIZATION_UNAVAILABLE`，不能通过 bind-time confirmation 或人工 approval 推断可调度。

本轮未执行上述 production preview、bind 或 run，因此两个案例均标记“待验证”，不是“已验证阻塞”。

## #3182 证据边界

`#3182` 未解决时，不能用直接 workflow committed 成功替代 Ornn + 自然语言链证据。本轮没有做这种外推，而是在生产镜像 `7ba3fa3e` 上逐个重跑 `/api/chat`：3/5 为严格 `validated`，2/5 为有 committed blocker 的 `typed-failure`。

因此，mount/admission、run identity 和模型绕过是已由新生产证据关闭的历史症状；issue 是否关闭应由其验收范围决定，不能反过来否定本轮证据。Lark Bot transport 仍是明确未覆盖边界。

## 证据位置

- Preview 摘要：`validation/production-preview-2026-08-04.json`
- Runtime、Ornn、`/api/chat` 与 schedule 摘要：`validation/production-validation-2026-08-05.json`
- 交互分析页：`report/index.html`
