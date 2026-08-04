# 工作流验证与能力覆盖报告

报告日期：2026-08-04。

## 路径与统计口径

用户最初提到的 `~/Code/workflows` 当前不存在。本报告实际比较：

- 验收仓库：`/Users/chronoai/Code/aevatar-workflow-acceptance-cases`；
- 源目录：`/Users/chronoai/workflows`。

源目录共有 43 个带 workflow 形态的可解析定义，其中两个是带 `nodes/connections` 契约的 n8n JSON。本轮按要求排除 n8n，只比较其余 41 个定义。41 个定义包含旧版本、派生版本和 Ornn 内嵌副本，不能用文件数直接计算功能覆盖率；本报告将它们归并为 7 个版本族。

## 总结

- 15/15 个公开 workflow 通过本地静态校验和 production explicit-request preview。
- 直接生产运行取得 13 个 committed `completed` 和 2 个 committed `failed`；两个失败均有稳定平台 blocker，不是未执行。
- 15/15 个 Ornn skill 通过服务端格式校验、公开发布和按名称回读。
- 13 已补齐合成图片/PDF、发票字段归一化与财务去重规则；14 精确覆盖 Lark contact API；15 补齐预算周报/月报公式与 schedule 契约。
- `/api/chat` 自然语言验证 5 个代表案例，当前没有任何一个满足严格的 typed artifact 成功条件，因此不能宣称 Ornn 自然语言全链路通过。
- `/api/chat` 与 Lark Bot 共用 Assistant/Ornn/workflow 核心，但不覆盖 Lark webhook、NyxID channel relay、会话映射和 Lark 回传。

## 源版本族映射

| 源版本族 | 非 n8n 定义数 | 新仓库案例 | 已覆盖语义 | 生产边界 | 判断 |
|---|---:|---|---|---|---|
| Base 探针 | 3 | 04、05、15 | 记录 GET、多源读取、受保护 POST、typed receipt | 无新增缺口 | 覆盖 |
| 原语与执行探针 | 5 | 01、03、11、12 | `assign`、`transform`、分支、`foreach`、managed `codex_exec`、固定 `code_execute` | `code_execute` 真实运行被 `NYXID_PROXY_UNAUTHORIZED` 阻塞 | 部分覆盖 / 平台阻塞 |
| Lark Onboarding | 1 | 06 | Base 申请、审批 payload、创建与实例回读 | 源 Aevatar e2e 语义已覆盖 | 覆盖 |
| 发票审批 | 7 | 02、03、09、13、14 | 图片/PDF、提取、SGD/金额/供应商规则、历史、去重、审批、contact | contact 缺 `contact:user.id:readonly`；通用代码执行仍阻塞 | 部分覆盖 / 平台阻塞 |
| 预算监控 | 5 | 04、08、15 | 六路 Base、预算差异、阈值、周报/月报、卡片发送 | schedule endpoint 返回 HTTP 502 且无 receipt | 部分覆盖 / 平台阻塞 |
| 旧验收案例副本 | 10 | 01-10 | 新仓库是修复、中文化并取得 committed 证据的权威版本 | 源副本仍保留旧契约 | 覆盖 |
| Ornn 资产副本 | 10 | 01-15 | 15 个 skill 已 public 发布并回读 | `/api/chat` 的 mount、admission、artifact 与模型选路仍未闭环 | 部分覆盖 |

## 新增案例与真实结果

| 案例 | 目标能力 | 静态/preview | 直接 runtime | 结论 |
|---|---|---|---|---|
| 12 | 通用 `code_execute` | 通过 | committed `failed`，`stateVersion=12`，`NYXID_PROXY_UNAUTHORIZED` | 定义与失败传播覆盖，平台执行阻塞 |
| 13 | 图片/PDF OCR、发票规则、历史去重 | 通过 | committed `completed`，`stateVersion=82` | 覆盖 |
| 14 | Lark `contact/v3/users/batch_get_id` | 通过 | committed `failed`，`NYXID_PROXY_HTTP_400` / Lark `99991672` | 精确调用覆盖，权限阻塞 |
| 15 | 六路 Base、预算周报/月报、schedule | 通过 | workflow committed `completed`，`stateVersion=73`；schedule HTTP 502 | 核心业务覆盖，durable schedule 阻塞 |

## Ornn 发布证据

15 个 skill 均采用 Ornn validator 接受的 `SKILL.md + assets/*.yaml` 布局。发布器对每个 ZIP 依次执行服务端格式校验、上传或更新、设置 public、按名称回读，15 项全部完成。

本地 Aevatar 源码的 `SkillWorkflowExtractor` 已包含 `assets/*.yaml` fallback。生产 `/api/chat` 中 01、12 能从 skill 到达 workflow 启动，说明当前问题不是所有 `assets` workflow 都不可发现；14、15 仍在 mount 阶段失败，15 的 inline fallback 进一步在启动前返回 `CAPABILITY_ADMISSION_REBIND_REQUIRED`。

## `/api/chat` 自然语言证据

| 案例 | Assistant 回合 | Ornn/skill | workflow | typed artifact 判定 |
|---|---|---|---|---|
| 01 | completed | 搜索、加载成功 | 已启动 | 查询两次，但 SSE 没有可判定 payload，`unproven` |
| 12 | completed | 搜索、加载成功 | 已启动 | 短 run 查询未物化；完整 actor 的 Observatory 为 committed failed |
| 13 | completed | 未调用 | 未启动 | 模型直接识图作答，`not-started` |
| 14 | failed | 搜索后 mount 失败 | 未启动 | `USE_SKILL_MOUNT_FAILED` |
| 15 | failed | 搜索后 mount 失败 | 未启动 | `USE_SKILL_MOUNT_FAILED`；inline 为 `CAPABILITY_ADMISSION_REBIND_REQUIRED` |

本轮 `/api/chat` 的成功工具在公开 SSE 中只暴露 `TOOL_CALL_END.result="completed"`，不包含可机判 artifact 内容。验证器因此把 01 记为 `unproven`，而不是根据 Assistant 文案中的 pending/completed 推测终态。

## `/api/chat` 与 Lark Bot

`/api/chat` 直接通过 NyxID 用户身份进入 Aevatar SSE，可验证 Assistant、工具目录、Ornn、workflow 启动和 artifact 查询。Lark Bot 在此基础上还包括：

- Lark webhook 验签和事件转换；
- NyxID channel relay 与 Bot 注册；
- platform conversation 到 agent 的映射；
- 发送者身份解析；
- Agent reply 经 relay 回传 Lark。

因此 `/api/chat` 成功不能证明 Lark transport 成功；Lark 中出现回复也不能证明 workflow 终态成功。

## 当前阻塞项

1. `code_execute`：`chrono-sandbox /execute` 生产要求 Bearer，与 catalog `auth_method=none` 不一致。
2. Lark contact：绑定 Bot 缺少 `contact:user.id:readonly`。
3. Schedule：案例 15 的 `/api/workflow/skills/{guid}/schedule` 返回 HTTP 502，没有 typed receipt。
4. Skill mount：14、15 返回 `USE_SKILL_MOUNT_FAILED`，没有 mounted workflow receipt。
5. Capability admission：15 inline fallback 返回 `CAPABILITY_ADMISSION_REBIND_REQUIRED`。
6. Artifact identity：Assistant 得到的短 run ID 不能稳定解析为完整 workflow actor artifact。
7. 模型选路：案例 13 即使明确要求使用 skill，仍直接识图回答。

## #3182 证据边界

`#3182` 未解决时，不能把直接 workflow committed 成功外推成 Ornn + 自然语言链成功。本轮已经把这两层拆开：直接 runtime 有 13 个成功，Ornn 发布有 15 个成功，但 `/api/chat` 严格 workflow validated 为 0/5。

同时，最新生产证据表明 `assets/*.yaml` 并非全局不可用：01、12 已能 mount/start。当前剩余问题更具体地位于复杂 capability mount/admission、短 run identity 到完整 actor 的解析，以及模型是否遵循 skill 调用要求。

## 证据位置

- Preview 摘要：`validation/production-preview-2026-08-04.json`
- Runtime、Ornn、`/api/chat` 与 schedule 摘要：`validation/production-validation-2026-08-04.json`
- 交互分析页：`report/index.html`
