# REQ-2026-001 后端根路径默认跳转 Swagger

| 项 | 值 |
|---|---|
| 提出人 | 用户 |
| 提出日期 | 2026-10-02 |
| 优先级 | P2 |
| 状态 | 开发中 |
| 关联 ADR | ADR-0027（消费树 ⊆ BASE subset invariant，本需求据以不登记功能树，见 §4） |

## 1. 需求描述

**用户原话（照抄）**：

> 所有后端增加一个，后端域名访问默认跳到swagger页面

**我的理解**：

本仓（saas-identity-platform 家族 4 后端之一，Rails 8.1 API 栈）在根路径增加浏览器友好默认入口：
匿名访问后端域名根路径时跳转到本仓 Swagger UI，方便 QA 联调与契约复核从域名直达 API 文档。
经澄清（见澄清记录）：

1. 范围 = 两家族全部 8 个后端仓，本文件是本仓一仓的落点；
2. 本仓 Swagger UI 现状：**没有**。Gemfile 无任何 swagger/rswag gem，路由只有 `/health`
   与 `/api/*`（API 面由 shared emit 的 api_manifest.json 驱动），需先补 UI 承载方案才有页面可跳；
3. 跳转全环境生效（dev/test/prod 同姿态，与 aspnetcore 仓「prod 暂全开」的家族现状一致）；
4. 不进契约面、不同步 contract-test 仓（与 /health 同类基础设施端点）；
5. 不登记功能树（架构约束见 §4）。

### 澄清记录

| 疑问 | 澄清结论 | 澄清人 | 日期 |
|---|---|---|---|
| 「所有后端」范围？suite 有两家族 × 4 栈共 8 仓 | 两家族全部 8 仓都做 | 用户 | 2026-10-02 |
| 本仓没有 Swagger 页可跳怎么办（缺页仓：lab-springboot / 双 rails） | 一并补齐 Swagger UI 再挂跳转，字面义完整实现 | 用户 | 2026-10-02 |
| 跳转在哪些环境生效 | 所有环境统一跳（与现状 Swagger 全环境暴露一致） | 用户 | 2026-10-02 |
| 是否按硬规则同步 contract-test 仓 | 不同步：不在 .tsp 契约面内，与 /health 同类（/health 从未进 CT 断言） | 用户 | 2026-10-02 |
| 工作流要求「新增功能先登记功能树」，本需求如何登记？ | 不登记。基础设施端点进树违反 ADR-0027 subset invariant（消费树必须 ⊆ BASE，extra 即红），BASE 侧「仅后端」交付行又会让前端树违反交付列收口；先例：infra 专属模块段（原 97/98 号段）已全家族退役出树，/health 从未进树。架构判定，随文档送用户追认 | Claude | 2026-10-02 |

## 2. 验收标准

| 编号 | 场景（给定） | 操作（当） | 预期（则） |
|---|---|---|---|
| AC-1 | 后端进程已启动 | 匿名 GET 根路径 `/` | 302 跳转到 UI 承载路径（候选 `/api-docs`），跟随跳转后 Swagger UI 200 可渲染 |
| AC-2 | 任意环境（dev/test/prod 同姿态） | 重复 AC-1 | 行为一致；带不带 Authorization 行为一致 |
| AC-3 | 既有面回归 | 访问任意 `/api/v1/*` 契约端点与 `/health` | 行为与改动前完全一致（跳转只占根路径）；route_parity_test 继续绿（根路由不在 api_manifest 对账面） |
| AC-4 | Swagger UI 本身可用 | 匿名打开 UI 路径 | 渲染出契约端点列表（数据源 = shared emit 的 openapi.yaml 或其派生物） |
| AC-5 | 门禁 | 跑本仓 L1-L4 | 全绿；contract-test 仓 gate 回归不受影响 |

## 3. 任务拆解

| 任务 ID | 任务描述 | 类型 | 负责人 | 预估 | 状态 |
|---|---|---|---|---|---|
| T-1 | 引入 Swagger UI 承载方案：候选 a) rswag-ui 挂 `/api-docs`（注意拖入 rspec 依赖链，本仓测试栈是 minitest）；b) 自托管 swagger-ui dist 静态资产 + 指向 shared emit 的 openapi.yaml（实现期裁，倾向 b 轻依赖） | 开发 | claude | S | 已完成（2026-10-02，选 b：swagger-ui-dist 5.33.1 离线 vendor 到 `public/api-docs/`（10 文件含 LICENSE.txt，零 CDN 依赖，minitest 栈零 gem 引入）；`index.html` 手写入口 `SwaggerUIBundle({url:'openapi.json'})`；`scripts/gen-shared.sh` step 3 用 ruby yaml→json 生成 `public/api-docs/openapi.json`，servers 改写同源空串（shared 占位符 api.example.com → try-it-out 打本域），SSOT 注释「契约变更后重跑本脚本勿手改」） |
| T-2 | 根路径跳转：`root to: redirect('/api-docs')` 或等价（匿名；route_parity_test 只对账 api_manifest 的 `/api/v1/*` 面，根路由不进对账） | 开发 | claude | XS | 已完成（2026-10-02，red→green：routes.rb 增 `root to: redirect('/api-docs/index.html', status: 302)` + `get '/api-docs'` 同款 302；redirect 路由无 controller#action defaults，route_parity_test 的 defaults.blank? 过滤天然不对账（随 L2 全绿实证）；`test/integration/root_swagger_redirect_test.rb` 3 断言（GET / 302 → /api-docs/index.html、UI 页 200 含 swagger-ui-bundle.js、openapi.json 200 可解析且 paths 非空），不挂 fn ID） |
| T-3 | L1-L4 门禁回归 + curl 三验（302、跟随 200、/api/v1/* 不回归） | 门禁 | claude | XS | 已完成（2026-10-02，**末版代码后**全量 gate 实测 21:58–22:01（suite 根 `.state/gate-saas-rails-1002-2258.log`）：L0–L5 全 PASS 门禁全绿，gate.json passed=true checked_at 22:01:07，L4 32 runs / 232 assertions / 0 failures；新增 root_swagger_redirect_test 3 runs / 9 assertions 单文件复跑实证 0 failures；route_parity/schema_parity 随套件全绿——契约面零回归。早期 16:15 判定早于末版改动落盘，已按「证据必须晚于末版代码」纪律作废重测） |

## 4. 功能影响（需求与功能对齐的唯一位置）

**无 —— 本需求不登记功能树（影响功能数 0）。**

定性：根路径跳转与 Swagger UI 暴露是**基础设施端点**，不是产品功能面。三重依据：

1. **ADR-0027 subset invariant**：消费仓功能树必须 ⊆ shared BASE，BASE 外 M/F/I 即门禁红，
   vertical_extra 白名单已按 ADR-0027 终态全家族归零；BASE 外 ID 必须先 tree-change 进 BASE。
2. **BASE 侧也不可进**：BASE 行按 ADR-0024 §3 全家族照抄，「仅后端」交付行会让前端树
   违反前端树交付列收口（前端树只准 仅前端/前端+后端）。后端专属基础设施在 BASE 无合法挂位。
3. **先例**：infra 专属模块段（原 97/98 号段）已全家族退役出树，/health 从未进树。
   本需求与 /health 同类，同待遇。

功能影响表因此为空——没有 ID 即无悬空引用，不违反「ID 必须存在于功能树」。

## 5. 流程影响

无。

## 6. 风险与回滚

| 风险 | 影响面 | 缓解 | 回滚方式 |
|---|---|---|---|
| rswag-ui 拖入 rspec 依赖链（本仓 minitest） | 依赖膨胀/测试栈混杂 | 倾向自托管 dist（T-1 候选 b）；brakeman L2 对新增静态资产回归 | revert gem/资产 commit |
| dist 资产离线可用性 | UI 打不开 | 资产随仓 vendor，不引 CDN | revert |
| prod 暴露面认知：裸域名直达 API 文档 | 安全姿态认知 | 家族现状「prod 暂全开」，本需求不改变暴露姿态；后续 prod 收口时跳转随 UI gating 同步收口 | revert 跳由 commit，恢复 404 现状 |

无数据面、无契约面变更。
