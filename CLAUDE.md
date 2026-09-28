# CLAUDE.md — SaaS 身份认证平台 Rails 后端

> 书稿配套仓 + harness 门禁仓双身份。入口，不是手册。L0 门强制上限 60 行。
> 本仓为《（书稿信息待补）》案例（待补）（SaaS 身份认证平台 Rails 后端）的可运行配套工程，是书稿代码块的 **source of truth**。

## 1. 项目定位

SaaS 身份认证平台 Rails 后端（`saas-identity-platform-rails`，技术栈 `rails`）。一句话定位见 README.md。

## 2. 铁律

- **TDD**：每个模块先写失败测试 → 跑确认失败 → 实现 → 跑确认绿 → commit
- **版本钉死**：依赖与 `version-lock.json` 的 `version_lock` 一致；不引入 lock 外的库
- **tag 即放行**：全量回归绿后打 `v<MAJOR>.<MINOR>.<PATCH>-<YYYYMMDD>`（如 `v0.3.54-20260826`）
- **mock-friendly**：安装 + 测试必须在无 Key、无 Docker、无网下全绿
- **功能清单是锚点**：改 `docs/functions/function-tree.md` 走 `/tree-change` 提案，由人批准；
  改功能与改功能清单必须同一个 commit；废弃只改状态，编号永不复用；禁止给 skip 的测试挂功能 ID

- 禁止在 Controller 写业务逻辑（瘦控制器，逻辑进 service 对象）
- 禁止 rescue 后吞掉异常（必须记录或 rethrow）
- 禁止手改 lib/generated/**（API 面只认生成物，suite-hard-rules §4）
- 禁止新增 db/migrate（schema SSOT = shared 仓 drizzle，镜像 springboot 禁止 Flyway）
- 禁止把连接串/密钥硬编码进源码（一律 ENV.fetch，fail-fast 无默认值兜底）
- 保护路由禁止跳过 TenantGuard；业务身份字段缺失必须 401/403（suite-hard-rules §3）
- 种子归 shared 仓 seed-db.mjs 独占；本仓零种子、零 fixtures/*.yml

## 2.1 家族契约速查

- **端口**：SERVER_PORT=5106（puma.rb 读）；**DB**：saas_dev/saas_test/saas_prod 三库（§6.2），连接 = PG_* 五件套
- **JWT**：HS256，`Auth::JwtVerifier`（JWT_SIGNING_KEY/JWT_ISSUER/JWT_AUDIENCE/JWT_TTL_SECONDS）；CORS = SAAS_CORS_ALLOWED_ORIGINS
- **env**：三件套键集严格相等（L0.5）；`.env.test` 的 PG_DATABASE=saas_test、`.env.local` 本机 dev 真值（gitignored）——见 ARCHITECTURE.md §3
- **镜像义务**：端点/DTO 语义以 saas-springboot 为参照实现；改 API 面必须同步 contract-test 仓（同 commit，suite-hard-rules §2）

## 3. 技术栈与版本（钉死于 version-lock.json）

Ruby 3.4 + Rails 8 API-mode + Minitest + RuboCop 1.60+（无 L3：Ruby 无类型系统，profiles/README.md 明文允许省略）。明细见 `version-lock.json` 与 README.md 技术栈表。

门禁命令见 `.harness/stack.json`。**不要改它来让门变松。**

## 4. 验收

- 在 **suite 根目录** 跑 `python scripts/gate.py -p saas-identity-platform-rails`；exit 0 才算完成
- 本地命令见 README.md「快速开始」

## 5. 指向别处

- 功能清单（唯一锚点） → `docs/functions/function-tree.md`
- 需求 → 任务 → 功能影响 → `docs/requirements/`
- 流程/设计 与功能对齐 → `docs/design/`（人评审，机器只查引用）
- 决策背景 → `docs/adr/`；编码细则 → `docs/conventions/`（不进主上下文）
- 待办与迭代方向 → `PLAN.md`；版本变更 → `CHANGELOG.md`

## 6. 工作循环

0. **开工前分诊**：先过 `using-skills`，把激活 skill 的清单落成 todo。
   顺序：规格(brainstorming)→计划(writing-plans)→测试先红(red-first)→实现(executing-plans)
1. 读 `.state/session.json` 恢复上下文
2. 最小改动
3. 跑 `python scripts/gate.py -p saas-identity-platform-rails`；exit 1 回到第 2 步；exit 2 停下问人
4. `/handoff` 更新 `.state/session.json`
