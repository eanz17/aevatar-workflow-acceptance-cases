# Aevatar 工作流验收案例

[![验证工作流](https://github.com/eanz17/aevatar-workflow-acceptance-cases/actions/workflows/validate.yml/badge.svg)](https://github.com/eanz17/aevatar-workflow-acceptance-cases/actions/workflows/validate.yml)

本仓库包含 11 个可公开的 Aevatar 工作流案例。它们使用与私有验收套件相同的工作流基础能力和 Lark 集成形态，但采用不同且有实际意义的业务场景；其中第 11 个案例专门验证 `codex_exec` 的 managed sandbox 全链路。

已提交的 YAML 使用占位符，不包含组织专属的 Base、用户、审批或 NyxID 资源标识。它们是模板，执行生产 preview 或真实运行前，必须先替换成自己的 Lark 与 NyxID 资源。

仓库的人类可读内容使用中文。工作流 `name`、步骤 `id`、工具名、API/JSON 字段、Base 列名、状态枚举、错误码和固定探针等技术契约保留英文，以确保定义可以稳定执行。

## 验证状态

验证日期：2026-08-04。

- 11 个 YAML 文件均通过本地解析、步骤图和安全检查；
- 所有步骤 ID 唯一，每个 `next` 和 `switch` 分支目标都存在；
- 本地外部能力调用数与已记录的生产 preview 调用数一致；
- 14 个配置占位符均已声明，仓库中没有组织专属标识；
- 11 个已配置定义均通过 Aevatar 主网 `interactive` explicit-request preview；
- 第 11 个 `codex_exec` 案例的固定 payload 由本地校验器逐字段保护；
- 第 11 个案例已真实运行至成功终态，并完成 read model 投影；
- 本次仓库验证没有写入 Base、创建 Lark 审批、发送消息或创建 schedule。

`interactive` preview 只证明解析与能力准入，不证明运行成功。`codex_exec` 是否真实全链路通过，以“真实运行证据”一节记录的 typed receipt、run ID 和 committed terminal evidence 为准。

## 工作流矩阵

| # | 工作流 | 步骤数 | 主要能力 | 生产验证 | 已执行副作用 |
|---:|---|---:|---|---|---|
| 01 | `release_readiness_review` | 13 | `assign`、JSON 解析/提取、双分支、并行 `foreach`、确定性转换 | preview 通过，0 个外部调用 | 无 |
| 02 | `candidate_document_compliance_preview` | 3 | 类型化文件输入、并行 `document_extract`、隐私约束 LLM | preview 通过，0 个声明的外部调用 | 无 |
| 03 | `email_access_approval_audit` | 5 | 审批列表 GET、ID 提取、动态 `foreach -> detail GET` | preview 通过，2 个只读 GET | 无 |
| 04 | `saas_license_utilization_review` | 10 | 六路 Base 汇聚、确定性利用率与成本聚合 | preview 通过，6 个只读 GET | 无 |
| 05 | `asset_inventory_attestation` | 8 | 输入标准化、preview/submit 分支、受保护的 Base POST | preview 通过，1 个需授权的 POST | 无 |
| 06 | `project_shared_mailbox_approval` | 8 | Base GET、审批 payload、受保护的审批 POST、实例验证 GET | preview 通过，2 GET + 1 POST | 无 |
| 07 | `quarterly_access_review_reminder` | 8 | preview/submit 分支、受保护的 Lark 私信 POST | preview 通过，1 个需授权的 POST | 无 |
| 08 | `saas_license_optimization_digest` | 21 | 六路 Base 读取、逐源标准化、摘要汇聚、预览/确认发送 | interactive preview 通过；durable 被拒绝 | 无 |
| 09 | `contractor_access_package_approval` | 23 | 附件、LLM 分类、身份查询、审批历史、稳定键去重、预览/提交/验证 | preview 通过，4 GET + 1 POST | 无 |
| 10 | `monthly_access_certification` | 28 | 运行期账期、月末门禁、Base 聚合、审批验证、提醒与完成通知 | interactive preview 通过；durable 被拒绝 | 无 |
| 11 | `complex_codex_exec_validation` | 32 | 固定 managed probe、五项精确 gate、receipt 恢复、并行证据归一化、多失败分支、终态汇总 | preview 与真实 committed run 均通过 | 无 |

## 各流程证据

### 01 发布就绪审查

通过确定性基础能力检查备份、监控和回滚控制，覆盖显式分支汇合和三项并行 `foreach`。本地 YAML/图校验通过，生产 preview 未发现外部能力调用点。

### 02 候选人材料合规预览

需要一个类型化附件，例如 `fixtures/candidate-profile-sample.txt`。流程提取文件，并让 LLM 返回五项布尔完整性判断，不复述个人数据。本地校验通过；生产 preview 未发现声明的 NyxID 外部调用点。本仓库验证没有执行附件输入和 LLM 运行。

### 03 邮箱访问审批审计

列出一个审批实例、提取 ID，再通过动态 `foreach` 获取详情。本地校验通过；生产 preview 接纳两个只读 GET 调用点。本次没有执行真实 GET。

### 04 SaaS 许可证利用率审查

读取四个 Base 表、表目录和一个视图，然后计算席位利用率、月成本和缩减候选。fixture 约定 185 个席位、140 个活跃用户、每月 6,670 美元成本和一个缩减候选。本地校验通过；生产 preview 接纳六个只读 GET 调用点。本次没有执行真实 GET。

### 05 资产盘点确认

默认输入为 `{"submit":false}`，只有显式传入 `submit=true` 才会到达 Base POST。本地校验通过；生产 preview 识别出一个需要授权的 POST 调用点。没有执行 POST 分支。

### 06 项目共享邮箱审批

读取一条已就绪的 Base 申请，构造邮箱访问审批，在工具授权后创建实例并读取同一实例进行验证。本地校验通过；生产 preview 接纳两个只读 GET 和一个需要授权的 POST 调用点。没有创建审批。

### 07 季度访问审查提醒

默认只预览，只有显式传入 `submit=true` 才发送一条 Lark 私信。本地校验通过；生产 preview 识别出一个需要授权的 POST 调用点。没有发送消息。

### 08 SaaS 许可证优化摘要

读取并标准化六个 Base 数据源，构造摘要后选择预览，或在显式确认后发送 Lark 卡片。本地校验和 production interactive preview 通过，包含六个只读 GET 和一个 POST 调用点。durable preview 返回 `DURABLE_AUTHORIZATION_UNAVAILABLE`，因此不能宣称定时发送能力可用。

### 09 外包人员访问资料审批

组合类型化附件、`document_extract`、LLM 分类、Base 身份解析、审批列表/详情读取、稳定申请键去重、预览、受保护创建和验证。本地校验通过；生产 preview 接纳四个只读 GET 和一个 POST 调用点。由于验收 bot 缺少 `contact:user.id:readonly`，案例有意改为 Base 身份目录查询。没有创建审批。

### 10 月度访问认证

解析模式、日期和账期；仅允许在真实月末进入 submit；聚合月度 Base 记录；支持预览、审批创建/验证、提醒和完成通知。本地校验和 production interactive preview 通过，包含两个只读 GET 和三个 POST 调用点。durable preview 返回 `NYXID_EXPLICIT_REQUEST_INTERACTIVE_REQUIRED`，因此自动月末审批和 27 日提醒 schedule 均未验证。

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
```

它还会确认案例 11 恰好调用一次 `codex_exec`，外层超时固定为 360 秒，完整 payload 与固定 managed probe 相等，没有调用方可控制的路由或凭据字段；同时保护五项并行检查、9 行序列化汇总和 `parallel_check_count=5` 的成功终态契约。

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

已脱敏的机器可读摘要位于 `validation/production-preview-2026-08-04.json`。

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
