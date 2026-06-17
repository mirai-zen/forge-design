# Forge 开发规范

> 所有 Forge 项目开发必须遵守此规范。新增工具/仓库/环境变更时同步更新本文档。

---

## 1. 仓库体系

| 仓库 | 可见性 | 本地路径 | 用途 |
|------|--------|---------|------|
| **forge-proto** | 公开 | `/Users/mirai/Code/go/forge-proto/` | 协议仓库 |
| **forge** | 私有 | `/Users/mirai/Code/go/forge/` | 后端 Monorepo |
| **forge-web** | 私有 | `/Users/mirai/Code/web/forge-web/` | 前端 |
| **forge-design** | 私有 | `/Users/mirai/CodeBuddy/forge-design/` | 设计文档 |

> ⚠️ `forge-design` 是纯文档仓库，不放任何代码。

GitHub Organization: `mirai-zen`

---

## 2. 环境信息

### 开发机：MacBook M4 Pro

| 项目 | 配置 |
|------|------|
| OS | macOS 26.3 |
| 内存 | 48 GB |
| 磁盘 | 1 TB |
| 包管理 | Homebrew |
| Go | 1.25 |
| Node | 24.15.0 |
| IDE 前端 | VS Code |
| IDE 后端 | GoLand |

### 测试机：铭凡 UM890 Pro

| 项目 | 配置 |
|------|------|
| OS | Windows 11 + WSL2 AlmaLinux (dnf) |
| CPU | 8 核 16 线程 |
| 内存 | 64 GB |
| 磁盘 | 1 TB SSD |
| Docker | Docker Desktop for Windows |
| K8s | Kind 集群（3 节点） |

### 网络

- 两台机器在同一局域网
- 通过 Tailscale 互联，不依赖公网 IP

### 数据库

| 项目 | 配置 |
|------|------|
| 类型 | MySQL 8.0 (Docker 容器) |
| 容器名 | `mysql` |
| 端口 | 3306 |
| 用户 | root / root123 |
| 数据库 | `forge_platform` |

---

## 3. 命名规范

| 层级 | 命名 | 示例 |
|------|------|------|
| 项目名 | `forge` | Forge IDP |
| GitHub 组织 | `mirai-zen` | github.com/mirai-zen |
| 仓库 | `forge-{name}` | forge-proto / forge / forge-web |
| Proto 模块 | `forge-proto/{service}` | forge-proto/platform |
| 后端模块 | `forge/{service}` | forge/platform |
| K8s Namespace（业务） | `forge-{env}` | forge-dev / forge-staging / forge-prod |
| K8s Namespace（工具） | `infra` | ArgoCD + MySQL + monitoring |
| K8s Service | `forge-{service}` | forge-platform |
| Docker Image | `ghcr.io/mirai-zen/forge-{service}` | ghcr.io/mirai-zen/forge-platform |
| etcd Key | `{service}.rpc` | platform.rpc |

---

## 4. 仓库结构

### forge-proto（协议仓库）

```
forge-proto/
├── {service}/              # 每个服务一个目录，独立 go.mod
│   ├── go.mod              # module github.com/mirai-zen/forge-proto/{service}
│   ├── {service}.proto     # proto 定义
│   └── {service}.pb.go     # buf generate 输出（和 proto 同目录）
├── buf.gen.yaml
├── go.work
└── .github/workflows/
```

go_package 格式：`github.com/mirai-zen/forge-proto/{service};{service}v1`

### forge（后端 Monorepo）

```
forge/
├── {service}/              # 每个服务独立 go.mod
│   ├── go.mod              # module github.com/mirai-zen/forge/{service}
│   ├── cmd/main.go
│   ├── internal/
│   │   ├── handler/
│   │   ├── logic/
│   │   ├── svc/
│   │   └── config/
│   ├── Dockerfile
│   └── configs/{service}.yaml.example
├── deploy/
│   ├── charts/{service}/
│   └── argocd/
├── sql/
│   └── init.sql
├── go.work
└── .github/workflows/
```

---

## 5. 部署架构

### 核心链路

```
创建项目 → GitHub API 创建仓库 + 渲染项目模板
创建服务 → 选模板 → text/template 渲染 → GitHub API 提交 PR
新建部署 → GitHub Actions workflow_dispatch → build → push GHCR → ArgoCD sync
状态查询 → 实时调 ArgoCD/K8s API（不存库）
```

### 环境

| 环境 | K8s Namespace | 说明 |
|------|--------------|------|
| dev | forge-dev | 开发环境 |
| staging | forge-staging | 测试环境 |
| prod | forge-prod | 正式环境 |

每个服务创建时自动初始化 3 个环境。

### 数据模型

```
projects      1 ──→ N services
services      1 ──→ 3 service_envs（dev/staging/prod）
```

部署状态不持久化，实时从 K8s/ArgoCD 查询。

---

## 6. 文档规范

### 文件命名

- 英文短横线：`platform-api.md`
- 不用泛化词，说清内容
- 数字前缀仅必要时用

### 写入规则

| 内容类型 | 写到 |
|---------|------|
| 功能方案 | `docs/services/{service}.md` |
| 进度计划 | `docs/sprint-plan.md` |
| 架构决策 | `docs/forge-architecture.md` |
| 环境/工具变更 | `docs/dev-environment.md` 或 `docs/implementation-checklist.md` |
| 重大决策过程 | `docs/decision-log.md` |

### 待确认 vs 已确认

```markdown
待确认：        ← 还没定
- [ ] xxx

已确认：        ← 定了就改掉
- [x] xxx
```

全确认后删除「待确认」块。

### 交叉引用

- 用相对路径：`[platform-api](services/platform-api.md)`
- 改名后必须同步更新所有引用

### 服务文档模板

```markdown
# {Service Name}

> 一句话定位。

## 功能清单
## 接口设计
## 数据模型
## 技术方案
## 不在 Phase 0 范围
```
