# SaaS 身份认证平台 Rails 后端

SaaS 身份认证平台 Rails 后端（`saas-identity-platform-rails`）——一句话系统定位（待补）。

本仓为《（书稿信息待补）》案例（待补）的可运行配套工程，是书稿代码块的 **source of truth**。

## 快速开始

```bash
# 按 rails 栈替换为实际命令
npm install        # 安装依赖
npm test           # 全量测试（无 Key / 无 Docker / 无网可跑）
npm run dev        # 本地开发
npm run build      # 生产构建
```

## 功能特性

按特性分点描述核心功能（见 `docs/functions/function-tree.md`）。

## 技术栈

| 技术 | 版本 |
| :--- | :--- |
| __STACK_DESC_LINE__ | |

> 依赖版本与 `version-lock.json` 的 `version_lock` 一致，不引入 lock 外的库。

## 配套书籍及章节映射

| 章 | 主题 | 对应源文件 |
| :--- | :--- | :--- |
| （待补） | | |

### 书一《Ruby从入门到项目实践》（第二部分）

- 书稿定位：xr-know-012，第 33、34、35、36、37、38、39、40、41 章正文代码块挂本仓 `source=` 锚点
- 配套版本：`v0.1.5-20261004`（registry 冻结 tag，代码以此为准）

| 章 | 章题 | 对应源文件 |
| :--- | :--- | :--- |
| 33 | 项目二启动：从单体到平台——SaaS 多租户导览与租户资源 | `app/controllers/admin_tenants_controller.rb` |
| 34 | 成员与邀请：租户里的人 | `app/controllers/tenant_members_controller.rb` |
| 35 | 密码登录与会话安全 | `app/controllers/sessions_controller.rb` + `app/services/auth/login_service.rb` |
| 36 | RBAC 权限模型：角色、分配与授权矩阵 | `app/controllers/tenant_members_controller.rb` + `app/controllers/tenant_role_menus_controller.rb` + `app/controllers/tenant_roles_controller.rb` |
| 37 | 租户上下文与应用订阅 | `app/controllers/me_controller.rb` + `app/controllers/tenant_applications_controller.rb` |
| 38 | 菜单树与有效授权 | `app/controllers/client_menus_controller.rb` + `app/services/me/menu_tree.rb` |
| 39 | OAuth 2.0（上）：应用注册与授权码签发 | `app/controllers/admin_clients_controller.rb` + `app/controllers/clients_controller.rb` + `app/services/oauth/authorize_service.rb` |
| 40 | OAuth 2.0（下）：令牌交换与刷新 | `app/services/oauth/token_service.rb` |
| 41 | 项目二完成：双项目收官与进阶路线图 | `app/services/me/menu_tree.rb` |
## 快速链接

- [CLAUDE.md](CLAUDE.md) — 开发约定与编码规范
- [系统架构.md](docs/ARCHITECTURE.md) — 结构 / 边界 / 数据流 / 决策
- [功能规格.md](docs/functions/function-tree.md) — 功能名称、描述与验收标准
- [未来开发计划](PLAN.md) — 待办与迭代方向
- [更新日志](CHANGELOG.md) — 版本变更记录
