# Aevatar 全案例当前状态报告

观测窗口：2026-08-07 13:15-13:49 SGT（05:15-05:49 UTC）。

本报告是一次 append-only 的 fresh 复验快照。它不修复 workflow、skill、验证脚本或生产配置，也不把历史成功替换成本轮成功。机器证据见 [`validation/full-revalidation-2026-08-07.json`](../validation/full-revalidation-2026-08-07.json)。本窗口之后的部署和单案例观测应按时间线另行判断，不能反向改写本快照。

窗口后追记：13:56 SGT，Case 11 在新 Ready `5f51f6d0` 上 preview 通过，run `72b16525a3d8` 仍 committed `failed`、state 31、4/4，稳定错误仍为 `codex_execution_capacity_unavailable`，无 final artifact、approval、resume 或副作用。因此当前 Case 11 结论未改变，本次全量汇总也不回算。

再次追记：14:29-14:36 SGT，Aevatar committed 诊断修复 `eead35c089758b26f7b0fd4c277dbbe71815b0cc` 已成为唯一 1/1 Ready、0 restart 的 production image `eead35c0`。Case 11 preview 通过后唯一 fresh run `106ecf7b750a` 仍 committed `failed`、state 31、4/4，错误为 `codex_execution_capacity_unavailable`，无 artifact、approval、resume 或副作用。新部署未观察到 allowlisted upstream code；同一 UserService 与 OpenSandbox health 绿色只证明连接，不证明 sandbox creation capacity。全量快照分母与汇总继续不回算。

第三次追记：[#3290](https://github.com/aevatarAI/aevatar/issues/3290) 记录了 14:03-14:42 SGT 的源迁移主链连续性回归。P2 在同一 member、binding 和定义下于 14:09:19 完成 14/14，业务数字与现行系统复算一致；14:18:27 同链在 `code_execute` 以 `NYXID_PROXY_HTTP_502` 失败，14:20-14:42 同一请求体又连续 5 次被 `NYXID_ADMISSION_SOURCE_CREDENTIAL_REQUIRED` 拒绝。P1 在另一个已绑定定义上第 1/27 步即出现 `Forwarding failed`，workflow 代码尚未执行。该证据来自 issue/同事运行记录，不是本仓库独立重跑；因此保留历史成功，但当前迁移主链标记为 `regression-blocked`，且不回算 13:15-13:49 的全量快照。

## 当前结论

本地静态面全部通过：29/29 workflow、29/29 skill、3/3 channel 定义、21/21 risk 定义、1/1 regression 定义；两套配置均物化并解析 29/29 workflow。Production explicit-request preview 为 29/29。

Fresh 运行面并未全绿：direct runtime 为 25 passed、1 platform-blocked、3 skipped；Assistant 代表集为 4 validated、1 chat-failed；Ornn 版本为 28/29 一致；Lark channel 为 2 passed、1 start-blocked。Case 19 的 Lark 文件 canary 和 R01 `/init` 均通过。

当前非绿项：

- Case 11 committed `failed`，稳定错误码为 `codex_execution_capacity_unavailable`，没有 final artifact。
- Assistant Case 15 在单次定向重试后仍为 `STREAM_FAILURE`，未搜索 Ornn、未 mount、未启动 workflow。
- Ornn `supplier-risk-tier-aggregation` 本地为 `1.1`、public catalog 为 `1.0`；29 项均存在、公开且服务端格式有效，但版本只匹配 28/29。
- Channel Case 22 返回 typed `InvalidWorkflowYaml`，run catalog 增量为 0，当前判定 `start-blocked`。
- Cases 06、24、25 因本轮没有副作用授权而跳过；本轮没有 fresh 创建 schedule。
- 源迁移 P1/P2 的历史成功不再能证明当前连续可用；#3290 的相邻时间序列显示 admission、`code_execute` 和 actor forwarding 同时回归，两条迁移线当前均为 `regression-blocked`。

## Direct Runtime 01-29

成功只来自 committed terminal 与严格 artifact；`preview`、HTTP 202、模型文案和 pending 状态均不计成功。

| Case | workflow | fresh 状态 | committed 证据 / 跳过原因 |
|---|---|---|---|
| 01 | `release_readiness_review` | passed | `50e9357ddb64`，state 80，13/13 |
| 02 | `candidate_document_compliance_preview` | passed | `240023738222`，state 35，4/4 |
| 03 | `email_access_approval_audit` | passed | `6e4597fbabce`，state 42，6/6 |
| 04 | `saas_license_utilization_review` | passed | `f89f4a4143bd`，state 67，10/10 |
| 05 | `asset_inventory_attestation` | passed | `553ed811299a`，state 37，5/5；preview branch，无写入 |
| 06 | `project_shared_mailbox_approval` | skipped | 未授权创建 Lark 审批 |
| 07 | `quarterly_access_review_reminder` | passed | `4d05876f88f8`，state 37，5/5 |
| 08 | `saas_license_optimization_digest` | passed | `ea1a136e9f5a`，state 91，14/14 |
| 09 | `contractor_access_package_approval` | passed | `68a50767ae79`，state 77，11/11 |
| 10 | `monthly_access_certification` | passed | `aa034b36f115`，state 67，10/10 |
| 11 | `complex_codex_exec_validation` | platform-blocked | `22876437b5b1`，committed `failed`，state 31，4/4；`codex_execution_capacity_unavailable`；无 artifact |
| 12 | `safe_code_execute_validation` | passed | `5f0fbfd1642c`，state 31，4/4；`total_cents=16623` |
| 13 | `invoice_ocr_policy_review` | passed | `f0355340bad2`，state 82，12/12 |
| 14 | `lark_contact_batch_resolution` | passed | `f10aa7837a87`，state 28，3/3；typed approval/resume 1 次 |
| 15 | `weekly_budget_variance_digest` | passed | `f5121b2da187`，state 73，11/11 |
| 16 | `nyxid_read_receipt_probe` | passed | `cb5b7aab6ad1`，state 31，4/4 |
| 17 | `lark_post_search_approval_probe` | passed | `92fd3ce658ea`，state 34，4/4；typed approval/resume 1 次 |
| 18 | `supplier_control_attestation_review` | passed | `4cc2319f79f6`，state 92，15/15 |
| 19 | `lark_bot_file_upload_validation` | passed | `126cd282b52b`，state 30，4/4；direct ingress=false |
| 20 | `supplier_risk_tier_aggregation` | passed | `63495525483b`，state 95，16/16 |
| 21 | `approval_window_integrity_audit` | passed | `0cfe6cd226bc`，state 49，7/7 |
| 22 | `acceptance_fixture_drift_attestation` | passed | `1e22712eba01`，state 55，8/8 |
| 23 | `readonly_attested_post_probe` | passed | `cda372ca23b0`，state 31，4/4 |
| 24 | `runtime_tool_approval_write_probe` | skipped | 未授权 Base 写探针 |
| 25 | `sequential_tool_approval_write_probe` | skipped | 未授权连续 Base 写探针 |
| 26 | `vendor_policy_inline_delegation` | passed | `6784c0c294c2`，state 44，5/5 |
| 27 | `deterministic_parallel_evidence_review` | passed | `56fcd9c05d87`，state 86，14/14 |
| 28 | `deterministic_race_policy_review` | passed | `20772f753159`，state 38，6/6 |
| 29 | `invoice_approval_routing_preview` | passed | `6ab4599181cd`，state 77，11/11 |

## Assistant `/api/chat`

| Case | fresh 状态 | 机器证据 |
|---|---|---|
| 01 | `validated` | `e692057b4725`，state 80，13/13 |
| 12 | `validated` | `40f2a81b924d`，state 31，4/4 |
| 13 | `validated` | `407d91ac66c1`，state 82，12/12 |
| 14 | `validated` | `dc16b9bf8c5c`，state 28，3/3 |
| 15 | `chat-failed` | 单次定向重试仍为 `STREAM_FAILURE`；`chatCompleted=false`，未搜索、未 mount、未启动 workflow |

Case 06 因副作用边界未通过 Assistant 运行。Cases 12-14 的 Assistant 最终文案可能停在 Running/Awaiting，但 committed typed artifact 完整，因此仍按 `validated`；模型文案不参与成功判定。

## Admission、Ornn 与 Risk

Admission 33-36 全部取得预期的 fail-closed/正负例证据，且无外部写入：Case 33 为 `INVALID_PROVISION_WORKFLOW_REQUEST` / `NYXID_OPERATION_SELECTION_REQUIRED`；Case 34 的 slot value 正例到达 provider，templated selector 与 slot escape 两条负例分别被拒绝；Case 35 拒绝 n8n root；Case 36 为 `INVALID_USER_WORKFLOW_REQUEST` / `DURABLE_AUTHORIZATION_UNAVAILABLE`。

Ornn 29/29 存在、公开、服务端格式有效且名称精确，但版本仅 28/29 一致。唯一漂移是 `supplier-risk-tier-aggregation`：local `1.1`、public `1.0`。`publish_skills.rb --verify-only` 与独立 public catalog 验证均以 exit 1 忠实暴露该漂移；本轮没有上传或权限变更。

按 fresh 观测派生的 risk 状态为 15 passed、1 failed、4 not-configured、1 skipped-expired。Risk 27 因上述 Ornn 版本漂移判定 failed；这不会反向修改历史机器摘要。

## 源迁移连续性回归（#3290）

| 时间（SGT） | 路径 | 观测 | 当前判定 |
|---|---|---|---|
| 14:04:06 | P2，同一 member/binding/definition | 6/10 failed；返回 `workflow run is already active`，同时 read model 中没有 active run | actor/run state 不一致的早期信号 |
| 14:09:19 | P2，同一 member/binding/definition | 14/14 committed completed；数字与现行系统复算一致 | 业务定义和输入曾真实可用 |
| 14:18:27 | P2，同一 member/binding/definition | 7/8 failed；`code_execute` -> `NYXID_PROXY_HTTP_502` | runtime tool leg 回归 |
| 14:20-14:42 | P2，byte-identical preview request | 连续 5 次 `NYXID_ADMISSION_SOURCE_CREDENTIAL_REQUIRED` | admission 当前阻塞 |
| 14:30 | P1，既有 27 步 binding | 第 1/27 步 `Forwarding failed`，0 个 workflow 步骤完成 | actor dispatch 当前阻塞 |

对照只证明故障边界：同一时段 sandbox 直经 NyxID 返回 HTTP 200，NyxID proxy、caller `whoami`、token 和 Aevatar read plane 正常；这些结果都不能代替 Aevatar admission/runtime/actor continuity。14:55 的只读集群检查显示当前 `eead35c0` 为 1/1 Ready、0 restart，但唯一 Pod 于 14:28:33 才启动，近 90 分钟 stdout 仅 10 行且相关关键词 0 命中，无法覆盖 14:03-14:20 的旧 pod/silo 窗口，所以 **cluster silo stability 仍未证明**。

现有 case 覆盖不足：Risk 28 只证明过一次 exact P1 v5 `submit=false` 14/14；Risk 29 尚未配置 P2 四表合成环境；Risk 40 与 Risk 41 约束副作用目标，但都不验证成功后重绑、member 变化、rollout 或 silo relocation 的时间连续性。下一条连续性 case 至少需要钉住同一 exact source definition 在切换前后两次 preview + run、source-readable credential 与 delegation credential 分离可解析、P2 14/14 复算、P1 首步 forwarding 与 27 步进展，以及脱敏的 deployment/silo transition 证据。本轮只记录缺口，不新增或执行该 case。

## Lark Channel 与文件入口

| Case | fresh 状态 | 证据 |
|---|---|---|
| Channel 20 | passed | mount approval 1 次、workflow runtime approval 1 次；唯一新增 run `90c8950beb0b` committed 3/3，artifact 命中 |
| Channel 21 | passed | mount 卡拒绝 1 次，Bot typed `Denied`；workflow start=0，run delta=0 |
| Channel 22 | `start-blocked` | `aevatar_start_workflow` typed failed，`InvalidWorkflowYaml`；run delta=0 |

Case 20 当前真实路径包含两层 approval，不能压缩成历史“单卡批准”。Case 22 没有 committed run，不能沿用历史 passed。

Case 19 的独立 Lark 文件 canary 通过：114-byte 合成 fixture 经 Lark 后 committed descriptor/extraction 为 113 bytes；唯一新增 run `73e35855ed43` 为 state 32、4/4 completed。artifact 精确命中 `lark_bot_ingress_validated=true`、文件名/正文/SHA、脱敏和 `side_effects=false`，并观察到 Bot final reply relay。

Regression R01 发送 1 次 `/init`，只出现 1 条授权更新回复且无重复，未打开 OAuth 链接。Ready workload 为 1/1、0 restart；有界日志 10 行，无 warning/error，`Activation access violation` 与 `CommittedStatePublicationException` 均为 0。日志没有可关联的 inbound 明细，因此只证明 UI transport 与禁止签名未出现，不声称日志级 inbound correlation。

## 边界与未执行项

- Cases 06、24、25 本轮没有获得副作用授权，fresh 状态是 `skipped`，不是 failed，也不是 passed。
- 本轮没有创建 schedule；既有 schedule E2E 继续作为历史证据，未提升为本轮 fresh 证据。
- 本报告没有保存 run、actor、message、approval、callback 或用户身份原值；只保留 12 位哈希、稳定错误码和机器断言。
- 本报告的全量窗口结束后，production deployment 或单案例复验可能继续前进。后续证据必须按自己的时间戳和 committed terminal 单独记录。
