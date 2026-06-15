# Forge 文档索引

> 团队协作文档规范，加文档前先看一眼。

---

## 目录结构

```
docs/
├── README.md                     ← 本文档：索引 + 规范
├── conventions.md                # 开发规范：命名、结构、工具、环境
├── forge-architecture.md         # 总架构方案：微服务拆分、技术选型、命名体系
├── sprint-plan.md                # 开发计划：W1-W4 排期 + 功能概览
├── dev-environment.md            # 环境配置：Mac + 铭凡双机开发指南
├── implementation-checklist.md   # 落地清单：环境确认、工具选型、风险控制
├── decision-log.md               # 决策日志：从构思到落地的完整讨论过程
└── services/
    ├── platform-api.md           # Platform 服务：项目/服务/部署管理
    ├── api-gateway.md            # Gateway 服务：路由 + 鉴权 + 转发
    └── user-auth-api.md          # User 服务：认证 + 身份管理
```

---

## 文档分层

| 层级 | 负责的内容 | 示例 |
|------|-----------|------|
| **架构层** | 系统怎么拆、技术怎么选、命名怎么定 | `forge-architecture.md` |
| **计划层** | 先做什么后做什么、工时怎么算 | `sprint-plan.md` |
| **执行层** | 环境好了没、工具装好没、风险降级 | `implementation-checklist.md` |
| **服务层** | 每个服务做什么功能、API 怎么设计、数据怎么存 | `services/*.md` |
| **历史层** | 为什么做这个决定、踩了什么坑 | `decision-log.md` |

---

## 规范

### 1. 写文档之前

- **功能方案** → 写到 `services/` 对应服务文档里
- **进度计划** → 更新 `sprint-plan.md`
- **架构决策** → 更新 `forge-architecture.md`
- **环境/工具变更** → 更新 `dev-environment.md` 或 `implementation-checklist.md`
- **重大决策** → 记录到 `decision-log.md`

### 2. 文件名

- 用英文短横线命名：`platform-api.md`，不用 `Platform_Service_Design.md`
- 数字前缀只在必要时用（如 `01-xxx.md`）
- 文件名说清楚「这是什么」，不用泛化词

### 3. 服务文档模板

每个服务文档至少包含：

```markdown
# {Service Name}

> 一句话定位。

---
## 功能清单          ← 这个服务做什么
## 接口设计          ← API 列表
## 数据模型          ← 表结构 + SQL
## 技术方案          ← 核心链路的实现方式
## 不在 Phase 0 范围  ← Non-goals
```

### 4. 交叉引用

- 服务文档之间互相引用用相对路径：`[platform-api](services/platform-api.md)`
- sprint-plan 引用服务文档同样用相对路径
- 文件被重命名后，**必须同步更新所有引用**

### 5. 待确认 vs 已确认

```
待确认：                           ← 还没定的
- [ ] Go 版本锁定（1.22 / 1.23）

已确认：                           ← 已经定了的
- [x] Go 1.25
```

全确认完了就把「待确认」块删掉，不留历史垃圾。

---

## 快速导航

| 我要… | 看这个 |
|--------|--------|
| 了解开发规范 | [`conventions.md`](conventions.md) |
| 了解整体架构 | [`forge-architecture.md`](forge-architecture.md) |
| 知道先做什么 | [`sprint-plan.md`](sprint-plan.md) |
| 配环境 | [`dev-environment.md`](dev-environment.md) |
| 查待办 | [`implementation-checklist.md`](implementation-checklist.md) |
| 为什么这么做 | [`decision-log.md`](decision-log.md) |
| Platform 功能 | [`services/platform-api.md`](services/platform-api.md) |
| Gateway 功能 | [`services/api-gateway.md`](services/api-gateway.md) |
| User 认证功能 | [`services/user-auth-api.md`](services/user-auth-api.md) |
