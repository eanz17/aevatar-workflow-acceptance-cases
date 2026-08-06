# Aevatar 工作流验收案例

[![验证工作流](https://github.com/eanz17/aevatar-workflow-acceptance-cases/actions/workflows/validate.yml/badge.svg)](https://github.com/eanz17/aevatar-workflow-acceptance-cases/actions/workflows/validate.yml)

本仓库采用“25 个 workflow + 3 个 Lark channel E2E case + 21 个风险验收 case”的口径：25 个公开、安全、可复现的 Aevatar workflow 与 Ornn skill 一一对应；channel case 独立验证 Lark 回调；risk case 验证 catalog、Assistant、源定义、runtime 原语、准入负例和报告一致性。案例覆盖基础原语、文件与图片输入、Lark Bot 入站附件、Base、Lark 审批、Lark 消息、contact、通用代码执行、`codex_exec`、schedule、NyxID provider receipt 和 typed tool approval resume 等能力。

公开 YAML 只保存占位符和合成数据，不包含组织专属 Base、用户、审批、NyxID 资源标识或未脱敏运行 ID。工作流 `name`、步骤 `id`、工具名、API 字段、错误码等技术契约保留英文，其余说明使用中文。

## 当前结论

验证基线日期：2026-08-05；状态更新：2026-08-06。

- 25/25 个 workflow 通过本地 YAML、步骤图、安全边界和专用契约校验；`production_validate.rb` 与 `assistant_validate.rb` 共用 25/25 个严格业务 artifact contract，committed `completed` 本身不再足以判绿。
- 25/25 个已配置定义通过 Aevatar 主网 `interactive` explicit-request preview。旧 01-20 保留既有 committed 基线；21/22/23 在用 `config.local.yaml` 重新物化后 fresh committed `completed`，分别为 7/7、8/8、4/4 且 artifact 精确命中。此前三项同时出现的 `NYXID_PROXY_HTTP_400` 已确认来自共享 `build/workflows/` 被示例配置覆盖，不是 Aevatar 回归；24/25 保留最近一次 5/5、8/8 completed 的 typed approval 证据。
- 新增 21/22/23 无副作用；24/25 在本轮显式授权和 typed approval 下分别完成 1 次、2 次 resume。本轮 Cases 05/24/25 共创建 4 条固定合成 Base 探针记录，随后连同 2 条同契约历史残留精确清理；回读匹配数为 0，未匹配记录未触碰。
- 3/3 个既有 Lark channel E2E case 通过静态契约校验，fresh 严格结果为 1/3：Case 22 在唯一新增 run 上完成 workflow tool approval 与 committed 3/3，artifact 精确命中；Cases 20/21 均在 mount 审批前以稳定 `InvalidWorkflowYaml` 阻塞，run 增量为 0，不能把旧审批卡或 direct workflow 绿色结果外推为通过。
- 案例 19 public skill 已升级并精确回读为 `1.1`。Direct synthetic fixture run hash `e6d17331400b` 为 committed `completed`、`stateVersion=30`、4/4；fresh Lark canary 在 6 条既有目标 run 的隔离基线上只新增 1 条，run hash `03c3f4ded68e` 为 committed `completed`、`stateVersion=32`、4/4，typed artifact 精确命中 `lark_bot_ingress_validated=true`、文件名/正文/SHA-256、脱敏和无副作用断言，严格状态升级为 `validated`。Lark 文件卡片为 114 字节，committed descriptor/extraction 因尾随 LF 归一化为 113 字节；历史 `service_catalog_missing` blocker 已关闭，Risk 24 严格通过。
- 本地 25/25 个 Ornn skill 与 workflow 字节一致，25/25 通过服务端格式校验并按精确名称、版本公开回读。本轮 missing-only 发布只创建并公开了原先缺失的 Case 19 与 21-25 六个 skill，19 个既有精确匹配项未上传、未改权限。
- `/api/chat` 已在 Ready 镜像 `ee031038` 上 fresh 验证 01、12、13、14、15：5/5 均取得 committed `completed`、严格业务 artifact 且 `workflowValidationStatus=validated`。12 和 14 的 Assistant 最终文案仍描述旧的 Running/Awaiting 状态，严格判定只采用 authoritative committed artifact，不能让模型文案覆盖机器证据。
- 案例 15 又在生产镜像 `d7844b5e` 上完成 artifact actor identity 回归：Assistant 读取到 committed typed artifact 并明确报告 `Completed`，没有再把最终结果误报为 pending。
- 五个代表案例均按 `ornn_search_skills -> use_skill -> mount approval -> aevatar_start_workflow -> committed observation` 到达可判定终态，未出现重复 tool start call ID。
- 本轮 fresh direct runtime 的固定 managed `codex_exec` 探针 committed `failed`，稳定错误为 `codex_execution_admission_denied`，4/4 已观测步骤后无 final artifact；同批其余基础、文件、`code_execute` 和确定性原语 case 全部严格通过。历史镜像 `f7f543c5` 的恢复证据继续保留，但不能覆盖当前回归。
- 本轮 14 和 17 均真实进入 `awaiting_tool_approval`，验证器从 SSE 取得完整 typed identity 后各 resume 一次，最终 committed 3/3、4/4 且 artifact 命中；旧的“当前运行未观察到 per-run pending/resume”结论已被 fresh 证据取代。
- 当前生产已补充验证 scope 特定的 sandbox bearer 转发修复：单步 `code_execute`、可访问 Base 的 P2 no-send 同类链、exact P1 v5 sanitized image + `submit=false` 均为 committed completed、`lastSuccess=true` 且 final output 非空；既有 PDF attachment probe 2/2 completed 证据继续有效。
- Durable schedule 的完整生产闭环证据来自历史镜像 `b010ba61`；相关修复提交 `748f98e7d`、`7a7781067` 和 `b010ba614` 已包含在当前 `6df43b83` 的提交历史中，但本轮未在当前镜像重跑该副作用链。历史 fresh NyxID 验证先完成六个只读 GET 的 interactive run，取得 11/11 committed `completed` 和精确预算 artifact；随后取得 HTTP 200 `confirmation_required` 与 HTTP 202 typed `pending_binding` receipt，binding committed `succeeded`（state 7）、provisioning committed `succeeded`（state 11），schedule/operation ID 均非空。每分钟 schedule 回读为 enabled，六次真实 cron 触发均完成，`fireCount=6`、`failureCount=0`；抽查 run 为 workflow 11/11 committed `completed`（state 73），六路 Base 与预算断言全部命中。NyxID DELETE 返回 typed accepted receipt 后 list 为空，跨下一分钟 workflow run count 保持 `6 -> 6`。`f7f543c5` 上的 `NyxIdOperationAuthorityContractUnavailable` 只作为历史回归背景保留；POST、WRITE 与 DESTRUCTIVE 仍 fail-closed。编译修复提交 `b010ba614` 的 Release publish、真实 `linux/amd64` Docker build、镜像内 `.NET 10.0.10 linux-x64`、完整架构/稳定性门禁和排除 3 个本机 Redis 版本契约用例后的 solution tests 均通过。
- `~/workflows` 中除 n8n 外的 41 个可解析定义已按 7 个版本族比较；剩余边界明确落在 per-run typed approval、Lark sender binding/channel canary，以及受安全约束未运行的源发送、审批和排程定义。公开案例 15 的 Durable schedule 已通过，不替代未运行的源财务 schedule 分支。
- 风险验收 21 个 case 的 fresh 严格汇总为：12 passed、2 blocked、2 failed、0 pending-execution、5 not-configured。Risk 25 由同 sender 的 fresh Lark Case 22 精确 grant、批准恢复及 committed contact artifact 关闭；Risk 26 由原 `/api/chat` 入口 fresh Case 12 的 4/4 committed 结算 artifact 关闭。其余失败和外部配置缺口继续保留，不能从其他入口外推。
- 已检查 #3161 作者此前在 `aevatarAI/aevatar` 提交的全部 11 条 issue，并用 13、15、16 做新一轮只读 committed 回归；没有为 channel/scheduler 外层缺口复制无效 workflow。详见 [定向回归报告](report/2026-08-05-issue-3161-author-regression.md) 与 [机器摘要](validation/issue-3161-author-regression-2026-08-05.json)。

`preview`、`202 Accepted`、Assistant 正常结束、模型文案和 pending artifact 都不等于 workflow 成功。逐案例证据见 [历史生产验证摘要](validation/production-validation-2026-08-05.json)、[21-25 生产证据](validation/production-validation-2026-08-06-cases-21-25.json) 与 [风险机器摘要](validation/risk-validation-2026-08-06.json)，完整对比见 [分析页面](report/index.html)。

### 本轮验证日志

| 时间（SGT） | 验证层 | 目标 | 结果 | 证据 / blocker | 下一步 |
|---|---|---|---|---|---|
| 2026-08-06 22:55 | Risk/channel/report 一致性门禁 | 当前工作树 | 通过 | `validate_risk_cases.rb`：21 项为 12 passed、2 blocked、2 failed、5 not-configured；`validate_channel_cases.rb`：1 passed、2 failed；`validate_report.rb`、JSON 解析与 `git diff --check` 全部通过 | 定位 Cases 20/21 在 AgentRun fallback 中产生 `InvalidWorkflowYaml` 的源码根因 |
| 2026-08-06 22:54 | Risk 25/26 证据重算与 README/report 回写 | Ready `ee031038`；fresh Lark Case 22 与 Assistant Case 12 | 通过证据已收敛，待一致性门禁 | Risk 25 的 sender binding、精确 Lark UserService grant、同 run approval resume 与 contact artifact 全部由 Case 22 命中；Risk 26 按原 `/api/chat` 入口 4/4 completed，`total_cents=16623`、`side_effects=false`；汇总更新为 12 passed、2 blocked、2 failed、5 not-configured | 运行 risk、channel 与 report validator；通过后定位 Cases 20/21 的 `InvalidWorkflowYaml` |
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
| 2026-08-06 18:06 | Ornn 风险证据与报告一致性 | 当前工作树 | 部分通过 | `validate_risk_cases.rb` 通过：21 项为 9 passed、2 blocked、4 failed、1 pending-execution、5 not-configured；`validate_report.rb` 因仍要求历史 Case 19 `start-blocked` 固定表述而失败 | 更新报告校验器为 catalog 已修复、fresh Lark `pending-execution` 的当前契约并重跑 |
| 2026-08-06 18:08 | 风险证据与报告定向复验 | 当前工作树 | 通过 | Risk YAML/JSON 汇总为 21 项中的 9 passed、2 blocked、4 failed、1 pending-execution、5 not-configured；`validate_risk_cases.rb`、`validate_report.rb`、脚本语法与 `git diff --check` 全部通过 | 诊断并闭环 Case 11 managed `codex_exec` admission 回归 |
| 2026-08-06 18:11 | Case 11 fresh 定向启动 | Ready 镜像 `2046dd5c` | 未启动 | 账号 managed readiness 为 enabled/eligible/active/ready 且无 cleanup pending；验证器在生产调用前因当前 shell 未设置 `AEVATAR_SCOPE_ID` 退出，没有创建 member 或 workflow run | 从本地 team 配置和已认证 Aevatar read model 恢复 scope，再重跑同一隔离定义 |
| 2026-08-06 18:13 | Case 11 fresh run 与线上日志诊断 | Ready 镜像 `2046dd5c`；scope hash `237314c29964` | 失败 | scope/team read model 匹配且 readiness 全部 ready；隔离定义请求以 HTTP 404 结束，未取得可判定 run。最近 15 分钟有界日志无可唯一关联的 404；部署源码仍注册 preview 与 provision 路由 | 单独执行 Case 11 preview，区分 preview 与 provision/binding/invoke 边界 |
| 2026-08-06 18:14 | Case 11 定向 preview | Ready 镜像 `2046dd5c`；隔离 local materialization | 通过 | fixed managed probe preview 通过，0 个外部 call site；HTTP 404 已排除 parser 与 explicit-request preview 边界 | 增加脱敏阶段诊断后重跑 run，定位 binding/provision/invoke 的具体失败点 |
| 2026-08-06 18:15 | Case 11 阶段化 run 诊断 | Ready 镜像 `2046dd5c` | 失败 | 脱敏阶段诊断确认失败位于 `invoke_workflow`，typed HTTP 503 `WORKFLOW_PROJECTION_UNAVAILABLE`；未创建可判定 run，`codex_exec` 尚未执行 | 检查 projection 可用性判定、Pod 状态与部署恢复窗口，必要时有界重试 |
| 2026-08-06 18:16 | Projection 健康与恢复窗口诊断 | Ready 镜像 `2046dd5c` | 部分通过 | Pod Ready、0 restart；最近日志持续成功写入 Elasticsearch workflow/projection read model，未见全局 projection outage；新 member 首次 invoke 仍可能早于投影可见 | 复用同一确定性 member 有界重试 Case 11；复现则进入 Aevatar 根因修复 |
| 2026-08-06 18:16 | Case 11 committed 重试 | Ready 镜像 `2046dd5c`；run hash `e75366e09494` | 失败 | 复用现有 revision 后取得 committed `failed`，state 31，4/4 已观测步骤；`codex_exec` 为 `codex_execution_admission_denied`，无 final artifact；readiness 仍为 ready | 拉取对应时间窗 codex 日志并定位 Aevatar admission 根因 |
| 2026-08-06 18:18 | Case 11 admission 源码/日志归因 | Ready 镜像 `2046dd5c` | 未收敛 | 对应时间窗仅记录 managed tool 注册，未暴露内部 failure code；`f7f543c51..2046dd5c` 的 managed coordinator/transport 无代码变化，历史认证修复未被回退；外层错误仍可能折叠 identity、Vault 或下游 401/403 | 查询 typed audit/read model 的内部 code；若诊断丢失则纳入 Aevatar 最小修复 |
| 2026-08-06 18:28 | Case 11 NyxID 身份传播源码归因 | Ready 镜像 `2046dd5c`；Aevatar/NyxID 本地源码 | 已定位 Aevatar 缺陷 | NyxID transitional 契约允许同时转发 `Authorization` 与已签名 identity assertion；主站 selector 当前在 bearer 存在时忽略 assertion，导致 bearer principal 未提供 native NyxID user claim 时 workflow authority 为空；固定 probe、readiness 与下游 transport 已排除 | 从最新 `origin/feature/integrate` 创建隔离 worktree，补双凭据认证及 workflow caller authority 回归测试后最小修复 |
| 2026-08-06 18:33 | Aevatar 身份断言优先级本地修复 | 基线 `fe752839d`；隔离 worktree | 通过 | 新增测试先稳定复现 2/2 失败：双凭据主体错误与无效 assertion 回退；最小 selector 修复后认证及 workflow caller credential 套件 7/7 通过，assertion 主体和 authority 一致，bearer 仍保留 | 运行完整受影响项目测试、稳定性/架构门禁和 diff 检查，再提交并普通推送 `origin/feature/integrate` |
| 2026-08-06 18:36 | Aevatar 修复扩大测试与门禁 | 隔离 worktree；本机 Redis `8.6.2` | 部分通过 | `architecture_guards.sh`、`test_stability_guards.sh`、`git diff --check` 通过；Capabilities 643 项中 640 通过，3 项仅因固定要求 Redis `7.2.3` 的环境前置失败，与本轮身份变更无关 | 精确排除这 3 个 pinned-Redis 环境用例重跑其余项目测试，复核 diff 后提交 |
| 2026-08-06 18:38 | Aevatar 修复环境隔离复验 | 隔离 worktree | 通过 | 精确排除 3 个 pinned-Redis 版本前置用例后，Capabilities 其余 640/640 通过；结合定向 7/7、架构与稳定性门禁，未发现本轮修复引入回归 | 重新 fetch/rebase 最新 `origin/feature/integrate`，复核并提交修复 |
| 2026-08-06 18:41 | Aevatar 修复 rebase 后复验 | 提交 `cd007b657`；基线 `25a84a44b` | 通过 | 远端前进 1 个不重叠的 Admin Studio 提交后 rebase 成功；身份断言定向套件 7/7、稳定性门禁和 `origin/feature/integrate...HEAD` 完整架构门禁再次通过 | 最后回读远端 tip，普通推送修复到 `origin/feature/integrate` 并等待 Ready 部署 |
| 2026-08-06 18:42 | Aevatar 修复推送与远端回读 | `origin/feature/integrate`；提交 `cd007b657` | 通过 | 普通推送成功，`git ls-remote` 回读的远端 tip 与本地完整提交精确一致；未使用 force push | 有界轮询 Ready workload，确认部署可追溯包含该修复后重跑 Case 11 |
| 2026-08-06 18:43 | Aevatar 修复部署首次轮询 | Ready 镜像 `fe752839` | 等待部署 | Pod Ready、0 restart，已从旧 `2046dd5c` 前滚但尚未包含 `cd007b657`；未执行 Case 11，避免在错误部署上复验 | 低频轮询 CI 与 Ready 镜像，直到可追溯包含修复提交 |
| 2026-08-06 18:47 | 验收闭环 skill 结构复验 | 当前工作树；临时隔离 Python 环境 | 通过 | `skill-creator` 官方 `quick_validate.py` 通过；Codex `agents/openai.yaml` 与 Claude Code 同源 skill 链接有效，批次 README 回写契约已生效 | 继续等待 `cd007b657` 或其后代 Ready 部署 |
| 2026-08-06 18:49 | Aevatar 修复部署第二次前滚 | Ready 镜像 `25a84a44` | 等待部署 | 新 Pod 1/1 Ready、0 restart；该提交是 `cd007b657` 的直接父提交，仍未包含身份修复；远端最新 `32c731992` 已确认是修复后代 | 继续低频轮询下一个 Ready 镜像，不在父提交上重跑 Case 11 |
| 2026-08-06 18:59 | Aevatar 身份修复 Ready 部署 | Ready 镜像 `32c73199` | 通过 | 新 Pod 1/1 Ready、0 restart；git ancestry 明确证明该部署包含 `cd007b657`，满足可追溯部署门槛 | 在该 Ready 镜像上先重跑 Case 11 preview，再运行 fixed managed probe 并读取 committed typed artifact |
| 2026-08-06 19:03 | Case 11 修复部署定向 preview | Ready 镜像 `32c73199`；scope hash `237314c29964` | 通过 | 通过 `/api/auth/me` 与 Studio team roster 在单进程内恢复并交叉校验 scope/team；fixed managed probe fresh preview 通过，0 个外部 call site；未启动 workflow、未产生外部写入 | 在同一 Ready 部署上真实运行 Case 11，并以 committed terminal state 与严格 typed artifact 判定 |
| 2026-08-06 19:04 | Case 11 修复部署首次 runtime | Ready 镜像 `32c73199` | 未启动 | preview 与 endpoint readiness 后，invoke 返回 typed HTTP 503 `WORKFLOW_PROJECTION_UNAVAILABLE`；未取得 run ID，`codex_exec` 尚未执行，不能据此判定身份修复失败 | 复用同一确定性 member 有界重试；若仍失败则重新检查 projection/read model 健康与部署日志 |
| 2026-08-06 19:05 | Case 11 修复部署 committed 重试 | Ready 镜像 `32c73199`；run hash `181874564935` | 失败 | 复用现有 revision 后取得 committed `failed`，state 31，4/4 已观测步骤；`codex_exec` 仍为 `codex_execution_admission_denied`，无 final artifact；已排除首次 invoke 的 projection 窗口 | 拉取该 run 时间窗的脱敏生产日志，确认身份断言修复后的剩余 admission 拒绝边界并继续修复 Aevatar |
| 2026-08-06 19:10 | Case 11 committed run 生产日志诊断 | Ready 镜像 `32c73199`；run hash `181874564935` | 未收敛 | 相关窗口未出现 `codex`、managed admission 或可关联的内部稳定错误码；同窗 workflow/projection read model 写入持续成功，排除全局 projection outage，但外层 `codex_execution_admission_denied` 仍折叠内部原因 | 查询 committed run detail/audit；若仍丢失内部 code，则在 Aevatar 增加无敏感信息的稳定诊断传播与回归测试 |
| 2026-08-06 19:11 | Case 11 managed readiness 与请求身份边界 | Ready 镜像 `32c73199`；scope hash `237314c29964` | 通过边界检查 | readiness 为 enabled/eligible/active、`execution_ready=true`、reason=`ready`、state 3、cleanup 0；`/api/auth/me` 为 NyxID 且 session/top-level scope 一致；interactive invoke 会从当前 HTTP 请求重新提取 caller credential，排除复用 revision 中陈旧凭据的假设 | 读取同一 committed run 的 detail/audit，只输出稳定 code、布尔值和哈希，以区分 identity 与 Vault credential resolution 边界 |
| 2026-08-06 19:13 | Case 11 committed detail/audit 交叉查询 | Ready 镜像 `32c73199`；run hash `181874564935` | 已定位诊断缺口 | observatory detail、member-scoped summary 与 audit 均确认 committed `failed`、state 31、4 个实际步骤，失败点为 `execute_probe`；三个面都只保留 `codex_execution_admission_denied`，未保留任何 `managed_*` 内部 code，无法从 committed 证据区分 identity、descriptor 与 Vault resolution | 在 Aevatar 执行/审计传播链补安全稳定的内部 failure code 与回归测试；部署后先用 fresh run 精确归因，再修实际 managed 执行缺陷 |
| 2026-08-06 19:17 | Case 11 fresh runtime 复现 | Ready 镜像 `09612d0b`；run hash `6f408aa3d421` | 失败 | 当前部署是身份修复后代；fresh preview 通过且 0 外部 call site，复用 revision 后 committed `failed`、state 31、4/4，仍为 `codex_execution_admission_denied` 且无 final artifact | 立即读取本次运行窗口的内部日志；若稳定 detail 仍不可见，则修复内部可观测性但不泄露 provider-owned detail 到公开审计分类 |
| 2026-08-06 19:18 | Case 11 fresh run 日志关联 | Ready 镜像 `09612d0b`；run hash `6f408aa3d421` | 阻塞于内部可观测性 | Ready Pod 单容器、0 restart，stdout 日志持续可读；fresh run 后 5 分钟窗口仍没有 coordinator/transport 的 `Managed Codex` Warning 或任何 `managed_*` code，无法使用现有生产日志区分根因 | 在 Aevatar 内部日志链增加无凭据、可关联且有测试保护的稳定 failure code；保持公开 receipt/audit 的封闭分类不变 |
| 2026-08-06 19:20 | Aevatar managed failure 内部诊断首轮静态批次 | 基线 `bb80c4dea`；隔离 worktree | 未进入测试 | 最小实现仅记录受限 stable code、failure kind 与 12 位 run hash；`git diff --check` 通过；定向 `--no-restore` 因隔离 worktree 缺少 `project.assets.json` 在构建前退出，独立 SHA-256 对照另发现测试预期 hash 需修正 | 修正测试预期，并允许 restore 后重跑 Codex failure audit 定向套件 |
| 2026-08-06 19:20 | Aevatar managed failure 内部诊断定向测试 | 基线 `bb80c4dea`；隔离 worktree | 通过 | restore/build 后 Codex failure audit 13/13 通过；内部 Warning 仅包含 failure kind、受限 stable provider code 与 12 位 run hash，原始 run ID 不出现；公开 receipt/audit 继续只保留封闭 `codex_execution_*` 分类且不含 provider detail | 无构建复验并运行完整 Aevatar.AI.Tests、稳定性/架构门禁与 diff 检查 |
| 2026-08-06 19:21 | Aevatar managed failure 扩大测试首轮 | 基线 `bb80c4dea`；隔离 worktree | 无有效测试结论 | 完整项目 build 与定向 `--no-build` 被错误并行到同一输出目录，最终因 `Aevatar.AI.Tests.runtimeconfig.json` 文件锁退出；两个门禁命令引用了不存在的 `scripts/` 根路径。均属验证命令编排错误，不是用例失败 | 查明实际门禁脚本路径，停止共享输出并发，串行重跑完整项目测试与门禁 |
| 2026-08-06 19:23 | Aevatar managed failure 完整相关项目测试 | 基线 `bb80c4dea`；隔离 worktree | 通过 | 停止共享输出并发后，`Aevatar.AI.Tests` 串行 2459/2459 通过、0 skipped；覆盖 DI 构造、工具执行、审计及相关 AI 路径 | 运行 `tools/ci` 下稳定性与架构门禁，复核 diff 后提交 |
| 2026-08-06 19:24 | Aevatar managed failure 提交前门禁 | 基线 `bb80c4dea`；隔离 worktree | 通过 | Codex failure audit 无构建复验 13/13；stability、architecture、proto lint、audit trail、NyxID chat semantics 等门禁和 `git diff --check` 全部通过 | 增加 unsafe provider code 日志降级负例，复验后 fetch/rebase 最新远端并提交 |
| 2026-08-06 19:25 | Aevatar managed failure 日志注入负例 | 基线 `bb80c4dea`；隔离 worktree | 通过 | 新增包含换行的 provider code 负例并通过；只有有界小写字母、数字、下划线 code 可进入内部日志，其余统一为 `unclassified`；架构门禁与 diff 检查继续通过 | fetch 最新 `origin/feature/integrate`；如远端前进则 rebase 并复验，否则提交当前最小修复 |
| 2026-08-06 19:25 | Aevatar 远端前进检查 | 本地基线 `bb80c4dea`；远端 `92bf13670` | 需要 rebase | `origin/feature/integrate` 已前进，包含 workflow catalogue 与失败终态相关变更；本轮改动仍仅限 executor 与对应测试，diff 无冲突迹象 | 暂存本轮两文件修改，将隔离分支 rebase 到 `92bf13670` 后恢复并重跑定向/完整相关测试与门禁 |
| 2026-08-06 19:26 | Aevatar managed failure rebase | 最新远端 `92bf13670`；隔离 worktree | 通过 | 本轮两文件修改经命名 stash 暂存后 fast-forward/rebase 到最新远端，恢复无冲突，stash 已删除，`git diff --check` 通过；主 Aevatar 脏工作树未改动 | 在新基线上串行重跑完整 `Aevatar.AI.Tests`，再运行稳定性与架构门禁 |
| 2026-08-06 19:33 | Aevatar managed failure rebase 后完整测试 | 最新远端 `92bf13670`；隔离 worktree | 通过 | `Aevatar.AI.Tests` 2460/2460 通过、0 skipped；新增 unsafe provider code 负例已计入，内部诊断与公开审计边界在最新 workflow 变更后仍成立 | 运行最终 stability/architecture 门禁，复核两文件 diff 后提交 |
| 2026-08-06 19:34 | Aevatar managed failure 最终提交前门禁 | 最新远端 `92bf13670`；隔离 worktree | 通过 | stability、architecture、proto lint、audit trail、channel/NyxID 语义门禁与 `git diff --check` 全部通过；diff 仅 executor 和对应 audit test 两文件，不含生产身份或凭据 | 提交内部诊断修复；再次 fetch/rebase 后普通推送到 `origin/feature/integrate` |
| 2026-08-06 19:34 | Aevatar managed failure 诊断修复提交 | 提交 `f0337b80d`；父提交 `92bf13670` | 通过 | 仅提交 executor 内部 Warning 与对应安全/审计回归测试，共两文件；隔离 worktree 提交后干净，验收仓库未提交 | fetch 远端并核对 tip；无前进则普通推送，有前进则 rebase、复验后推送 |
| 2026-08-06 19:35 | Aevatar 推送前远端一致性 | 本地 `f0337b80d`；远端 `92bf13670` | 通过 | 再次 fetch 后远端未前进，本地提交父节点精确等于当前 `origin/feature/integrate`，无需 rebase | 普通推送 `HEAD:feature/integrate`，随后回读远端完整 SHA |
| 2026-08-06 19:35 | Aevatar managed failure 诊断修复推送 | `origin/feature/integrate`；提交 `f0337b80d` | 通过 | 普通推送成功，`git ls-remote` 回读远端 tip 与本地完整 SHA 精确一致；未使用 force push | 有界轮询 Ready workload，只有部署包含该提交或明确后代时才 fresh 复跑 Case 11 并读取安全内部 code |
| 2026-08-06 19:35 | Aevatar 诊断修复部署首次轮询 | Ready 镜像 `5240e518` | 等待部署 | workload 为 1/1 Ready、updated/available 均为 1、0 已知 rollout 故障；该镜像来自推送前远端历史，不含 `f0337b80d` | 继续低频轮询；等待期间执行验收仓库本地静态批次，不在旧镜像复跑 Case 11 |
| 2026-08-06 19:36 | 验收仓库静态与报告一致性复验 | 当前工作树 | 通过 validator | 25/25 workflow、25/25 skill、3/3 channel 定义、21/21 risk 定义均纳入校验；生产/Assistant/admission 脚本语法、报告契约和 `git diff --check` 通过。运行状态仍诚实保留 channel 0/3 严格通过、risk 9 passed/2 blocked/4 failed/1 pending/5 not-configured | 用 `config.example.yaml` 物化并解析全部生成 YAML；随后继续轮询诊断修复部署 |
| 2026-08-06 19:36 | 公开模板 materialize 与 YAML 解析 | `config.example.yaml`；当前工作树 | 通过 | materializer 干净生成动态 inventory 的 25 个 workflow，全部 `YAML.safe_load` 成功，未发现 stale output 或文件集合漂移；`build/` 保持忽略 | 重新用不提交的 `config.local.yaml` 物化生产定义，再检查 `f0337b80d` Ready 部署 |
| 2026-08-06 19:37 | 生产配置 materialize | `config.local.yaml`；当前工作树 | 通过 | 16 个本地 replacement 已重新物化到 25 个 ignored build workflow；命令输出未包含真实值，配置与 build 均未纳入提交 | 检查 Ready image；包含 `f0337b80d` 后 fresh 运行 Case 11 并关联内部 Warning |
| 2026-08-06 19:37 | Aevatar 诊断修复部署第二次轮询 | Ready 镜像 `5240e518` | 等待部署 | generation 与 observedGeneration 均为 2691，workload 1/1 Ready 且 updated/available 为 1；镜像无变化，尚未包含 `f0337b80d`，未在旧镜像重复运行 Case 11 | 查询 `feature/integrate` 对应 CI/build 状态；继续有界低频轮询 |
| 2026-08-06 19:38 | Aevatar 诊断修复 CI 列表检查 | `feature/integrate`；提交 `f0337b80d` | 尚无对应 run | 最近可见 GitHub `ci` 仍是 `09612d0ba` completed/success，列表尚未出现诊断提交；生产已独立前滚到 `5240e518`，不能假设该 Actions 列表与部署一一同步 | 查询 `f0337b80d` 精确 check-runs/commit status，并继续观察 Ready image |
| 2026-08-06 19:38 | Aevatar 诊断提交精确 checks/status | 提交 `f0337b80d` | 符合分支契约 | GitHub 返回 0 check-runs、0 commit statuses；`.github/workflows/ci.yml` 的 push 触发只包含 `main`/`dev`，不包含 `feature/integrate`，所以无 Actions run 是预期而非失败 | 继续以外部构建链产生的 Ready image 与 git ancestry 作为部署证据 |
| 2026-08-06 19:39 | Aevatar 诊断修复部署第三次轮询 | Ready 镜像 `5240e518` | 等待部署，无状态变化 | 30 秒后 deployment 仍为 generation 2691、1/1 Ready、updated/available 为 1；没有 failed rollout 信号，目标提交仍未部署 | 只读检查 registry 的 `f0337b80` 镜像 tag，区分构建等待与部署等待 |
| 2026-08-06 19:39 | Aevatar 诊断镜像 registry 检查 | 镜像 tag `f0337b80` | 等待构建 | Docker registry 返回 `no such manifest`，说明目标提交镜像尚未发布；当前不是 rollout 卡死，也不能在旧 Ready 镜像复验诊断日志 | fetch 远端检查是否已有包含修复的后代提交；继续低频检查后代 tag/Ready image |
| 2026-08-06 19:40 | Aevatar 诊断提交远端后代检查 | `origin/feature/integrate` | 无后代、等待构建 | fetch 后远端 tip 仍精确为 `f0337b80d`，ancestry 检查通过但没有更新提交可替代目标 tag；registry 仍需构建当前 tip | 低频等待镜像；同时盘点 risk/channel 未通过项的精确入口，为 Case 11 恢复后的全量闭环排序 |
| 2026-08-06 19:44 | Aevatar 诊断镜像发布与 rollout 启动 | 镜像 `f0337b80`；digest `sha256:c15b43abc85255d9b7312e271126f5c97e4c35328bad30cb60d21d8bb75019f8` | 等待 Ready | registry manifest 已发布；新 ReplicaSet `aevatar-console-backend-57c874fbdd` 已创建并请求 1 个副本，但本批结束时尚无 Ready 副本，旧 `5240e518` workload 仍承担 Ready 流量 | 低频轮询 deployment 与新 Pod；只有 `f0337b80` 达到 1/1 Ready 后才重跑 Case 11 |
| 2026-08-06 19:49 | Aevatar 诊断修复 Ready 部署 | Ready 镜像 `f0337b80`；digest `sha256:c15b43abc85255d9b7312e271126f5c97e4c35328bad30cb60d21d8bb75019f8` | 通过 | deployment generation/observedGeneration 均为 2693，目标提交对应镜像为唯一副本且 1/1 Ready、updated/available 均为 1、0 restart；运行 digest 与 registry manifest 精确一致 | 在该 Ready 部署 fresh 运行 Case 11，随后按 run hash 读取内部受限 failure kind/code |
| 2026-08-06 19:51 | Case 11 运行前身份预检 | Ready 镜像 `f0337b80`；scope hash `237314c29964` | 通过 | `/api/auth/me` 已认证，顶层 scope、session scope 与 profile subject 哈希一致；只检查脱敏字段结构和布尔状态，未输出真实 scope 或凭据 | 从忽略的本地配置读取 team/service，单进程执行 Case 11 preview 与 fresh runtime |
| 2026-08-06 19:51 | Case 11 诊断部署 fresh runtime | Ready 镜像 `f0337b80`；run hash `557edd506461` | 失败 | fresh preview 通过且 0 个外部 call site；复用 revision 后 committed `failed`、state 31、4/4，`execute_probe` 仍为 `codex_execution_admission_denied`，无 final artifact | 立即按同一 run hash 查询诊断部署的受限内部 Warning，提取 stable failure kind/code |
| 2026-08-06 19:52 | Case 11 诊断部署日志关联 | Ready 镜像 `f0337b80`；run hash `557edd506461` | 未取得内部 code | fresh run 后 5 分钟精确匹配及 10 分钟 `codex`/`managed`/`admitted` 扩大搜索均为空；新 Warning 未出现在当前 Pod stdout | 核对 executor 调用边界与生产日志级别，判断失败是否在进入 `AdmittedAgentToolExecutor` 前已被折叠 |
| 2026-08-06 19:54 | Case 11 managed failure 源码边界复核 | 部署源码 `f0337b80` | 缩小范围，未最终归因 | `CodexExecutionException` 会经过 executor catch；生产没有日志级别覆盖。managed coordinator 的 transport/readiness 失败已有 Warning，只有 request validation/identity 的 `ManagedCodexRequestException` 直接返回且不记录；这使 `managed_identity_unavailable` 成为待证假设，但尚不能写成确认根因 | 在 required logger 的 coordinator failure 生成边界补受限 code 日志，或在后代 Ready 部署上取得等价 typed 证据后再修实际缺陷 |
| 2026-08-06 19:55 | Aevatar 后代镜像 rollout | 镜像 `3f62ff62`；远端 tip `3981c1e1d` | 等待 Ready | `3f62ff62` 是 `f0337b80` 的直接后代，明确包含诊断修复；deployment generation 2695 已启动新 Pod，但本批结束时新副本未 Ready，旧 `f0337b80` 仍 1/1 Ready | 等待后代镜像 Ready；不跨两个 deployment 重跑或混合日志证据 |
| 2026-08-06 19:56 | Aevatar 诊断后代 Ready 部署 | Ready 镜像 `3f62ff62`；digest `sha256:578d292d1c71f56a50e550dcaf3b8f6485ecfa9ac316f2774e5a901195aa2b8e` | 通过 | deployment generation/observedGeneration 均为 2695，目标后代镜像已成为唯一副本且 1/1 Ready、updated/available 均为 1、0 restart；git ancestry 包含 `f0337b80` | fresh 重跑 Case 11，并立即按单 Pod、run hash 查询受限日志 |
| 2026-08-06 19:57 | Case 11 后代部署首次 invoke | Ready 镜像 `3f62ff62` | 未启动 | preview/既有 binding 后 invoke 返回 typed HTTP 503 `WORKFLOW_PROJECTION_UNAVAILABLE`；未取得 run ID，`codex_exec` 尚未执行，不能据此判断诊断或功能状态 | 复用同一确定性 member 有界重试，取得 committed run 后再关联单 Pod 日志 |
| 2026-08-06 19:57 | Case 11 projection 有界重试 | Ready 镜像 `3f62ff62` | 持续未启动 | 第二次复用同一确定性 member 仍在 invoke 返回 typed HTTP 503 `WORKFLOW_PROJECTION_UNAVAILABLE`；连续两次均未创建 run，重复执行不再提供新证据 | 检查新 Pod projection 初始化、Elasticsearch 写入与 workload readiness；区分暂时恢复窗口和 Ready 判定缺陷 |
| 2026-08-06 19:58 | Projection/Ready 生产诊断 | Ready 镜像 `3f62ff62` | 全局链路健康，member 可见性待重试 | 新 Pod 持续成功提交 projection scope 事件并写入 Elasticsearch 的 workflow binding、execution board 与 status read model；Pod/Deployment Ready、0 restart。启动期仅一次端口未监听的 readiness 过渡，无持续错误 | 在 projection 持续写入后对同一 member 做最后一次有界 invoke；成功创建 run 后立即关联日志，仍 503 则升级为独立 Aevatar activation 缺陷 |
| 2026-08-06 19:59 | Case 11 projection 恢复后 runtime | Ready 镜像 `3f62ff62`；run hash `ee61879a2f4a` | 失败 | invoke 已恢复并取得 committed `failed`，state 31，4/4；fixed probe 仍为外层 `codex_execution_admission_denied`，无 final artifact | 固定单 Pod 查询同一时间窗，读取诊断提交新增的受限 failure kind/code |
| 2026-08-06 20:00 | Case 11 内部 failure code 关联 | Ready 镜像 `3f62ff62`；run hash `ee61879a2f4a` | 已定位根因边界 | coordinator 与 executor 两层日志精确一致：`failureKind=AdmissionDenied`、`failureCode=managed_proxy_authorization_denied`；工具上下文有 caller bearer/NyxID access token，排除 identity、readiness 与 Vault credential unavailable | 核对 Aevatar managed transport 的 Agent Key header、service binding 与 NyxID 已发布代理认证契约，修复 Aevatar 下游授权调用 |
| 2026-08-06 20:04 | Managed Agent Key / NyxID 契约对照 | Aevatar `3f62ff62`；本地 NyxID 源码 `bf484f395` | 已定位分类缺口 | 唯一 managed key active、未过期、`proxy`/`codex`，严格只允许当前 sandbox+LLM 两个 UserService，service/node scope 均精确；Aevatar 已使用 `X-API-Key` 与 exact `_nyxid_via`。但 bounded transport 将 HTTP 401 与 403 折叠为同一 code，无法区分 Vault 中陈旧 secret 与真实授权拒绝 | 在 Aevatar 内将 401/403 映射为不同的稳定内部 failure code并补测试；部署后 fresh run 精确归因 |
| 2026-08-06 20:06 | Aevatar managed proxy auth 分类定向测试 | 基线 `3981c1e1d`；隔离 worktree | 通过 | transport 定向套件 18/18 通过；真实 HTTP 401 映射为 `managed_proxy_authentication_failed`，403 保持 `managed_proxy_authorization_denied`，两条路径均断言不泄露响应体中的 Agent Key；`git diff --check` 通过且仅两文件改动 | 运行完整 ChronoSandbox 测试项目、稳定性/架构门禁和最终 diff 检查 |
| 2026-08-06 20:06 | Aevatar managed proxy auth 分类扩大测试 | 基线 `3981c1e1d`；隔离 worktree | 通过 | 完整 `Aevatar.AI.Infrastructure.ChronoSandbox.Tests` 211/211 通过、0 skipped；credential lifecycle、readiness、transport 与 coordinator 相关路径未见回归 | 运行仓库 stability/architecture 及相关语义门禁，复核 diff 后提交 |
| 2026-08-06 20:10 | Aevatar managed proxy auth 分类提交前门禁 | 基线 `3981c1e1d`；隔离 worktree | 通过 | stability、architecture、proto、workflow saga/binding、audit、channel、NyxID 与 docs lint 全部通过；Architecture tests 15/15，`git diff --check` 通过，diff 仍仅 transport 与对应测试两文件 | fetch 最新 `origin/feature/integrate`；如远端前进则 rebase/复验，否则提交并普通推送 |
| 2026-08-06 20:11 | Aevatar managed proxy auth 分类远端一致性 | 本地/远端基线 `3981c1e1d` | 通过 | fetch 后 `origin/feature/integrate` 未前进，本地分支父节点与远端完整 SHA 精确一致；无需 rebase，工作区仅两处预期修改 | 只提交 transport 401/403 分类与对应回归测试，然后再次 fetch 并普通推送 |
| 2026-08-06 20:11 | Aevatar managed proxy auth 分类提交 | 提交 `48261819b`；父提交 `3981c1e1d` | 通过 | 两文件提交完成：401/403 稳定分类与真实 HTTP boundary 回归测试；隔离 worktree 提交后干净，验收仓库未提交 | 再次 fetch 远端；无前进则普通推送 `HEAD:feature/integrate` 并回读完整 SHA |
| 2026-08-06 20:12 | Aevatar managed proxy auth 分类推送 | `origin/feature/integrate`；提交 `48261819b` | 通过 | 普通推送成功，`git ls-remote` 回读远端 tip 与本地完整 SHA 精确一致；未使用 force push | 等待 registry manifest 与可追溯 Ready workload，随后 fresh Case 11 区分 401 stale secret 与 403 authorization |
| 2026-08-06 20:12 | Aevatar auth 分类部署首次轮询 | Ready 镜像 `3981c1e1` | 等待构建 | 生产已前滚到目标提交的直接父节点并 1/1 Ready；registry 尚无 `48261819` manifest，远端 tip 仍精确为目标提交 | 低频等待目标镜像构建；不在父节点上重复 Case 11 |
| 2026-08-06 20:14 | Aevatar auth 分类镜像有界等待 | 镜像 tag `48261819` | 等待构建，无状态变化 | 两次间隔 20 秒的 registry 检查均无 manifest；未观察到 rollout 失败，因为 deployment 尚未引用目标 tag | 继续低频检查 registry 与 Ready workload，manifest 发布后再进入 rollout 验证 |
| 2026-08-06 20:14 | Aevatar auth 分类部署复查 | Ready 镜像 `3981c1e1` | 等待构建，无状态变化 | 目标 registry tag 仍不存在；deployment generation 2697 稳定、父提交镜像 1/1 Ready，尚未开始目标 rollout | 延长轮询间隔，等待 `48261819` manifest |
| 2026-08-06 20:15 | Aevatar auth 分类镜像延长等待 | 镜像 tag `48261819` | 等待构建，无状态变化 | 40 秒后 registry 仍无目标 manifest；未触发 production runtime 重试 | 检查远端是否已有包含修复的后代提交，并继续等待目标或后代镜像 |
| 2026-08-06 20:16 | Aevatar auth 分类远端后代检查 | `origin/feature/integrate` | 无后代、等待构建 | fetch 后远端 tip 仍精确为 `48261819b`，目标 ancestry 正常但没有后代镜像可替代 | 继续低频等待当前 tip 的 registry manifest |
| 2026-08-06 20:17 | Aevatar auth 分类镜像第二次延长等待 | 镜像 tag `48261819` | 等待构建，无状态变化 | 再过 40 秒 registry 仍无 manifest；未观察到 deployment 更新或可判定构建失败 | 继续低频等待并复查 deployment/registry |
| 2026-08-06 20:19 | Aevatar auth 分类镜像第三次延长等待 | 镜像 tag `48261819` | 等待构建，无状态变化 | 再过 50 秒 registry 仍无 manifest；推送后约 7 分钟，仍接近既有外部构建窗口 | 继续等待目标 manifest，父镜像保持 Ready |
| 2026-08-06 20:20 | Aevatar auth 分类镜像第四次延长等待 | 镜像 tag `48261819` | 等待构建，无状态变化 | 再过 50 秒 registry 仍无 manifest；推送后约 8 分钟，deployment 尚未引用目标 tag | 继续低频等待，接近既有约 9 分钟构建时长 |
| 2026-08-06 20:21 | Aevatar auth 分类镜像第五次延长等待 | 镜像 tag `48261819` | 等待构建，无状态变化 | 再过 45 秒 registry 仍无 manifest；推送后约 9 分钟，尚无可判定失败信号 | 下一轮同时检查目标/后代 registry 与 deployment image |
| 2026-08-06 20:23 | Aevatar auth 分类镜像发布与 rollout 启动 | 镜像 `48261819`；digest config `sha256:89166692c836ba4cafabd976af3368fcacbd85843efca48f720c00c3fc68a8be` | 等待 Ready | registry manifest 已发布；deployment generation/observedGeneration 为 2699/2699，目标镜像已开始 rollout；本批结束时 2 个副本中仅 1 个 updated、1 个 Ready/available，尚未证明目标镜像为唯一 1/1 Ready | 低频轮询 deployment 与目标 Pod；只有 `48261819` 成为唯一 1/1 Ready、0 restart 后才 fresh 运行 Case 11 |
| 2026-08-06 20:24 | Aevatar auth 分类 Ready 部署 | Ready 镜像 `48261819`；运行 digest `sha256:6365e07ddb8291b2c5a27df7158ca2e25d4b7061390ff4ccc66a13b92a808384` | 通过 | deployment generation/observedGeneration 均为 2699，目标提交对应镜像为唯一副本且 1/1 Ready、updated/available 均为 1、0 restart；rollout status 成功 | 在该 Ready 部署单进程 fresh 运行 Case 11，并立即按 run hash 查询同一 Pod 的受限 stable failure code |
| 2026-08-06 20:25 | Case 11 auth 分类部署 fresh runtime | Ready 镜像 `48261819`；run hash `28dff88dcde0` | 失败 | 身份预检三处 scope hash 一致；fresh preview 通过且 0 个外部 call site；复用 revision 后 committed `failed`、state 31、4/4，`execute_probe` 仍为外层 `codex_execution_admission_denied`，无 final artifact | 固定唯一目标 Pod 查询同一 run hash 的受限内部日志，用新分类区分 401 stale Agent Key secret 与 403 authorization |
| 2026-08-06 20:26 | Case 11 auth 分类日志关联 | Ready 镜像 `48261819`；run hash `28dff88dcde0` | 已定位 authentication 边界 | 唯一目标 Pod 的 transport 与 admitted executor 两层受限日志一致返回 `managed_proxy_authentication_failed`；新 401/403 分类证明下游是 HTTP 401，排除真实授权范围 403 | 对照 NyxID Agent Key rotation 与 Aevatar Vault secret 生命周期，确认 active 元数据和 raw secret 是否漂移并修复根因 |
| 2026-08-06 20:29 | Managed credential 轮换前一致性核对 | Aevatar status / NyxID key metadata | 已确认 raw secret 漂移 | Aevatar read model 仍为 `active`、`execution_ready=true`、state 3、cleanup 0；NyxID 仅有 1 个同名 active key，未过期，`proxy`/`codex`、两个精确 service grant、无 allow-all。结构元数据全部正确但真实 transport 401，只能由当前 Vault raw secret 无效解释 | 使用当前已认证用户调用正式 `/api/managed-codex/credential/rotate`，有界等待新 authoritative state 后复验 Case 11 |
| 2026-08-06 20:30 | Managed credential 首次 rotate 请求 | 当前已认证 NyxID 用户 | 结果不明，已停止重试 | NyxID CLI 未返回可接受的成功状态；命令未输出或保存原始错误和任何 credential 标识。由于 lifecycle 写可能已被受理，不能把 CLI 非零等同于“未执行”，也不能盲目重复轮换 | 只读回查 authoritative state version、active managed key 数量及脱敏 stable error，确认是否已有状态变化后再决定恢复动作 |
| 2026-08-06 20:31 | Managed credential rotate 后只读回查 | Aevatar state / NyxID key metadata / 目标 Pod | 明确未写入 | state 仍为 3、cleanup 0；同名 key 仍为原 active hash `3cffd111e4a0`，inactive 数为 0；服务端 rotate endpoint 在约 162 ms 内返回 HTTP 502。没有新 key、旧 key 撤销或 Actor commit，排除“已受理但 CLI 非零” | 再做一次有界复现并只提取响应 stable code/脱敏 message，定位 lifecycle 前置失败，不盲目多次轮换 |
| 2026-08-06 20:33 | Managed credential rotate 有界复现 | 当前已认证 NyxID 用户 | 失败，无写入 | 请求仍为 HTTP 502，CLI 响应没有可提取 stable code；立即回查 state 仍为 3、cleanup 0、active key hash 仍为 `3cffd111e4a0` 且 inactive 数 0，确定第二次也未进入外部 mutation | 从 Host endpoint 测试、lifecycle exception mapping 与脱敏服务端日志定位无 code 502；修复或选择正确显式恢复入口后再轮换 |
| 2026-08-06 20:36 | Managed credential rotate 前置契约归因 | Aevatar Actor descriptor / NyxID active key | 排除 expiry 漂移 | 两侧 expiry 均存在且 Unix 毫秒精确相等，delta 为 0；结合 key ID、policy、service/node scope 已精确匹配，`ValidatePersistedKey` 前置不会解释当前 502 | 核对经 NyxID proxy 进入 Aevatar 后的原始 access-token 提取；定位 lifecycle 写接口是否误用仅供 Aevatar 调用的入站 bearer |
| 2026-08-06 20:41 | Managed credential lifecycle 认证边界归因 | Aevatar/NyxID 源码与 live UserService 配置 | 已定位 Aevatar 分类缺陷 | live `aevatar` 为 `auth_method=none`、`forward_access_token=true`、identity JWT + delegation token，CLI 无环境 token/profile override，排除 service credential 覆盖；credential adapter 将 NyxID 401/403 error envelope 一律折叠为 `managed_api_key_issue_invalid`，Host 默认映射 502，导致运维入口丢失真实认证/授权边界 | 从最新 `origin/feature/integrate` 新建隔离 worktree，为 credential adapter 与 Host endpoint 补 401/403 稳定分类和测试，普通推送后等待部署复验 rotate |
| 2026-08-06 20:40 | Managed credential lifecycle 认证边界红态测试 | 基线 `5cddd8e15`；隔离 worktree | 预期失败，根因已复现 | adapter 参数化用例 2/2 失败：NyxID HTTP 401/403 均被折叠为 `managed_api_key_issue_invalid`；Host 参数化用例 2/2 失败：`managed_user_authentication_failed` 与 `managed_user_authorization_denied` 均被默认映射为 HTTP 502。四条红态与生产 rotate 502 边界一致，未调用生产、未产生写入 | 最小修复 adapter 的 401/403 stable code 与 Host 的 401/403 HTTP 映射，再重跑两个定向套件 |
| 2026-08-06 20:43 | Managed credential lifecycle 认证边界定向复验 | 基线 `5cddd8e15`；隔离 worktree | 通过 | adapter 2/2 与 Host 2/2 参数化用例全部转绿；NyxID error envelope 的 body 不进入异常，401/403 分别保留为 `managed_user_authentication_failed` / `managed_user_authorization_denied`，Host 分别返回 HTTP 401/403；Host 无构建复验再次 2/2 通过 | 串行运行完整 ChronoSandbox 与 Capabilities 受影响项目，再执行 stability、architecture、语义和 docs 门禁 |
| 2026-08-06 20:47 | Managed credential lifecycle 扩大项目测试 | 基线 `5cddd8e15`；本机 Redis `8.6.2` | 通过受影响代码；3 项环境前置不满足 | 完整 ChronoSandbox 213/213 通过；Capabilities 全量 647 项中 644 通过，3 项仅因测试固定要求 Redis `7.2.3` 而本机为 `8.6.2` 失败。精确排除这 3 个 pinned-Redis 用例后，其余 644/644 通过，未排除任何 credential、Host 或 runtime 用例 | 运行 stability、architecture、proto/语义、docs lint 与 `git diff --check`，复核最终改动范围 |
| 2026-08-06 20:49 | Managed credential lifecycle 提交前门禁 | 基线 `5cddd8e15`；隔离 worktree | 通过 | stability guard 及其 guard 负例自测、architecture 全扫描、Architecture Tests 15/15、proto、audit、workflow/channel/NyxID 语义、87 份 docs lint 与 `git diff --check` 全部通过；diff 仅 adapter、Host endpoint、两组回归测试和运维文档 5 文件 | fetch 最新 `origin/feature/integrate`；远端前进则 rebase 后重跑定向测试与门禁，否则提交最小修复 |
| 2026-08-06 20:49 | Managed credential lifecycle 推送前远端一致性 | 本地/远端基线 `5cddd8e15` | 通过 | fetch 后本地 HEAD 与 `origin/feature/integrate` 完整 SHA 精确一致，远端未前进，无需 rebase；隔离 worktree 仍仅 5 个预期文件修改 | 提交认证/授权边界修复；再次 fetch，确认远端基线未变化后普通推送 |
| 2026-08-06 20:49 | Managed credential lifecycle 修复提交 | 提交 `b12b748f6`；父提交 `5cddd8e15` | 通过 | 仅提交 adapter 的 NyxID 401/403 stable code、Host HTTP 401/403 映射、两组参数化回归测试和运维说明，共 5 文件；提交后隔离 worktree 干净 | 再次 fetch `origin/feature/integrate`；无远端前进则普通推送 `HEAD:feature/integrate` 并回读完整 SHA |
| 2026-08-06 20:49 | Managed credential lifecycle 最终推送门槛 | 本地 `b12b748f6`；远端 `5cddd8e15` | 通过 | 第二次 fetch 后本地提交父节点与 `origin/feature/integrate` 完整 SHA 精确一致；隔离 worktree 干净、仅 ahead 1，无需 rebase | 普通推送 `HEAD:feature/integrate`，随后用 `git ls-remote` 回读远端完整 SHA |
| 2026-08-06 20:52 | Managed credential lifecycle 修复推送 | `origin/feature/integrate`；提交 `b12b748f6` | 通过 | 普通推送成功；`git ls-remote` 回读远端 tip 为 `b12b748f6db1f165baeba1af5cb60eecdf3ab736`，与本地提交精确一致，未使用 force push | 低频轮询 registry 与 Ready workload；只有目标提交或明确后代成为唯一 1/1 Ready 后才复验 rotate |
| 2026-08-06 20:53 | Managed credential lifecycle 部署首次轮询 | Ready 镜像 `5cddd8e1`；目标 `b12b748f` | 等待构建 | deployment generation/observedGeneration 为 2701/2701，父提交镜像是唯一副本且 1/1 Ready、updated/available 均为 1、0 restart；生产尚未引用目标提交 | 低频等待目标或明确后代镜像；期间只做本地 inventory/validator 复核，不在父镜像复验 rotate |
| 2026-08-06 20:55 | 动态 inventory 与 validator registry 复核 | 当前验收工作树 | 通过 | 动态发现 25 个 workflow、25 个唯一且一一对应的 Ornn skill、3 个 channel case、21 个 risk case、1 个 schedule、6 个 fixture、16 个 replacement 及完整 validation/report 文件；已完整读取 production、Assistant、admission、channel、risk、workflow、skill 和 report validator，未发现 orphan 定义或执行入口遗漏 | 继续轮询 `b12b748f` 或明确后代的 registry/Ready 状态；部署前不执行生产 rotate |
| 2026-08-06 20:55 | Managed credential lifecycle 部署第二次轮询 | target tag `b12b748f`；Ready `5cddd8e1` | 等待构建，无状态变化 | registry 尚无目标 manifest；deployment 仍为 generation 2701/2701、父提交镜像唯一 1/1 Ready、updated/available 均为 1，没有 rollout 失败信号 | 利用构建窗口执行验收仓库完整静态检查；随后继续低频轮询目标或后代镜像 |
| 2026-08-06 20:56 | 验收仓库完整静态提交前检查 | 当前验收工作树 | 通过 | 25/25 workflow、25/25 Ornn skill、3/3 channel 定义、21/21 risk 定义、production/Assistant/admission 语法、报告契约、示例配置 materialize、生成的 25 份 YAML 解析及 `git diff --check` 全部通过。首次 YAML 统计 one-liner 仅因输出字符串引号错误在解析前退出，修正命令后 25/25 解析通过 | 继续轮询目标或后代镜像；生产复验前用忽略的 `config.local.yaml` 重新 materialize，避免示例占位符进入运行 |
| 2026-08-06 20:58 | Managed credential lifecycle 部署第三次轮询 | target `b12b748f6`；远端后代 `f984def70` | 等待后代构建 | `git merge-base --is-ancestor` 确认远端新 tip `f984def70` 包含目标修复，后代仅增加 Admin Studio UI 调整；目标 tag 仍无 manifest，deployment 仍是父提交 `5cddd8e1` 的唯一 1/1 Ready 副本 | 接受 `f984def7` 作为可追溯后代候选并继续低频等待其 registry manifest 与唯一 Ready workload |
| 2026-08-06 21:00 | Managed credential lifecycle 部署第四次轮询 | target `b12b748f` / 后代 `f984def7` | 等待构建，无状态变化 | 两个候选 tag 均尚无 registry manifest；deployment 仍为 generation 2701/2701，`5cddd8e1` 唯一副本 1/1 Ready、0 已知 rollout 故障，尚未开始目标或后代 rollout | 拉长轮询间隔，继续等待 manifest；不在旧部署重复 rotate 或 Case 11 |
| 2026-08-06 21:02 | Managed credential lifecycle 目标 rollout 启动 | 目标镜像 `b12b748f`；runtime digest `sha256:a351bfb72e0359362893c7d1718caa2eec63a8ee21df4e54e00ed6e59c1b1bdc` | 等待 Ready | deployment generation/observedGeneration 为 2703/2703、2 个副本中 1 updated/1 Ready；目标 Pod 已拉取运行、0 restart 但 readiness 尚未通过，旧 `5cddd8e1` Pod 继续承载流量 | 低频等待目标 Pod Ready 且旧 Pod 退出；只有目标成为唯一 1/1 Ready 后才复验 rotate |
| 2026-08-06 21:03 | Managed credential lifecycle 目标 Ready 部署 | 目标镜像 `b12b748f`；runtime digest `sha256:a351bfb72e0359362893c7d1718caa2eec63a8ee21df4e54e00ed6e59c1b1bdc` | 通过 | rollout status 成功；deployment generation/observedGeneration 为 2703/2703，目标提交镜像成为唯一副本且 1/1 Ready、updated/available 均为 1、0 restart | 通过 NyxID 正式调用 rotate，仅保留 HTTP、stable code 与 typed receipt 字段存在性；随后只读查询 authoritative state |
| 2026-08-06 21:03 | Managed credential lifecycle 目标部署 rotate 复验 | Ready 镜像 `b12b748f` | 失败，无 typed receipt | 经 `nyxid proxy request aevatar` 调用正式 rotate 仍为 HTTP 502；CLI 进程正常结束但响应无 stable code，`status`、actor/key/command/expiry receipt 字段均不存在。新 401/403 映射未被触发，不能盲目重复轮换 | 只读关联目标 Pod 最近日志与 authoritative state，定位 adapter 前置失败、非标准 NyxID error envelope 或其他 lifecycle code |
| 2026-08-06 21:08 | Managed credential rotate 生产日志首轮关联 | Ready 镜像 `b12b748f`；当前目标 deployment | 无关联日志，诊断未收敛 | 只读拉取最近 2 小时目标 deployment 日志并按 managed Codex、credential、NyxID、rotate、502 过滤，没有命中；Pod 状态查询因未引用的 zsh 数组路径被 shell 在执行前拒绝，本批未产生生产变更，也不能据此判断 502 来源 | 修正只读 Pod 查询并扩大到有界请求/异常日志模式；同时补真实 HTTP 401/403 客户端边界测试，区分应用 lifecycle code 与 ingress/gateway 502 |
| 2026-08-06 21:10 | Managed credential rotate 生产与源码边界复核 | Ready 镜像 `b12b748f`；唯一 Pod | Pod 健康，失败码映射仍不完备 | 修正后的只读查询确认目标 Pod 1/1 Ready、0 restart；最近 30 分钟通用 warn/error/request 过滤仍无命中。源码枚举发现 rotate 前置链的 `nyxid_identity_invalid`、`managed_service_catalog_invalid`、`managed_api_key_list_invalid`、`managed_api_key_issue_invalid` 及 descriptor/vault 校验码仍会默认映射为 HTTP 502，现有 401/403 测试只覆盖其中一个 adapter envelope 分支 | 先增加真实 HTTP 401/403 客户端边界和 endpoint stable-code 完整映射红态；不重复生产 rotate，直到新的失败能返回 typed code |
| 2026-08-06 21:13 | Managed credential rotate NyxID/remote 根因边界 | NyxID 本地源码；Aevatar `origin/feature/integrate=f984def70` | 失败位于 NyxID mutation 之前 | NyxID proxy 对下游非 2xx 原样透传 status/body，不会主动把 401/403 改写为 502；NyxID key rotate 本身先停用旧 key 再创建新 key，而生产旧 key 在两次失败后均保持 active，证明请求未进入该 mutation。Aevatar 远端后代 `f984def70` 明确包含 `b12b748f6` | 从最新远端创建新隔离 worktree，先用真实 HTTP status 的 adapter 红态和 rotate 各前置阶段的 typed endpoint 诊断测试锁定边界，再做最小修复 |
| 2026-08-06 21:15 | Managed credential rotate 新隔离基线 | Aevatar `00c5a22f0`；分支 `codex/managed-rotate-diagnostics-20260806` | 通过 | 创建 worktree 时远端已再次前进到 `00c5a22f0`，ancestry 检查确认它包含 `b12b748f6`；新 worktree 从该最新 tip 创建且初始干净，未接触 Aevatar 主工作树 | 补 endpoint 有界 stable-code 日志红态与真实 HTTP 401/403 adapter 覆盖，再实施最小诊断修复并跑定向/扩大门禁 |
| 2026-08-06 21:17 | Managed credential rotate 诊断红态首次执行 | Aevatar `00c5a22f0`；新隔离 worktree | 未执行测试，构建前置缺失 | 两个精确 `dotnet test --no-restore` 均在编译前因新 worktree 缺少 `obj/project.assets.json` 以 `NETSDK1004` 退出；未把该环境前置误记为红态或通过 | 允许 NuGet restore 后重跑真实 HTTP 401/403 adapter 与 endpoint 有界日志两个精确用例 |
| 2026-08-06 21:20 | Managed credential rotate 诊断红态 | Aevatar `00c5a22f0`；新隔离 worktree | 客户端 2/2 通过；日志红态 1/1 失败 | restore 后真实 HTTP 401/403 adapter 参数用例 2/2 通过，排除 HTTP status 包装差异；endpoint `managed_api_key_issue_invalid` 502 日志断言按预期失败，捕获集合为空，证明当前服务端没有可关联的 lifecycle stage/code 诊断 | 在 endpoint catch 仅记录 operation、stable code 和映射 HTTP status，不记录 exception message、bearer、用户或资源标识；随后重跑两个精确套件 |
| 2026-08-06 21:22 | Managed credential rotate 诊断定向复验 | Aevatar `00c5a22f0`；新隔离 worktree | 通过 | 真实 HTTP 401/403 adapter 2/2 继续通过；endpoint 有界日志 1/1 转绿，断言仅出现固定 operation、stable lifecycle code 与映射 HTTP status，bearer、用户及上游 message 均未进入日志；响应契约和 status mapping 未改变 | 运行完整 ChronoSandbox 与 Capabilities 项目；通过后执行仓库 stability/architecture/语义/docs 门禁并复核 diff |
| 2026-08-06 21:23 | Managed credential rotate ChronoSandbox 全量 | Aevatar `00c5a22f0`；新隔离 worktree | 通过 | `Aevatar.AI.Infrastructure.ChronoSandbox.Tests` 完整项目 213/213 通过，无失败或跳过；真实 HTTP transport 分类与 credential lifecycle 其他路径均未回归 | 运行完整 Capabilities 项目，若仅命中已知 Redis 7.2.3 本地前置则精确排除环境用例复核其余集合 |
| 2026-08-06 21:26 | Managed credential rotate Capabilities 全量 | Aevatar `00c5a22f0`；本机 Redis `8.6.2` | 受影响代码通过；3 项环境前置不满足 | 完整 Capabilities 648 项中 645 通过；仅 3 个 `AgentToolAdmissionLedgerTests` 在启动 fixture 时因固定要求 Redis `7.2.3`、实测 `8.6.2` 失败，新增 endpoint 日志及全部 credential/Host 用例均通过 | 仅按三个完整测试名精确排除环境用例重跑其余 645 项，不排除整个类或任何 managed credential 用例 |
| 2026-08-06 21:28 | Managed credential rotate Capabilities 环境隔离复验 | Aevatar `00c5a22f0`；本机 Redis `8.6.2` | 通过 | 仅按三个完整测试名排除固定 Redis 7.2.3 前置后，其余 645/645 通过；未排除整个类、credential lifecycle、Host endpoint 或本轮新增测试 | 运行 stability、architecture、proto/语义、docs lint 与 `git diff --check`，复核最终 diff 只含 endpoint、两组测试及必要文档 |
| 2026-08-06 21:29 | Managed credential rotate 修复范围复核 | Aevatar `00c5a22f0`；新隔离 worktree | 通过 | 当前 diff 仅 3 文件：Host endpoint 增加有界 stable-code warning、adapter 测试改为真实 HTTP 401/403、Host 增加日志脱敏回归测试；响应、状态映射和 lifecycle 编排均未改变 | 在既有 managed Codex rollout 运维文档补充日志字段/脱敏边界，再执行完整提交前门禁 |
| 2026-08-06 21:32 | Managed credential rotate 提交前门禁 | Aevatar `00c5a22f0`；新隔离 worktree | 通过 | test stability 及全部 guard meta-tests、完整 architecture full-scan、proto、NyxID chat 语义、workflow closed-world/binding/run-id、channel、CQRS、audit、runtime callback、docs lint 与 `git diff --check` 均通过；并行显式 Architecture Tests 首次因缺 assets 未执行，但完整 architecture guard 内部 restore 后同一项目 15/15 通过 | 最终复核 4 文件 diff、敏感信息和工作树；fetch 最新远端，若前进则 rebase 并重跑定向测试/门禁，否则提交最小诊断修复 |
| 2026-08-06 21:33 | Managed credential rotate 最终 diff/文档复核 | Aevatar `00c5a22f0`；新隔离 worktree | 通过 | 最终仅 4 个预期文件、96 insertions/6 deletions：endpoint、真实 HTTP status 测试、日志脱敏测试和既有运维文档；docs lint 87/87、`git diff --check` 通过。新增 bearer/key/message 均为合成负断言，没有真实凭据或运行标识 | fetch 最新 `origin/feature/integrate`；远端前进则 rebase 后重跑定向测试与门禁，否则提交并普通推送 |
| 2026-08-06 21:34 | Managed credential rotate 提交前远端一致性 | Aevatar 本地/远端 `00c5a22f0` | 通过 | fetch 后本地 HEAD 与 `origin/feature/integrate` 完整 SHA 精确一致，远端未前进；worktree 仍只有 4 个预期文件修改，无需 rebase | 仅暂存 4 个预期文件并提交；随后再次 fetch，确认远端基线未变化后普通推送 |
| 2026-08-06 21:35 | Managed credential rotate 诊断修复提交 | Aevatar 提交 `ee031038b`；父提交 `00c5a22f0` | 通过 | 仅提交 endpoint 有界 stable-code 日志、真实 HTTP 401/403 回归测试、日志脱敏回归测试和运维说明 4 文件；提交信息为 `fix: log managed credential lifecycle failures` | 再次 fetch `origin/feature/integrate`；远端仍为父提交才普通推送 `HEAD:feature/integrate` |
| 2026-08-06 21:36 | Managed credential rotate 最终推送门槛 | 本地 `ee031038b`；远端 `00c5a22f0` | 通过 | 第二次 fetch 后本地提交父节点与 `origin/feature/integrate` 完整 SHA 精确一致；worktree 干净、仅 ahead 1，无需 rebase | 普通推送 `HEAD:feature/integrate`，随后用 `git ls-remote` 回读远端完整 SHA |
| 2026-08-06 21:37 | Managed credential rotate 诊断修复推送 | `origin/feature/integrate`；提交 `ee031038b` | 通过 | 普通推送成功；`git ls-remote` 回读远端 tip 为 `ee031038b3d498648d90283b55f6e30a1fa2549f`，与本地提交精确一致，未使用 force push；隔离 worktree 干净 | 低频轮询 registry 与 Ready workload；只有该提交或明确后代成为唯一 1/1 Ready 后才复验 rotate 并读取有界 stable-code 日志 |
| 2026-08-06 21:38 | Managed credential rotate 部署首次轮询 | 提交 `ee031038b`；错误 registry probe tag `ee031038b`；Ready `00c5a22f` | 等待构建 | registry probe 误用了 9 位 tag，返回 manifest 不存在，不能作为正确 8 位部署 tag 的 manifest 证据；deployment generation/observedGeneration 为 2707/2707，父提交镜像唯一 1/1 Ready、updated/available 均为 1；远端 tip 仍精确为目标提交，没有 rollout 失败信号 | 改用 8 位镜像 tag `ee031038` 复核 registry 与 Ready workload，部署前不重复 production rotate |
| 2026-08-06 21:39 | Managed credential rotate 部署第二次轮询 | 提交 `ee031038b`；错误 registry probe tag `ee031038b`；Ready `00c5a22f` | 等待构建，无状态变化 | 约 30 秒后的 registry probe 仍误用了 9 位 tag，因此 manifest 不存在结果无效；deployment 保持 generation 2707/2707、父提交镜像唯一 1/1 Ready，尚未开始目标 rollout | 改用 8 位镜像 tag `ee031038`；等待窗口复核验收 README/report 与最终 inventory，不在旧部署重复写探针 |
| 2026-08-06 21:40 | 验收 README/report 与 Skill 等待窗口复核 | 当前验收工作树 | report/inventory 通过；Skill validator 环境阻塞 | report validator 通过；动态清单仍为 25 workflow、25 skill、3 channel、21 risk、1 schedule、6 fixture，`git diff --check` 通过。系统 `python3` 缺少 PyYAML，官方 `quick_validate.py` 在导入阶段退出，未进入 Skill 校验，不能记为 Skill 失败 | 使用 Codex 随附依赖环境重跑同一官方 validator；随后继续低频轮询目标部署 |
| 2026-08-06 21:41 | 验收闭环 Skill 官方校验 | `.agents/skills/aevatar-acceptance-loop` | 通过 | 系统与随附 Python 均缺 PyYAML；改用一次性 `uv --with pyyaml` 环境运行同一官方 `quick_validate.py` 后输出 `Skill is valid!`，未修改仓库或全局 Python。Codex 入口与 Claude Code 软链接继续指向同一 Skill | 继续轮询 `ee031038b` registry/Ready 部署；部署后仅重试一次 rotate 并用新有界日志定位 stable code |
| 2026-08-06 21:42 | Managed credential rotate 部署第三次轮询 | 提交 `ee031038b`；错误 registry probe tag `ee031038b`；Ready `00c5a22f` | 等待构建，无状态变化 | registry probe 仍误用了 9 位 tag，不能据其 manifest 不存在判断正确 8 位 tag 的构建状态；deployment 继续为 generation 2707/2707、父提交镜像唯一 1/1 Ready；远端 tip 未变化且无 rollout 失败 | 改用 8 位镜像 tag `ee031038` 并继续检查 Ready workload |
| 2026-08-06 21:43 | Managed credential rotate 部署第四次轮询 | 提交 `ee031038b`；错误 registry probe tag `ee031038b`；Ready `00c5a22f` | 等待构建，无状态变化 | 本轮 manifest 不存在仍来自错误 9 位 tag，不能作为目标 manifest 证据；deployment 仍为父提交唯一 1/1 Ready、generation 2707/2707，未观察到失败 rollout | 改用 8 位镜像 tag `ee031038`，并继续检查远端后代与 Ready workload |
| 2026-08-06 21:44 | Managed credential rotate 部署第五次轮询 | 提交 `ee031038b`；错误 registry probe tag `ee031038b`；Ready `00c5a22f` | 等待构建，无状态变化 | registry probe 的 9 位 tag 错误使 manifest 结论无效；deployment 父提交继续唯一 1/1 Ready、generation 2707/2707；远端 tip 仍精确为目标提交，没有后代候选 | 改用 8 位镜像 tag `ee031038`，部署前不运行 production 写探针 |
| 2026-08-06 21:45 | Managed credential rotate 部署第六次轮询 | 提交 `ee031038b`；错误 registry probe tag `ee031038b`；Ready `00c5a22f` | 等待构建，无状态变化 | registry probe 的 manifest 不存在结果因 9 位 tag 错误而无效；deployment 仍为父提交唯一 1/1 Ready、generation 2707/2707，无失败信号 | 改用 8 位镜像 tag `ee031038`，随后复查 registry、deployment 与远端 tip |
| 2026-08-06 21:46 | Managed credential rotate 部署第七次轮询 | 提交 `ee031038b`；错误 registry probe tag `ee031038b`；Ready `00c5a22f` | 等待构建，无状态变化 | registry probe 仍错误使用 9 位 tag，不能据此判断正确 tag 是否已有 manifest；deployment 父提交唯一 1/1 Ready、generation 2707/2707，远端 tip 仍精确为目标提交 | 改用 8 位镜像 tag `ee031038` 检查 manifest 与 Ready workload |
| 2026-08-06 21:39 | Managed credential rotate 目标 Ready 复核 | 镜像 `ee031038`；提交 `ee031038b`；runtime digest `sha256:f7d85dca2c81e89f230aad7b88fc8287db279e195e64b32239793700f5c097d2` | 通过 | 使用正确 8 位部署 tag 复核；rollout status 成功，deployment generation/observedGeneration 为 2709/2709，目标镜像唯一副本 1/1 Ready、updated/available 均为 1、0 restart | 仅通过 NyxID 正式重试一次 rotate；随后读取 authoritative credential state 和新有界 stable-code 日志 |
| 2026-08-06 21:45 | Managed credential rotate 目标部署复验 | Ready 镜像 `ee031038`；authoritative state 3 | 失败，mutation 未开始 | 仅通过 `nyxid proxy request aevatar` 调用一次 rotate，返回 HTTP 502 且无 typed receipt；前后状态均为 active/ready、state version 3、cleanup 0。新有界日志精确命中 `chrono_sandbox_delegation_misconfigured`，未保存原始响应、Pod 名称或任何凭据标识 | 对照 Aevatar catalog resolver 与 NyxID 本地源码，区分生产 UserService 配置缺口和 Aevatar 过严校验；先补最小红态再修复 |
| 2026-08-06 21:47 | Managed credential rotate NyxID 配置归因 | 当前用户的 `chrono-sandbox` / `chrono-llm-public` UserService | 配置阻塞，不是 Aevatar 缺陷 | 只读回读确认两条服务均 active/personal；`chrono-sandbox` 当前为 `forward_access_token=true`、`inject_delegation_token=true`、scope=`llm:proxy`，不满足运维文档固定前置 `false/true/proxy:*`。Aevatar resolver 与测试按设计在 key mutation 前 fail closed；当前安装的 `nyxid service update` 也未提供三项策略参数，未编写临时 HTTP 绕过 CLI | 继续所有不依赖 managed credential 的 case；最终仅把这项列为外部配置 blocker，取得显式安全变更路径后再调整 UserService 并复验 rotate/Case 11 |
| 2026-08-06 21:48 | 生产配置 materialize fresh 批次 | `config.local.yaml`；当前动态 inventory | 通过 | 16 个本地 replacement 均已解析，重新生成 25 个 ignored build workflow；25/25 份 YAML 均通过 `YAML.safe_load`，命令输出未包含 replacement 值 | 从 `/api/auth/me` 恢复并交叉校验 scope，在不启动 workflow 的前提下执行全部 production preview |
| 2026-08-06 21:50 | Production explicit-request preview fresh 批次 | Ready 镜像 `ee031038`；scope hash `237314c29964` | 通过 | 使用本地生产 materialization 动态验证全部 25 个 workflow；25/25 preview 通过，call-site method、path template、risk、approval enforcement 与 interactive execution mode 均满足 registry 契约；未启动 workflow、未产生外部写入 | 先运行无副作用和纯只读 direct runtime；Case 11 保持 NyxID 配置 blocker，副作用分支另批复核目标与清理条件 |
| 2026-08-06 22:01 | 无副作用与只读 direct runtime fresh 批次 | Ready 镜像 `ee031038`；21 个 case | 20 通过，1 个 invoke 失败 | 01-05、07-09、12-23 均取得 committed `completed`、完整步骤和严格 artifact；05、07-10 使用 preview 分支且未写入，14/17 各观察并恢复 1 次 typed read-only approval。Case 10 在 `invoke_workflow` 收到 HTTP 502，未取得 run evidence，不能记为运行失败或通过 | 单独 fresh 重跑 Case 10 preview 分支；复现则关联有界生产日志和 NyxID proxy 边界，不重复整批 |
| 2026-08-06 22:02 | Case 10 invoke 定向复验 | Ready 镜像 `ee031038`；fresh run hash `638a9e09e789` | 通过 | 相同生产 materialization 与 preview prompt 下取得 committed `completed`、state 67、10/10 步，严格 artifact 命中；`approval_created=false`、`message_sent=false`。首轮 502 未复现且未形成 run，当前归为瞬时传输失败 | fresh 运行 Case 11 固定 managed probe，保留 committed 终态并与已确认的 NyxID delegation 配置 blocker 对照 |
| 2026-08-06 22:03 | Case 11 managed probe fresh runtime | Ready 镜像 `ee031038`；run hash `be807f86ddab` | committed 失败，配置阻塞 | preview 通过且 0 外部 call site；运行 committed `failed`、state 31、4/4 步，公开失败为 `codex_execution_admission_denied`、无 final artifact。有界内部日志同时出现 `managed_proxy_authentication_failed`；结合 rotate 的 `chrono_sandbox_delegation_misconfigured` 与只读 UserService 配置，仍归因于 NyxID delegation 前置未满足 | 不修改 Aevatar；继续副作用 probe、Assistant/channel/risk/schedule/Ornn 验证，待获得安全的 UserService 策略更新路径后复验 rotate 与 Case 11 |
| 2026-08-06 22:05 | 可清理 Base 写探针 fresh runtime | Ready 镜像 `ee031038`；Cases 05/24/25 | 通过 | 三项均 committed `completed` 并命中严格 artifact；05 与 24 各观察/恢复 1 次 typed approval，25 连续观察/恢复 2 次，共创建 4 条固定合成前缀 Base 记录。未执行消息或审批写分支 | 只读按三个固定合成前缀定位本轮记录；仅在记录集合和字段契约精确匹配时删除并回读确认 |
| 2026-08-06 22:07 | Base 探针清理只读盘点 | 资产盘点合成表；固定验收 key/字段契约 | 通过盘点，待清理 | 表内 7 条记录中，6 条精确命中仓库固定验收 key：3 条 `manual-asset-attestation-20260804`、1 条本轮 runtime、2 条本轮 sequential；另 1 条不匹配验收模式并排除。Case 05 key 固定且无自动创建时间字段，无法只区分本轮与两条历史残留 | 删除前再次校验 6 条的 Control/Owner/Status/Sequence/Reviewed At 全字段；仅删除完整匹配的验收记录并回读要求匹配数为 0 |
| 2026-08-06 22:09 | Base 探针精确清理 | 本轮 4 条 + 同 key 历史残留 2 条 | 通过 | 删除前 6/6 条同时满足固定 key 与 Control/Owner/Status/Sequence/Reviewed At 契约；逐条 DELETE 均返回 code 0，重新列表后四类验收 key 匹配数为 0，未匹配的第 7 条记录未触碰。仓库未保存 record ID；可恢复性取决于目标 Base 回收站策略 | 运行 `/api/chat` Assistant 动态案例并按 typed artifact 区分 validated、typed failure 与未启动 |
| 2026-08-06 22:19 | Assistant `/api/chat` fresh 批次 | Ready 镜像 `ee031038`；01/12/13/14/15 | 5/5 通过 | 五项均按 Ornn 搜索、精确 skill、typed mount approval、workflow 启动与 committed current state 完成，`workflowValidationStatus=validated`、`workflowValidated=true`、`caseValidated=true`，严格 artifact 全部命中。12/14 的最终自然语言仍描述旧 Running/Awaiting 状态，未覆盖 committed `completed` 机器证据 | 使用 Lark channel canary 真实验证 channel cases；不得从 `/api/chat` 结果外推 webhook、callback 或 Lark 回传通过 |
| 2026-08-06 22:35 | Lark channel fresh 批次 | Case 19 镜像 `19b5906b`；Channel 20-22 镜像 `ee031038` | 2 通过，2 失败 | Case 19 最新 run hash `03c3f4ded68e` committed 4/4；114 字节文件卡片经尾随 LF 归一化为 113 字节 committed descriptor/extraction，文件、SHA、Lark ingress、脱敏与无副作用 artifact 全命中。Case 22 新 run hash `08cdd96d61dd` 从 `awaiting_tool_approval` 经最后一张 workflow 卡只批准一次后 committed 3/3，严格 artifact 命中。Cases 20/21 均未出现新 mount 审批卡，以 `InvalidWorkflowYaml` 结束，目标 workflow run delta=0 | 同步 risk/channel 机器摘要、Markdown/HTML 报告并修复报告校验器；随后定位 Cases 20/21 的 Aevatar definition resolution 根因 |
| 2026-08-06 19:41 | 动态未通过 case 账本复核 | 当前 risk/channel 机器摘要 | 通过盘点、未全绿 | 3 个 channel 为 pending-execution；risk 中 4 failed、2 blocked、1 pending-execution、5 not-configured。稳定缺口覆盖 Lark typed deny/AgentRun、Assistant `code_execute` authority、`workflow_call` definition resolution、parallel/race deterministic worker，以及缺少 disposable source target 的发送/提交/schedule | Case 11 恢复后先处理无需新增外部资源的平台/runtime 缺陷，再执行真实 Lark；源副作用项只在可清理目标与 authority 齐全时运行 |
| 2026-08-06 19:42 | Aevatar 诊断镜像与 Ready 联合轮询 | tag `f0337b80` / Ready `5240e518` | 等待构建，无状态变化 | registry 仍无目标 manifest；deployment 仍为 generation 2691、1/1 Ready、updated/available 为 1。没有 rollout 失败，目标代码尚未进入镜像 | 等待期间只读定位 Risk 37 当前源码边界；随后继续低频联合轮询 |
| 2026-08-06 19:43 | Risk 37 workflow_call 当前源码归因 | 历史基线 `6df43b83` / Ready `5240e518` | 需要 fresh 复验 | 旧失败报告锁定 Studio provision 缺 inline definition；当前 Aevatar 已有 registry definition resolver 与 resolved binding 主链，且 Ready 镜像精确包含新的 workflow catalogue 修复 `5240e518`，历史 30 秒超时不能继续代表当前状态 | 找到现有无副作用 workflow_call probe/入口，在 `5240e518` fresh 运行并以 child start 与 committed artifact 判定 |
| 2026-08-06 19:44 | Risk 37 catalogue 修复边界复核 | Ready/提交 `5240e518` | Aevatar 缺陷仍存在 | 精确 diff 显示该提交只新增 scope workflow catalogue 查询，未给 Studio `/provision-workflow` 增加 inline child definitions，也未改变验收入口的单 YAML 绑定；registry resolver 本身不能让未绑定子定义可见，旧 30 秒超时机制仍由当前源码解释 | Case 11 诊断部署完成后，为 provisioning 多定义契约补回归测试与最小 Aevatar 修复，再新增正式无副作用 workflow case 覆盖 workflow_call |
| 2026-08-06 19:44 | Aevatar 诊断镜像与 Ready 再轮询 | tag `f0337b80` / Ready `5240e518` | 等待构建，无状态变化 | registry 仍返回目标 manifest 缺失；deployment generation 2691 完全 observed、1/1 Ready，无 rollout 错误。目标修复还未进入任何可复验镜像 | 再有界等待 45 秒；若仍无 manifest，检查外部部署节奏/后续远端提交，不重复运行失败 case |
| 2026-08-06 19:45 | Aevatar 诊断部署 45 秒有界等待 | tag `f0337b80` / Ready `5240e518` | 等待构建，无状态变化 | 等待后 registry 仍无 manifest，deployment 仍 1/1 Ready、generation 2691/2691；无失败 rollout，也无可追溯目标镜像 | 查看 registry 最近 tag 时间和 ReplicaSet 历史以确认外部构建节奏；继续处理不依赖目标部署的诊断 |

## 财务源工作流 post-fix 验收

这组结果独立于下方公开案例统计，使用当前 `~/workflows` 源定义、同结构安全变体和脱敏生产输入取得。财务 scope 的同一 run 对照显示 Base 读取成功、随后 `code_execute` 401；源码契约将根因定位为 sandbox UserService 未转发 caller bearer。Aevatar execution delegation 已包含所需执行权限，只调整 sandbox 转发策略且未添加静态 credential。下列结果证明功能主链已在线执行成功，但不代表安全限制下的发送、审批和排程分支也已运行。

| 源定义 | Preview / 输入边界 | 真实终态 | 副作用与结论 |
|---|---|---|---|
| 单步 `code_execute` probe | 新 member；一个固定输出的无副作用步骤 | 单次 invoke，run catalog `0 -> 1`，1/1 completed，`lastSuccess=true`，final output 非空 | scope 特定 sandbox bearer 转发链通过 |
| P2 shared-Base no-send 同结构运行定义 | 基于 `budget_monitor_weekly.shared-base.nosend.yaml` 刷新 live selector，不是当前文件的逐字副本；6 个唯一 GET；全部 read-only；0 approval | 单次 invoke，run catalog `0 -> 1`，8/8 completed，`lastSuccess=true`；首个 Base 输出与 final output 非空 | 未发送消息，未创建 schedule；#3161 `nyxid_proxy -> code_execute` 功能主链通过，不外推到当前文件或旧 Base |
| `invoice_file_chain.v5.workflow.json` | exact JSON；5 个唯一 call site；sanitized PNG；`submit=false` | 只 invoke 一次；14/14 实际步骤 completed，`lastSuccess=true`，final output 非空 | 图片抽取、只读 lookup、preview presentation 通过；完整提交分支未执行，无 approval、无 Lark 写入 |
| PDF attachment probe | 无副作用 PDF 输入 | run catalog +1，2/2 completed，`lastSuccess=true`；extract 与 final output 非空 | PDF 附件接收与抽取主链通过 |

源目录中明确未运行：P2 send workflow、P1 v6、durable/weekly schedule 和 P1 v2 旧定义。它们不是“没有 case”：分别由 Risk 40、41、30 和 42 约束。前三个源副作用定义缺一次性目标、显式授权或清理闭环；P1 v2 还需先隔离旧硬编码集成语义。真实 Lark attachment canary 已由 Risk 24 关闭，不能混入这组未运行项；公开验收案例 15 的 schedule 成功也不能替代源排程定义证据。

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
| 19 | `lark_bot_file_upload_validation` | 3 | Lark 入站 file ref、单次 `document_extract`、SHA-256 与 transport 证据分层 | preview 通过；direct committed 4/4、`stateVersion=30`；fresh Lark committed 4/4、`stateVersion=32`、run hash `03c3f4ded68e`，typed artifact 精确命中 | 无业务副作用；skill `1.1`；114 字节卡片归一化为 113 字节 descriptor/extraction；原始标识未持久化 |
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
| 20 | `lark_agent_run_skill_approval_approved` | 批准 | 真实 Lark inbound/relay；审批卡可见；`Approval pending` 不进入模型回复；回调精确匹配 run/request/call/hash/sender/scope/conversation 且只分发一次；同一 AgentRun 恢复；`use_skill=Completed`；workflow 只启动一次；取得精确 committed artifact | `failed`：审批卡前 `InvalidWorkflowYaml`，run 增量 0 |
| 21 | `lark_agent_run_skill_approval_rejected` | 拒绝 | 真实 Lark inbound/relay；审批卡只分发一次；同一挂起调用返回 typed `Denied` / `approval_denied`；不执行 mount；workflow start=0；run catalog 增量=0 | `failed`：没有可拒绝的新审批卡，`InvalidWorkflowYaml`，run 增量 0 |
| 22 | `lark_workflow_runtime_tool_approval_approved` | 批准 | skill 已挂载且不出现新 mount 审批；workflow start=1；新 run 晚于本次 Lark inbound 启动；审批卡投递与回调各一次；同一 workflow run 恢复；3/3 steps、stateVersion 30、脱敏 artifact 精确命中 | `passed` |

Case 20/21 的目标修复提交 `9f67c528174ac477bb144d6bd1525444e7c971cf` 已包含在 Ready 生产镜像中；fresh 实测均在 mount 审批前以 `InvalidWorkflowYaml` 失败，目标 run 增量为 0。Case 22 的目标提交 `3f62ff62bcb32f7fb7c97aea8a7920aadd29d398` 已进入生产；最新真实运行 hash `08cdd96d61dd` committed `completed`，workflow 审批卡与 CardAction 各一次，普通 AgentRun 可见回复为 0，最终 relay 为 1，观测详情未持久化原始联系人标识。Bot 文案、`[tool receipt] Approval pending`、审批卡本身或 direct workflow 成功仍不能替代这些证据。

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
| 24 | Lark 附件经 catalog 启动 | `passed` | public skill `1.1` 精确解析；隔离基线后目标 run 数量 `6 -> 7`，唯一新增 run hash `03c3f4ded68e` committed `completed`、state 32、4/4，typed artifact 精确命中 |
| 25 | Lark sender service scope | `passed` | 同 sender 的 fresh Case 22 已解析精确 skill，运行期批准后同一 run committed completed；contact artifact 精确命中，历史 `NYXID_PROXY_SERVICE_SCOPE_FORBIDDEN` / `NYXID_PROXY_UNAUTHORIZED` 均未出现 |
| 26 | `/api/chat` 安全 code_execute | `passed` | Ready `ee031038` 上按原 `/api/chat` 入口 fresh 重跑 Case 12：search-first、精确 skill、workflow start、4/4 committed completed，`total_cents=16623` 且无副作用 |
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

使用仓库内 114 字节合成 JSON，通过 `input_file_refs -> document_extract` 验证文件名、媒体类型、字节数和固定 SHA-256，全程不调用 Lark 写接口。Production preview 已通过且为 0 个外部 call site；public skill `1.1` 已精确回读。Direct run hash `e6d17331400b` committed `completed`、`stateVersion=30`、4/4，并按入口分层得到 `lark_bot_ingress_validated=false` 和 114 字节 LF 变体。fresh Lark canary 在 6 条既有目标 run 的隔离基线上只新增 1 条；run hash `03c3f4ded68e` committed `completed`、`stateVersion=32`、4/4。Lark 文件卡片显示 114 字节，下载后的 committed descriptor/extraction 因尾随 LF 归一化为 113 字节；artifact 精确满足 `success=true`、文件登记/抽取/内容匹配、`lark_bot_ingress_validated=true`、文件名/正文/SHA-256 匹配、脱敏和 `side_effects=false`。历史 `service_catalog_missing` 与不完整 artifact 只保留为恢复路径证据，不覆盖最新严格通过。公开摘要不保存文件消息、resource key 或其他 opaque ID。

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
- 12：Ready 镜像 `ee031038` 上 fresh 严格状态 `validated`，workflow committed `completed`，固定 JavaScript 结算 artifact 精确命中 `total_cents=16623` 与 `side_effects=false`。Assistant 最终文案仍描述旧 Running 状态，不参与终态判定。
- 13：严格状态 `validated`，图片 file ref 进入真实执行，12/12 步完成，`success=true`，`stateVersion=82`。
- 14：Ready 镜像 `ee031038` 上 fresh 严格状态 `validated`，workflow committed `completed`，`success=true`、`resolved_count=1` 且联系人标识未回显。Assistant 最终文案仍描述旧 Awaiting 状态，严格判定只采用 committed artifact。
- 15：在生产镜像 `d7844b5e` 上严格状态 `validated`，六路 Base 读取与周/月差异断言通过，11/11 步完成，`stateVersion=73`。Assistant 最终读取并报告 committed typed artifact，`artifactPendingReportedAsFinal=false`。

五个案例已在 Ready 镜像 `ee031038` 上 fresh 验证，均先搜索 Ornn，再加载精确 skill、完成 typed mount approval、启动 workflow 并读取 committed current state，严格状态为 5/5 `validated`。公开 SSE 中成功工具结果仍可能只有通用 `completed`，所以验证器使用 typed run identity 查询 workflow current state；它既不会把 Assistant 文案中的 pending 改写成成功，也不会让陈旧的 Running/Awaiting 文案覆盖 committed artifact。

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

Case 19 的 `--run` 仍只验证 direct synthetic fixture，预期 `lark_bot_ingress_validated=false`；真实 Lark canary 则已从唯一 fresh committed run 的 typed artifact 读取到 `lark_bot_ingress_validated=true`。这两层证据不能互相替代，Bot 回复文案和文件卡片也仍不参与 workflow 成功判定。当前通过仅适用于公开合成 fixture 的三个精确规范变体：113 字节无换行、114 字节 LF、115 字节 CRLF，不接受模糊正文匹配。

`build/`、`tmp/` 和 `config.local.yaml` 均被忽略。合成附件位于 `fixtures/`，schedule 示例位于 `schedules/`。

## 生产验证边界

- 所有生产请求必须使用 `nyxid proxy request aevatar ...`；不得直连后端、复制 bearer 或借用浏览器 session。
- 一律先 preview。写入分支需要明确的用户意图、允许列表和 typed tool approval。
- 平台工具批准不等于 Lark 业务审批；新建审批通常仍是 `PENDING`。
- 只有 typed receipt、run ID、业务断言和 committed terminal evidence 齐全，才可写成 workflow 通过。
- managed `codex_exec`、typed approval 和 schedule 的现有边界不得通过 mock 成功结果或业务 artifact 掩盖；contact 的业务成功必须同时核对批准身份链与脱敏断言。
- #3161 已关闭；Case 16 覆盖共同 receipt/runtime 平面，源 P2 no-send 又在当前部署上覆盖 published-operation authority 主链并 committed 完成。该结论只适用于 no-send 只读执行，不外推到消息发送或 durable schedule。
- #3184 仍开放；Case 17 的历史 run 证明过批准 resume，但最新 `0c4ff023` run 未观察到 typed pending/resume，当前记为契约回归。拒绝路径在此状态下不可达，durable preview 仍需独立证据。
- Case 19 已有静态、preview、direct committed 与 fresh Lark committed 4/4 证据；public skill 版本为 `1.1`，最新 run hash `03c3f4ded68e` 的 typed artifact 明确给出 `lark_bot_ingress_validated=true`，114 字节文件卡片与 113 字节 committed extraction 的尾随 LF 归一化已分层记录，Risk 24 严格通过。
- Case 20/21 分别覆盖 #3210 的 skill mount 批准和拒绝路径，本轮均在审批卡出现前以 `InvalidWorkflowYaml` 阻塞且 run 增量为 0；Case 22 的 workflow 运行期批准路径已由真实 Lark 审批卡、同一 run continuation 和 committed artifact 严格通过。不能用 Case 22 外推 Case 20/21，也不能用 Bot 文案或 direct Case 14 结果代替。
- 不得提交 token、真实组织标识、业务载荷、审批表单或未脱敏运行证据。

新增和维护案例的完整规则见 [AGENTS.md](AGENTS.md)。

## 许可证

MIT。`LICENSE` 保留标准英文法律原文。
