# Aevatar 工作流验收案例

[![验证工作流](https://github.com/eanz17/aevatar-workflow-acceptance-cases/actions/workflows/validate.yml/badge.svg)](https://github.com/eanz17/aevatar-workflow-acceptance-cases/actions/workflows/validate.yml)

本仓库包含 11 个可公开的 Aevatar 工作流案例。它们使用与私有验收套件相同的工作流基础能力和 Lark 集成形态，但采用不同且有实际意义的业务场景；其中第 11 个案例专门验证 `codex_exec` 的 managed sandbox 全链路。

已提交的 YAML 使用占位符，不包含组织专属的 Base、用户、审批或 NyxID 资源标识。它们是模板，执行生产 preview 或真实运行前，必须先替换成自己的 Lark 与 NyxID 资源。

仓库的人类可读内容使用中文。工作流 `name`、步骤 `id`、工具名、API/JSON 字段、Base 列名、状态枚举、错误码和固定探针等技术契约保留英文，以确保定义可以稳定执行。

## 验证结论

验证日期：2026-08-04。

- 11/11 个 YAML 均通过本地解析、步骤图、安全和固定契约检查；
- 11/11 个已配置定义均通过 Aevatar 主网 `interactive` explicit-request preview；
- 11/11 个工作流均真实运行至 `completed`，并取得 committed read model 终态；
- 05-10 的写路径均在 typed tool approval 后执行，分别验证 Base POST、Lark 审批创建/回读、文本私信和 interactive card；
- 01-10 已移除生产未授权的通用 `code_execute`，11 只调用一次固定、无副作用的 managed `codex_exec`；
- 14 个配置占位符均有声明，公开仓库不包含组织专属资源标识。

`interactive` preview 只证明解析与能力准入，不证明运行成功。本仓库的“通过”以 typed receipt、run ID、业务断言和 committed terminal evidence 为准。逐案例脱敏证据见 `validation/production-validation-2026-08-04.json`，对比分析见 `report/index.html`。

## 工作流矩阵

| # | 工作流 | 步骤数 | 主要能力 | 生产验证 | 已执行副作用 |
|---:|---|---:|---|---|---|
| 01 | `release_readiness_review` | 13 | `assign`、JSON 解析/提取、双分支、并行 `foreach`、确定性转换 | committed 通过，`ready_for_review=true` | 无 |
| 02 | `candidate_document_compliance_preview` | 3 | 类型化文件输入、并行 `document_extract`、隐私约束 LLM | committed 通过，五类材料均为 true | 无 |
| 03 | `email_access_approval_audit` | 5 | 审批列表 GET、ID 提取、动态 `foreach -> detail GET` | committed 通过，审批详情可达 | 无 |
| 04 | `saas_license_utilization_review` | 10 | 六路 Base 汇聚、确定性利用率与成本聚合 | committed 通过，合计值全部命中 | 无 |
| 05 | `asset_inventory_attestation` | 7 | 输入标准化、preview/submit 分支、受保护的 Base POST | committed 通过，`accepted=true` | 新增一条验收 Base 记录 |
| 06 | `project_shared_mailbox_approval` | 8 | Base GET、审批 payload、受保护的审批 POST、实例验证 GET | committed 通过，回读为 `PENDING` | 创建一条验收审批 |
| 07 | `quarterly_access_review_reminder` | 7 | preview/submit 分支、受保护的 Lark 私信 POST | committed 通过，`message_sent=true` | 发送一条验收私信 |
| 08 | `saas_license_optimization_digest` | 19 | 六路 Base 读取、逐源标准化、摘要汇聚、预览/确认发送 | committed 通过，六源汇总和卡片发送成功 | 发送一条验收卡片 |
| 09 | `contractor_access_package_approval` | 25 | 附件、LLM 分类、身份查询、审批历史、稳定键去重、预览/提交/验证 | 创建/回读与幂等复跑均通过 | 诊断期间创建两条同键 `PENDING` 验收审批 |
| 10 | `monthly_access_certification` | 23 | 运行期账期、月末门禁、Base 聚合、审批验证、提醒与完成通知 | 月末、跳过、提醒预览和提醒发送均通过 | 创建一条验收审批并发送两条验收私信 |
| 11 | `complex_codex_exec_validation` | 32 | 固定 managed probe、五项精确 gate、receipt 恢复、并行证据归一化、多失败分支、终态汇总 | committed 通过，`parallel_check_count=5` | 无 |

## 各流程证据

### 01 发布就绪审查

通过确定性基础能力检查备份、监控和回滚控制，覆盖显式分支汇合和三项并行 `foreach`。真实运行终态为 `completed`，`ready_for_review=true`。

### 02 候选人材料合规预览

使用 `fixtures/candidate-profile-sample.txt` 作为合成类型化附件。流程完成文件提取和隐私约束 LLM 判断，五类材料字段均为 true。

### 03 邮箱访问审批审计

列出一个审批实例、提取 ID，再通过动态 `foreach` 获取详情。两个只读 GET 已真实执行，`instance_reachable=true`。

### 04 SaaS 许可证利用率审查

读取四个 Base 表、表目录和一个视图，然后计算席位利用率、月成本和缩减候选。真实结果命中 185 个席位、140 个活跃用户、每月 6,670 美元和一个缩减候选。

### 05 资产盘点确认

默认输入为 `{"submit":false}`，只有显式传入 `submit=true` 才会到达 Base POST。写分支经 typed approval 后执行，结果为 `mutation_executed=true`、`accepted=true`。

### 06 项目共享邮箱审批

读取一条已就绪的 Base 申请，构造邮箱访问审批，在 typed approval 后创建实例并读取同一实例验证，回读状态为 `PENDING`。

### 07 季度访问审查提醒

默认只预览，只有显式传入 `submit=true` 才发送 Lark 私信。写分支已真实运行，`message_sent=true`。

### 08 SaaS 许可证优化摘要

读取并标准化六个 Base 数据源，构造摘要后选择预览，或在显式确认后发送 Lark 卡片。六源汇总与 interactive card 均真实通过；durable preview 仍返回 `DURABLE_AUTHORIZATION_UNAVAILABLE`，不能宣称定时发送可用。

### 09 外包人员访问资料审批

组合类型化附件、`document_extract`、LLM 分类、Base 身份解析、审批列表/详情读取、稳定申请键去重、预览、受保护创建和验证。创建与回读通过，修复版复跑返回 `possible_duplicate=true`、`approval_created=false`、`idempotent_skip=true`。诊断旧时间窗口时创建了两条同键 `PENDING` 验收审批，未擅自删除。由于 Bot 缺少 `contact:user.id:readonly`，身份解析使用 Base 目录，这不等于 contact API 已通过。

### 10 月度访问认证

解析模式、日期和账期；仅允许在真实月末进入 submit；聚合月度 Base 记录；支持预览、审批创建/验证、提醒和完成通知。月末审批、实例回读和完成私信通过；非月末跳过、提醒预览、提醒发送也分别通过。durable preview 返回 `NYXID_EXPLICIT_REQUEST_INTERACTIVE_REQUIRED`，所以 schedule 仍未验证。

### 11 复杂 `codex_exec` 验证

流程先校验内部探针路由，再执行一次固定的 operator-managed `codex_exec`。随后只使用 workflow 原语，在各 gate 间显式恢复原始 receipt，对 `status`、`target`、`output`、`exit_code`、`diagnostic_id` 依次做精确判断，并行归一化五项证据名称，经多条失败分支生成机器可判定终态。固定 prompt `Reply with exactly CODEX_EXEC_READY` 是官方技术契约，不能翻译或改写。

本地验证只证明 payload 与步骤图正确。真实成功还必须同时看到：`status=succeeded`、`target=managed_sandbox`、裁剪后的 `output=CODEX_EXEC_READY`、`exit_code=0` 和非空脱敏 `diagnostic_id`。

`foreach` 会用四行 `---` 连接五个并行结果，因此后处理对序列化文本断言 9 个物理行；业务结果仍必须报告 `parallel_check_count=5`。这项断言用于同时证明五个并行子步骤全部完成且汇总格式符合当前运行时契约。

#### 真实运行证据

2026-08-04 通过已认证的 `nyxid proxy request aevatar` 链路完成验证：

- preview：`workflowId=wf-complex-codex-exec-validation-20260804-v4`，`revisionId=rev-complex-codex-exec-validation-20260804-v4`，`callSiteCount=0`；
- 运行标识：`runId=workflow.definition:<已脱敏>:run:f9cac8b1…`，`commandId=fabb3e9d…`；
- `codex_exec` receipt：`status=succeeded`、`target=managed_sandbox`、`output=CODEX_EXEC_READY`、`exit_code=0`，`diagnostic_id` 非空且未写入仓库；
- 工作流终态：`success=true`，五项 checks 全为 true，`parallel_check_count=5`，`side_effects=false`；
- committed read model：`projectionCompletionStatus=WORKFLOW_PROJECTION_COMPLETION_STATUS_PAYLOAD_COMPLETED`、`projectionCompleted=true`、`stateVersion=178`。

初次 canary 暴露了 `foreach` 汇总包含分隔行的真实运行时格式，旧断言把 5 个结果和 4 个分隔符误计为异常。修复为 9 个物理行后重新 preview 并真实运行，上述同一条 run 已从固定探针推进到 committed 成功终态。

## 配置

将 `config.example.yaml` 复制为已忽略的 `config.local.yaml`，替换全部值，然后生成已配置定义：

```bash
ruby scripts/materialize_workflows.rb config.local.yaml
```

输出目录默认为 `build/workflows/`。占位符覆盖：

- NyxID Lark `UserService` 标识；
- Base app token、六个 table ID 和共享邮箱记录 ID；
- 审批 definition code 及 textarea/link widget ID；
- 审批提交人和消息接收人的 Lark user ID。

Base 字段与记录契约记录在 `fixtures/base-records.example.yaml`。案例 04 会明确断言六个表、一个 SaaS 视图以及三行样例的合计值。

## 本地验证

运行公开模板校验器：

```bash
ruby scripts/validate_workflows.rb
ruby scripts/validate_report.rb
```

第一个校验器还会确认案例 11 恰好调用一次 `codex_exec`，外层超时固定为 360 秒，完整 payload 与固定 managed probe 相等，没有调用方可控制的路由或凭据字段；同时保护五项并行检查、9 行序列化汇总和 `parallel_check_count=5` 的成功终态契约。第二个校验器保护 workflow、README、脱敏生产摘要和分析页之间的案例编号、步骤数与矩阵数量一致性。

## 生产验证

生产能力 preview 只能通过已认证的 NyxID CLI，将已配置 YAML 作为 stdin JSON 提交到：

```text
nyxid proxy request aevatar \
  /api/scopes/{scopeId}/workflows:explicit-request-preview \
  --method POST \
  --header Content-Type:application/json \
  --data - \
  --output json
```

每次 preview 使用不同的 `workflowId` 与 `revisionId`。preview 绝不授权把 `202 Accepted`、等待工具审批或模型描述当作工作流完成。

`scripts/production_validate.rb` 提供可复现验证入口：默认只 preview；加 `--run` 才执行；写路径还必须同时提供 `--allow-side-effects` 与 `--approve`。`--prompt` 只能用于单个案例，可复测同一定义的其他分支。验证器会逐行处理 SSE，并在看到 typed pending receipt 时立即调用 resume，不等待流结束。

已脱敏的 preview 摘要位于 `validation/production-preview-2026-08-04.json`，真实运行摘要位于 `validation/production-validation-2026-08-04.json`。

## 安全边界

- 一律先 preview。写入分支需要明确的用户意图和平台工具授权。
- 平台工具授权不等于 Lark 业务审批；新建的审批通常仍处于 `PENDING`。
- 在 durable authorization 问题解决前，不得 schedule 工作流 08 或 10。
- `codex_exec` managed probe 不接受仓库、路径、镜像、模型、provider、sandbox flag 或凭据输入。
- 不得提交 `config.local.yaml`、token、凭据、租户标识、业务记录、审批表单内容或未脱敏运行证据。
- 只有拿到 typed receipt、run ID 与 committed terminal evidence，才能宣称真实运行通过。

新增和维护案例的完整规则见 `AGENTS.md`。

## 许可证

MIT。`LICENSE` 保留标准英文法律原文。
