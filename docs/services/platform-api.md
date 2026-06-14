# Platform Service

> 平台核心服务：项目管理 + 服务模板生成 + 多环境部署。

---

## 功能清单

### A. 项目管理

| # | 功能 | 说明 |
|---|------|------|
| A1 | 创建项目 | 选项目模板 → GitHub API 创建仓库 + 项目骨架 |
| A2 | 项目列表 | 查看所有已创建的项目 |
| A3 | 项目详情 | 查看项目信息 + 该项目下所有服务 |

### B. 服务管理

| # | 功能 | 说明 |
|---|------|------|
| B1 | 创建服务 | 选 go-zero 模板 → 填参数 → 渲染代码 → 提交 PR |
| B2 | 服务详情 | 服务信息 + 三个环境 Tab + 实时部署状态 |

### C. 部署管理

| # | 功能 | 说明 |
|---|------|------|
| C1 | 新建部署 | 选服务 + 环境 + 分支 → 触发 GitHub Actions |
| C2 | 部署状态 | 实时从 ArgoCD/K8s 查询 |
| D  | 模板列表 | 查询可用模板 |

---

## 产品闭环

```
创建项目 → GitHub 仓库自动创建
  ↓
创建服务 → 选模板 → 自动生成代码 → 提交 PR → merge → 服务就绪
  ↓
开发 push 代码
  ↓
新建部署 → 选服务 + 环境 + 分支 → GitHub Actions → ArgoCD → K8s
  ↓
前端实时查 ArgoCD/K8s 部署状态
```

---

## 接口设计

### 项目管理

| 接口 | 方法 | 路径 | 说明 |
|------|------|------|------|
| 创建项目 | POST | `/api/platform/projects` | GitHub API 创建仓库 + 写库 |
| 项目列表 | GET | `/api/platform/projects` | 读库 |
| 项目详情 | GET | `/api/platform/projects/:id` | 含服务列表 |

### 服务管理

| 接口 | 方法 | 路径 | 说明 |
|------|------|------|------|
| 创建服务 | POST | `/api/platform/projects/:id/services` | 渲染模板 → GitHub API 提 PR → 写库 |
| 服务详情 | GET | `/api/platform/services/:id` | 读库 + 实时查 ArgoCD/K8s |

### 部署管理

| 接口 | 方法 | 路径 | 说明 |
|------|------|------|------|
| 新建部署 | POST | `/api/platform/services/:id/deploy` | 触发 GH Actions workflow_dispatch |
| 部署状态 | GET | `/api/platform/services/:id/envs/:env` | 代理查 ArgoCD/K8s API |

### 模板

| 接口 | 方法 | 路径 | 说明 |
|------|------|------|------|
| 模板列表 | GET | `/api/platform/templates` | 读 `deploy/templates/` 目录 |

---

## 数据模型

```
projects        1 ──→ N   services
services        1 ──→ 3   service_envs（固定 dev / staging / prod）

部署状态不存库，从 K8s/ArgoCD 实时查询
```

### projects

```sql
CREATE TABLE projects (
    id          BIGINT PRIMARY KEY AUTO_INCREMENT,
    name        VARCHAR(64)  NOT NULL UNIQUE COMMENT '项目名',
    git_org     VARCHAR(128) NOT NULL COMMENT 'GitHub Org',
    git_repo    VARCHAR(128) NOT NULL COMMENT '仓库名',
    template    VARCHAR(64)  NOT NULL COMMENT '项目模板名',
    created_at  DATETIME DEFAULT CURRENT_TIMESTAMP,
    updated_at  DATETIME DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
);
```

### services

```sql
CREATE TABLE services (
    id          BIGINT PRIMARY KEY AUTO_INCREMENT,
    project_id  BIGINT       NOT NULL,
    name        VARCHAR(64)  NOT NULL COMMENT '服务名：user-service',
    template    VARCHAR(64)  NOT NULL COMMENT '模板：go-zero-service',
    params_json JSON         NOT NULL COMMENT '模板参数：{port,db,...}',
    created_at  DATETIME DEFAULT CURRENT_TIMESTAMP,
    updated_at  DATETIME DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    UNIQUE KEY uk_project_service (project_id, name),
    FOREIGN KEY (project_id) REFERENCES projects(id)
);
```

### service_envs

```sql
CREATE TABLE service_envs (
    id          BIGINT PRIMARY KEY AUTO_INCREMENT,
    service_id  BIGINT       NOT NULL,
    env         VARCHAR(32)  NOT NULL COMMENT 'dev / staging / prod',
    namespace   VARCHAR(64)  NOT NULL COMMENT 'K8s namespace: forge-dev',
    created_at  DATETIME DEFAULT CURRENT_TIMESTAMP,
    UNIQUE KEY uk_service_env (service_id, env),
    FOREIGN KEY (service_id) REFERENCES services(id)
);
```

每个服务创建时自动插入 3 条 `service_envs` 记录。

---

## 技术方案

### 创建项目

```
用户在前端填表单 → POST /api/platform/projects
  → platform 调 GitHub API 创建仓库
  → 渲染项目模板（forge.yaml + 目录骨架）
  → 提交初始文件到仓库
  → 写 projects 表
  → 返回项目 ID + 仓库地址
```

### 创建服务（核心链路）

```
用户在前端选模板 + 填参数 → POST /api/platform/projects/:id/services
  → 从 deploy/templates/go-zero-service/ 读取模板
  → Go text/template 渲染所有 .tpl 文件
  → GitHub API：创建分支 → 批量提交文件 → 开 Pull Request
  → 写 services 表
  → 自动插入 3 条 service_envs 记录
  → 返回 PR 链接
```

### 模板目录结构

```
deploy/templates/
├── project/                    # 项目模板
│   ├── template.yaml
│   ├── forge.yaml.tpl
│   └── README.md.tpl
└── go-zero-service/            # 服务模板
    ├── template.yaml           # 参数定义
    ├── cmd/main.go.tpl
    ├── internal/handler/{{.ServiceName}}.go.tpl
    ├── internal/logic/{{.ServiceName}}.go.tpl
    ├── Dockerfile.tpl
    ├── go.mod.tpl
    └── deploy/helm/            # Helm Chart
        ├── Chart.yaml.tpl
        ├── values.yaml.tpl
        └── templates/deployment.yaml.tpl
```

### 新建部署

```
前端 POST /api/platform/services/:id/deploy
  body: { env: "staging", branch: "feature/login" }
  → platform 查 service_envs 拿到 repo 信息
  → 调 GitHub API: POST /repos/{org}/{repo}/actions/workflows/deploy-{service}.yaml/dispatches
    inputs: { service, env, branch, namespace }
  → GitHub Actions 构建 → push GHCR → ArgoCD 同步 → K8s
```

### 状态查询（实时，不存库）

```
前端 GET /api/platform/services/:id/envs/staging
  → platform 查 service_envs → namespace: forge-staging
  → 调 ArgoCD API: GET /api/v1/applications/forge-{service}-staging
  → 返回实时状态: { sync_status, health_status, version, branch, lastDeployed }
```

---

## 不在 Phase 0 范围

| 功能 | 推迟原因 |
|------|---------|
| 部署回滚 | Phase 1 |
| 自定义环境数量 | 固定 dev/staging/prod 三环境 |
| 用户认证 | Day 8 补位，硬编码 token |
| 多服务模板 | 先做一个 go-zero 模板 |
| 部署历史持久化 | 从 ArgoCD 实时查，不另存 |
