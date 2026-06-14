# Platform Service

> 平台核心服务：服务管理 + 模板管理。

## 接口设计

### 服务管理

| 接口 | 方法 | 路径 | 说明 |
|------|------|------|------|
| 服务列表 | GET | /api/platform/services | 列出所有注册的服务 |
| 服务详情 | GET | /api/platform/services/:id | 单个服务信息 |
| 注册服务 | POST | /api/platform/services | 手动注册一个服务 |
| 更新服务 | PUT | /api/platform/services/:id | 更新服务信息 |
| 删除服务 | DELETE | /api/platform/services/:id | 注销服务 |

### 模板管理

| 接口 | 方法 | 路径 | 说明 |
|------|------|------|------|
| 模板列表 | GET | /api/platform/templates | 列出可用项目模板 |
| 模板详情 | GET | /api/platform/templates/:id | 单个模板信息 |
| 创建模板 | POST | /api/platform/templates | 新增模板 |
| 更新模板 | PUT | /api/platform/templates/:id | 修改模板 |
| 删除模板 | DELETE | /api/platform/templates/:id | 删除模板 |

## 数据模型

### services

```
id          BIGINT PK
name        VARCHAR(128)    服务名称
type        VARCHAR(32)     服务类型（api/rpc）
description TEXT            服务描述
owner       VARCHAR(64)     负责人
health      VARCHAR(16)     健康状态
created_at  TIMESTAMP
updated_at  TIMESTAMP
```

### templates

```
id          BIGINT PK
name        VARCHAR(128)    模板名称
type        VARCHAR(32)     模板类型（backend/frontend/fullstack）
language    VARCHAR(32)     语言（go/vue/react）
repo_url    VARCHAR(512)    模板仓库地址
description TEXT            模板描述
stars       INT             使用次数
created_at  TIMESTAMP
updated_at  TIMESTAMP
```

## 技术要点

- 服务管理对接 K8s（展示 Pod 状态等）
- 模板管理支持从 GitHub 仓库克隆创建项目（后续）
- Phase 0 以 CRUD 为主

## 待讨论

- [ ] 服务管理的数据从哪来？手动录入还是自动发现？
- [ ] 模板怎么用？是 fork 仓库还是本地生成？
- [ ] 需要对接 ArgoCD 自动部署吗？
- [ ] 需要 WebSocket 实时推送服务状态吗？
