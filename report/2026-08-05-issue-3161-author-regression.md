# #3161 作者历史 issue 的 workflow 回归

验证日期：2026-08-05。目标仓库为 [`aevatarAI/aevatar`](https://github.com/aevatarAI/aevatar)，锚点为 [`#3161`](https://github.com/aevatarAI/aevatar/issues/3161)。按“同一作者 `jianwei-su`、同一仓库、创建时间早于 #3161、只统计 issue 不含 PR”查询，共得到 11 条。

本轮没有新增 workflow。未覆盖点集中在 Lark channel ingress/回传、channel-bound private Ornn authority 和 durable scheduler actor 生命周期；这些边界不能通过复制一个业务 YAML 得到有效证明。现有 Case 13、15、16 已覆盖可由 workflow 内部证明的三条主线，因此复用并重新执行。

## 新鲜生产证据

统一使用 `scripts/production_validate.rb --cases 13,15,16 --run --timeout 420`，所有请求经 `nyxid proxy request aevatar`；没有批准、消息、审批、Base 写入或 schedule 写入。

| Case | 终态 | 步骤 | 机器断言 | 脱敏 run hash |
|---:|---|---:|---|---|
| 13 | committed `completed` | 12/12 | typed PDF、`document_extract`、SGD/金额/日期/发票号与历史去重全部命中 | `b0684497103a` |
| 15 | committed `completed` | 11/11 | 六路 Base GET；周度 2340/2400、月度 9360/9600、over/watch 计数命中 | `da7f37628c6a` |
| 16 | committed `completed` | 4/4 | 首个 Base GET 输出非空，`provider_response_verified=true`、`side_effects=false` | `43de689e301c` |

上述最小案例之后，镜像 `71a38ff5` 又对源 P2 no-send 定义完成 exact YAML preview、fresh binding/contract 核对和单次真实 invoke。Preview 为 6 个唯一 read-only GET、无需 approval；run catalog 只增加 1，终态 `completed`、`lastSuccess=true`、8/8 步成功，首个 Base 输出和 final output 均非空，audit 无 auth、authority、receipt、readiness、admission 或重复启动错误。该证据补齐了 #3161 的真实 published-operation authority 主链；未发送消息，也未创建 schedule。

## 历史 issue 映射

| Issue | 当前状态 | 现有案例 | 本轮结论 | 严格边界 |
|---|---|---|---|---|
| [`#2411`](https://github.com/aevatarAI/aevatar/issues/2411) schedule run 缺 NyxID 凭证 | closed | 15 | 部分覆盖 | Case 15 证明 run 内 NyxID 调用正常；没有 durable schedule receipt，不能证明 schedule fire 凭证透传 |
| [`#2412`](https://github.com/aevatarAI/aevatar/issues/2412) Lark attachment / 回复截断 | closed | 13 | 部分覆盖 | workflow typed file 接收端通过；未发送 Lark 消息，未独立证明 relay ingress 或完整回复投递 |
| [`#2447`](https://github.com/aevatarAI/aevatar/issues/2447) Lark 上传文件无法进入 workflow | closed | 13 | 部分覆盖 | 合成 PDF 经 `input_file_refs -> document_extract` 通过；直接 typed input 不等于 file-card/recent attachment drain |
| [`#2944`](https://github.com/aevatarAI/aevatar/issues/2944) external capability authoring/admission 迁移 | closed | 13、15、16 | 语义替换覆盖 | 三个当前 `capability.nyxid_request` 定义 preview、既有绑定与真实运行均通过；不重放 legacy proof/direct typed-tool authoring |
| [`#2958`](https://github.com/aevatarAI/aevatar/issues/2958) 存量 schedule actor 停摆 | closed | 15 | 生产阻塞 | 旧 schedule 证据为 HTTP 502 且无 receipt；`0c4ff023` 不包含当前 actor-owned provisioning 补丁，仍不能证明 fire/自愈 |
| [`#2999`](https://github.com/aevatarAI/aevatar/issues/2999) binding registry 冻结 | closed | 13、15、16 | 当前正向对照通过 | 三个复用既有 revision 的 member 均 invocation ready 并完成；报告方已将旧维护窗口状态定为当前不可复现 |
| [`#3000`](https://github.com/aevatarAI/aevatar/issues/3000) PUT target 后 schedule actor 孤儿化 | open | 15 | 未运行 | 精确回归要求创建 schedule 后修改 target；最新部署未获准创建或修改 durable schedule，不能从代码部署外推行为成功 |
| [`#3001`](https://github.com/aevatarAI/aevatar/issues/3001) scheduled dispatch 无法 provision definition actor | closed | 15 | 未运行 | 直接 invoke 通过不等于 scheduled dispatch；缺少最新部署的 schedule fire 终态证据 |
| [`#3061`](https://github.com/aevatarAI/aevatar/issues/3061) channel `aevatar_invoke_team` activation violation | closed | 无 | 未独立回归 | issue 报告方曾用真实 bot run 验证后关闭；member 直调或 `/api/chat` 不经过 channel background-delivery reservation 链 |
| [`#3086`](https://github.com/aevatarAI/aevatar/issues/3086) channel 无法填充 typed `file_ref` | open | 13 | 部分覆盖 | workflow 接收端已通过；仍缺真实 Lark image/PDF 自动传播到 invocation 的 E2E |
| [`#3087`](https://github.com/aevatarAI/aevatar/issues/3087) private Ornn skill 在 channel 中不可见 | open | 13 | 部分覆盖 | 现有 `/api/chat` public Ornn 核心链已通过；不证明 channel-bound private authority 与 `ornn_search_skills` receipt |

## 结论

可由现有 workflow 严格证明的接收端、external capability 当前契约、NyxID runtime/receipt 和正常 member serving 路径均为绿色，因此不新增重复案例。剩余证据不是 YAML 缺口：

1. `#2411`、`#2958`、`#3000`、`#3001` 需要 durable schedule 创建 receipt、run-now/fire 和 committed run；旧证据为 HTTP 502，当前 actor-owned provisioning 仍是本地未提交补丁，不能写成已部署或已复测。
2. `#2412`、`#2447`、`#3061`、`#3086`、`#3087` 需要获准发送真实 Lark image/PDF/command canary，观察 channel ingress、tool bridge、private Ornn authority 和 Lark 回传。
3. `#3000` 还要求 PUT 修改 schedule target，必须使用专门创建、可清理的 canary schedule，不能牺牲现有健康排程。

锚点 #3161 现在已有两层证据：Case 16 对共同 provider receipt/runtime 平面为绿色，源 P2 no-send 又对 published-operation authority 主链取得 8/8 committed completion。该结论只覆盖 no-send 只读执行，不能外推到消息发送或 durable schedule。

机器可读摘要见 [`validation/issue-3161-author-regression-2026-08-05.json`](../validation/issue-3161-author-regression-2026-08-05.json)。
