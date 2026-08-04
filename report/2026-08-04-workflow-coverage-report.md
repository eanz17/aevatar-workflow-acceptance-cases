# 工作流验证与能力覆盖报告

报告日期：2026-08-04。

## 路径口径

用户提到的 `~/Code/workflows` 当前不存在。本报告实际比较：

- 新仓库：`/Users/chronoai/Code/aevatar-workflow-acceptance-cases`；
- 源目录：`/Users/chronoai/workflows`。

源目录共有 43 个可解析工作流定义，但不能按文件数直接计算覆盖率。其中 20 个是本批十个验收案例及其 Ornn 资产的旧副本，另外 23 个分属 Base 探针、原语探针、Lark Onboarding、发票审批、预算监控和月度考勤等版本族。

## 结论

- 新仓库 11/11 个工作流通过静态校验与 production explicit-request preview。
- 11/11 个工作流都有真实 committed 终态证据；05-10 的写路径通过 typed tool receipt 批准后执行。
- 01-10 不再依赖生产未授权的通用 `code_execute`；11 只保留一次固定、无副作用的 `codex_exec` managed sandbox 探针。
- 09 的创建、回读和稳定键幂等跳过均得到真实证据。修复前的错误时间窗口导致诊断期间创建了两条同键 `PENDING` 验收审批，未擅自删除。
- 10 的月末提交、非月末跳过、提醒预览和提醒发送四条路径均通过。

## 源版本族映射

| 源版本族 | 定义数 | 新仓库对应案例 | 重叠能力 | 尚未一一覆盖 |
|---|---:|---|---|---|
| Base 探针 | 3 | 04、05 | Base 多表 GET、表/视图 GET、受保护 POST、结果判定 | 原始旧资源本身不在公共仓库复测 |
| 原语与执行探针 | 5 | 01、03、11 | assign、transform、switch、foreach、动态 GET、managed `codex_exec` | 通用 `code_execute` 凭据探针未覆盖 |
| Lark Onboarding | 2 | 06 | Base 记录到审批创建、实例回读 | n8n webhook 与同步 webhook response 被交互式调用替代 |
| 发票审批 | 7 | 02、03、09 | 附件、文档提取、LLM、历史审批、去重、审批创建/验证 | 图片/PDF OCR、发票字段与金额规则、contact batch lookup |
| 预算监控 | 5 | 04、08 | 六源 Base、确定性聚合、阈值判断、卡片发送 | 原始预算类别/差异公式与每周 durable schedule |
| 月度考勤 | 1 | 10 | 月末门禁、月度聚合、审批、验证、完成与提醒消息 | n8n 每日 schedule trigger |
| 旧验收案例副本 | 10 | 01-10 | 新仓库是其修复、中文化和生产验证后的权威版本 | 源副本仍含过时 `code_execute` |
| Ornn 资产副本 | 10 | 无 | 资产内嵌工作流与旧验收案例相同 | 新仓库未打包或发布 Ornn skill，自然语言调用未在本仓库证明 |

## 已覆盖能力

新仓库已经真实覆盖：

- 工作流基础原语：`assign`、JSON 解析/提取、bounded template、`switch`、`conditional`、并行与动态 `foreach`；
- AI 与附件：文本附件输入、`document_extract`、受约束 `llm_call`；
- Base：记录 GET、多表汇聚、表目录、视图、记录 POST；
- Lark Approval：列表、详情、创建、实例回读、稳定键去重；
- Lark IM：文本私信与 interactive card；
- 安全与证据：NyxID 用户身份代理、typed tool approval/resume、committed read model 终态；
- 执行：preview/submit 门禁、2026 月末门禁、提醒分支、managed `codex_exec`。

## 语义替换

| 源能力 | 新仓库实现 | 判断 |
|---|---|---|
| n8n 内直接获取 Lark token | NyxID 绑定的 Lark UserService | 更安全的语义替换 |
| Lark contact batch lookup | Base 身份目录稳定键查询 | 权限受限下的显式替换，不等于 contact API 通过 |
| 任意 JavaScript 做解析和聚合 | bounded template、assign、switch、conditional | 业务功能覆盖，不等于任意代码执行能力覆盖 |
| 预算差异业务 | SaaS 许可证利用率与成本聚合 | 相同聚合/阈值原语，不是相同财务公式 |

## 未覆盖或阻塞

- n8n webhook listener 与 `respondToWebhook` 的同步 HTTP 契约；
- n8n schedule trigger，以及 Aevatar durable weekly/monthly schedule；
- 通用 `code_execute` 和凭据透传探针，生产返回 `NYXID_PROXY_UNAUTHORIZED`；
- 图片/PDF OCR 的媒体广度，当前公开 fixture 是合成文本；
- 发票专属字段、供应商归一化、金额/币种与发票号去重规则；
- Lark `contact/v3/users/batch_get_id` 精确调用，当前 Bot 缺少 `contact:user.id:readonly`；
- Ornn skill 打包、发布、搜索、加载，以及 Lark Bot 自然语言启动的类型化全链路。

`#3182` 关注的是工具失败后 Bot 仍可能用自然语言误报成功，不是 `code_execute` 授权错误本身。直接 workflow API 的 committed 成功不能被外推为 Lark Bot + Ornn 自然语言链路已经通过。

## 验证证据

逐案例的脱敏 production 证据位于 `validation/production-validation-2026-08-04.json`。可视化分析页面位于 `report/index.html`。
