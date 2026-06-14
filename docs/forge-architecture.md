# Forge - 云原生内部开发者平台（IDP）技术方案设计

## 一、项目概述

### 1.1 项目定位
Forge（云原生内部开发者平台，Internal Developer Platform），对标腾讯星斗（Tencent Xingdou），为研发团队提供一站式的研发基础设施和开发体验。

### 1.1.1 命名体系

| 层级 | 命名规则 | 示例 |
|------|----------|------|
| **项目名称** | `forge` | Forge IDP |
| **GitHub 组织** | `mirai-zen` | github.com/mirai-zen |
| **仓库名** | `forge-{name}` | `forge-proto` / `forge` / `forge-web` |
| **协议仓库** | `forge-proto` | github.com/mirai-zen/forge-proto |
| **Proto 模块** | `forge-proto/{service}` | `forge-proto/user` |
| **服务模块** | `forge/{service}` | `forge/user` |
| **K8s Namespace** | `forge-{env}` | `forge-dev`, `forge-prod` |
| **Service (K8s)** | `forge-{service}` | `forge-gateway`, `forge-user` |
| **Docker Image** | `ghcr.io/{org}/forge-{service}` | `ghcr.io/mirai-zen/forge-user` |
| **etcd Key** | `/forge/{service}/{instance}` | `/forge/user/192.168.1.10:8080` |
| **Helm Chart** | `forge-{service}` | `forge-gateway`, `forge-user` |
| **Log Service** | `forge.{service}` | `forge.gateway`, `forge.user` |
| **Prometheus Job** | `job="forge-{service}"` | `job="forge-gateway"` |
| **Jaeger Service** | `forge-{service}` | `jaeger logic: forge-gateway` |

### 1.1.2 为什么自研而不是用 Backstage？

| 维度 | 自研 | Backstage |
|------|------|-----------|
| **学习深度** | 从零设计架构，深入理解每个环节 | 只会用插件，不理解底层 |
| **技术掌控** | 完全掌控技术栈，自主选型 | 受 Backstage 框架和插件生态限制 |
| **执行引擎** | 自研 K8s Controller + ArgoCD 集成 | Backstage 只是前端门户，执行还是要自己写 |
| **简历价值** | S 级区分度 | 只能说"用过 Backstage" |

> 企业级落地可以考虑 **Backstage 做前端门户 + 自研后端引擎**的组合方案，兼顾开发效率和定制能力。

### 1.2 项目目标
- **简历 Demo**：展示云原生、微服务、平台工程等前沿技术能力
- **长期开发**：作为个人长期使用的研发平台，支持项目快速搭建和部署
- **技术沉淀**：形成可复用的技术工具箱和最佳实践

### 1.2.1 非目标（Non-Goals）

> 明确边界，防止范围蔓延。

- ❌ 不做多租户计费与账单系统
- ❌ 不做跨云多活架构（单集群足够）
- ❌ 不做 Istio 服务网格（go-zero middleware 已覆盖核心治理需求）
- ❌ 不做自建 Git 服务（直接使用 GitHub）
- ❌ 不做移动端 App
- ❌ Phase 1~3 不做 OAuth2.0 / OIDC 第三方登录

### 1.3 核心功能模块
| 模块 | 功能描述 |
|------|---------|
| 服务管理 | 代码仓库、制品库、依赖管理 |
| 模板中心 | 项目模板、CI/CD 模板、基础设施模板 |
| 部署中心 | 一键部署、灰度发布、回滚、扩缩容（K8s 集成） |
| 监控中心 | 链路追踪、指标采集、日志查询、告警 |
| 用户与权限 | 用户管理、角色权限（RBAC）、租户隔离 |
| 配置中心 | 环境配置、灰度配置、密钥管理 |
| **注册中心控制面板** | 前端可视化 etcd 服务列表、健康状态、配置热更新 |
| **运维 Agent** | AI 驱动的自动化运维（Phase 3）——不是概念，有具体方案 |

### 1.4 仓库策略：协议独立 + 服务 Monorepo

> **核心原则**：API 协议是一等公民，独立于业务实现；后端服务在单一仓库内按目录隔离，每个服务持有独立的 `go.mod`，随时可拆分为独立仓库。

#### 仓库拆分

```
GitHub Organization: mirai-zen

Phase 0（3 个仓库）：
├── forge-proto              # API 协议仓库（公开）
│   ├── user/              # user-service proto（独立 go.mod）
│   │   ├── go.mod            # module github.com/mirai-zen/forge-proto/user
│   │   ├── user.proto
│   │   └── gen/              # buf generate 输出（go/ts/openapi）
│   ├── gateway/           # gateway-service proto（独立 go.mod）
│   │   ├── go.mod            # module github.com/mirai-zen/forge-proto/gateway
│   │   ├── gateway.proto
│   │   └── gen/
│   ├── platform/          # platform-service proto（独立 go.mod）
│   │   ├── go.mod            # module github.com/mirai-zen/forge-proto/platform
│   │   ├── platform.proto
│   │   └── gen/
│   ├── buf.gen.yaml          # buf 代码生成配置
│   ├── go.work               # Go workspace
│   └── .github/workflows/    # 各 proto 独立 CI
│
├── forge             # 后端 + 部署 Monorepo（私有）
│   ├── user/                 # user-service（独立 go.mod）
│   │   ├── go.mod            # module github.com/mirai-zen/forge/user
│   │   ├── cmd/main.go
│   │   ├── internal/         # handler + logic + svc + config
│   │   └── Dockerfile
│   ├── gateway/              # gateway-service（独立 go.mod）
│   ├── platform/             # platform-service（独立 go.mod）
│   ├── deploy/               # 部署配置（代码和部署一起改）
│   │   ├── charts/           # Helm Charts（按服务拆分）
│   │   └── argocd/           # ArgoCD Application 定义
│   ├── go.work
│   └── .github/workflows/    # 各服务独立 CI
│
└── forge-web                # 前端 Monorepo（私有）
    ├── apps/                 # 子应用
    │   ├── main/             # 主应用（登录、仪表盘）
    │   └── etcd-panel/       # 注册中心面板
    ├── packages/             # 共享包
    │   ├── ui/               # 共享组件
    │   └── proto-types/      # TS 类型（从 forge-proto 生成）
    └── pnpm-workspace.yaml

后续仓库（按需创建）：
├── forge-infra            # 基础设施 IaC（Phase 3）
└── forge-agent            # AI 运维 Agent（Phase 4）
```

#### Monorepo 设计理由（forge-proto 与 forge 对齐）

**forge-proto 和 forge 采用完全一致的 Monorepo 治理策略：**

| 维度 | forge-proto | forge |
|------|-----------|----------------|
| **独立 go.mod** | `forge-proto/user` | `forge/user` |
| **独立版本** | proto 各自打 tag | 服务各自打 tag |
| **go.work** | 本地 workspace | 本地 workspace |
| **独立 CI** | 每 proto 一个 workflow | 每服务一个 workflow |
| **随时可拆** | 复制目录即独立仓库 | 同左 |

**为什么对齐：**
| 维度 | 说明 |
|------|------|
| **治理一致** | proto 和服务用同一套哲学，降低认知负担 |
| **版本解耦** | `user` 升级不影响 `gateway` 的 proto 版本 |
| **按需拉取** | 服务只 `go get` 自己需要的 proto 模块，不拉全量 |
| **独立 go.mod** | 腾讯/Google/Uber 的大厂标准做法

#### 每个服务内部统一结构

```
{service}/
├── go.mod                 # 独立模块
├── go.sum
├── cmd/
│   └── main.go            # 唯一入口，只做启动
├── internal/
│   ├── handler/           # HTTP 层：参数校验、请求绑定、返回响应
│   ├── logic/             # 业务逻辑 + 数据访问
│   ├── svc/               # ServiceContext：依赖注入容器
│   └── config/            # 配置结构体 + YAML
├── Dockerfile
└── README.md
```

#### 跨 Proto 依赖规范

> **核心原则**：不同服务的 proto 之间不应直接 import。如需复用 message，抽取到独立 `common/` 模块。

```
允许：
  forge/user  ——→ 引用 forge-proto/user     ✅ 自己的 proto
  forge/gateway ——→ 引用 forge-proto/user    ✅ 通过 go.mod 声明依赖

禁止：
  gateway.proto ——→ import "user/user.proto" ❌ 循环依赖风险
```

**需要共享 message 时：**
```
forge-proto/
├── common/              # 共享模块（按需创建）
│   ├── go.mod
│   └── types.proto      # 如 ErrorResponse、PageRequest
├── user/                # 可 import common
└── gateway/             # 可 import common
```

**版本策略：**
```bash
# 每个 proto 模块独立打 tag
git tag user/v0.1.0
git tag gateway/v0.1.0
# common 也是独立模块，单独打 tag
git tag common/v0.1.0
```

#### 前端 Proto 类型引用

```
forge-web/packages/proto-types/
    └── src/
        ├── user.ts      ← 从 forge-proto/user 生成
        ├── gateway.ts   ← 从 forge-proto/gateway 生成
        └── index.ts     # 统一导出
```

按需安装，用 pnpm workspace 管理：
```json
// apps/main/package.json
{
  "dependencies": {
    "@forge/proto-types": "workspace:*"
  }
}
```

#### 各方引用方式

| 角色 | 引用方式 | 拉取内容 |
|------|---------|---------|
| **后端服务** | `go get github.com/mirai-zen/forge-proto@v1.2.0` | 仅 proto + .pb.go，不拉源码 |
| **前端** | `npm install @mirai-zen/forge-proto`（TypeScript 类型） | 仅 .ts 类型定义 |
| **第三方** | `go get github.com/mirai-zen/forge-proto` | 只有 API 契约，看不到实现 |

#### 协议治理（buf）

| 能力 | 工具 | 说明 |
|------|------|------|
| **代码生成** | `buf generate` | Go/TypeScript/OpenAPI 一键生成 |
| **规范检查** | `buf lint` | 强力检查命名、目录结构等 |
| **向后兼容** | `buf breaking` | PR 中自动检测不兼容变更 |
| **依赖管理** | `buf mod` | proto 文件间依赖管理 |

#### 协议发布流水线

```
开发者修改 .proto → PR
  ├── buf lint（规范检查）
  ├── buf breaking（兼容性检查）
  └── Code Review
        │
        ▼
  合并到 main
        │
        ▼
  GitHub Actions 自动：
  ├── buf generate（Go + TS + OpenAPI）
  ├── Git Tag（{service}/0.1.0，每 proto 独立版本）
  └── GitHub Release
        │
        ▼
  forge Renovate 检测
  └── 自动提 PR 升级 proto 依赖
```

#### CI/CD 设计：每服务独立 Workflow

> **核心理念**：每个服务一个 GitHub Actions workflow，按目录路径触发，互不影响。

```
.github/workflows/
├── user-ci.yml         # 监听 user/** 变更
├── gateway-ci.yml      # 监听 gateway/** 变更
└── platform-ci.yml     # 监听 platform/** 变更
```

**触发规则：**
```
PR 改 user/handler/login.go
  → user-ci.yml 触发       ✅
  → gateway-ci.yml 跳过     ❌（未改 gateway/）
  → platform-ci.yml 跳过    ❌（未改 platform/）
```

**每个 Workflow 两个 Job：**

| Job | 触发条件 | 步骤 |
|-----|---------|------|
| **build** | PR / Push main | `go vet` → `go test -race` → `go build` |
| **docker** | Push main 时 | 构建镜像 → 推送到 `ghcr.io/mirai-zen/forge-{service}` |

**Docker Context 设计：**
- Context 为服务目录自身（`./user`）
- 每个 Dockerfile 只看到自己的 `go.mod` 和代码
- 服务间零耦合，未来拆仓库无需改 Dockerfile

**扩展新服务：**
```bash
cp .github/workflows/user-ci.yml .github/workflows/new-svc-ci.yml
sed -i 's/user/new-svc/g' .github/workflows/new-svc-ci.yml
```

#### forge-proto CI（与 forge 对齐）

```
forge-proto/.github/workflows/
├── proto-user-ci.yml      # 监听 user/** 变更
├── proto-gateway-ci.yml   # 监听 gateway/** 变更
└── proto-platform-ci.yml  # 监听 platform/** 变更
```

**每个 Workflow：**

| Job | 步骤 |
|-----|------|
| **lint** | `buf lint` → `buf breaking`（PR 时检测兼容性）→ `buf generate` → `go vet` |

**版本策略：**
```bash
# 每个 proto 独立打 tag
git tag user/v0.1.0 cd user/v1 && git tag user/0.1.0 && git push --tagscd user/v1 && git tag user/0.1.0 && git push --tags git push --tags
git tag gateway/v0.1.0 cd gateway/v1 && git tag gateway/v0.1.0 && git push --tagscd gateway/v1 && git tag gateway/v0.1.0 && git push --tags git push --tags
```

**服务引用方式：**
```go
// 按需引用，不拉全量 proto
import userv1 "github.com/mirai-zen/forge-proto/user"
```

#### 部署配置（forge/deploy/）

> 部署配置与代码同仓库，改接口时同步改 Helm Chart，一个 PR 完成。

```
forge/deploy/
├── charts/                  # Helm Charts
│   ├── user/                # user-service 的 Helm Chart
│   │   ├── Chart.yaml
│   │   ├── values.yaml
│   │   ├── values-dev.yaml
│   │   └── templates/
│   │       ├── deployment.yaml
│   │       ├── service.yaml
│   │       └── configmap.yaml
│   ├── gateway/
│   └── platform/
└── argocd/                  # ArgoCD Application
    ├── user.yaml            # 指向 charts/user/
    ├── gateway.yaml
    └── platform.yaml
```

---

## 二、后端技术选型

### 2.1 语言选型：Go

| 维度 | Go | Java | Python | Node.js |
|------|-----|------|--------|---------|
| 性能 | ⭐⭐⭐⭐⭐ | ⭐⭐⭐⭐ | ⭐⭐ | ⭐⭐⭐ |
| 并发模型 | Goroutine（轻量级） | Thread（重量级） | GIL 限制 | 单线程事件循环 |
| 编译部署 | 静态编译，单二进制文件 | JVM 依赖 | 解释执行 | Node.js 运行时 |
| 类型安全 | 静态类型 | 静态类型 | 动态类型 | 动态类型（TS 可选） |
| 社区生态 | 云原生首选 | 企业级生态最丰富 | AI/ML 首选 | 前端生态丰富 |

**选型理由：**
- 云原生生态首选（K8s、Docker、Prometheus 均为 Go 编写）
- 高性能、低内存占用，适合微服务架构
- 静态编译，部署简单（单二进制文件）
- 并发模型优秀（Goroutine 轻量级，适合高并发场景）

---

### 2.2 微服务框架选型：go-zero

#### 候选框架对比

| 框架 | 出品方 | 定位 | 微服务治理 | 社区活跃度 | 大厂采用 | 推荐指数 |
|------|--------|------|-----------|-----------|---------|---------|
| **go-zero** | 社区 | 极致性能 + 完备工具链 | ⭐⭐⭐⭐⭐ | ⭐⭐⭐⭐⭐ | 腾讯/华为/美团/好未来 | ⭐⭐⭐⭐⭐ |
| Kratos | B站 | 企业级标准化 | ⭐⭐⭐⭐⭐ | ⭐⭐⭐ | B站/携程/京东 | ⭐⭐⭐⭐ |
| Kitex | 字节 | 高性能 RPC | ⭐⭐⭐⭐ | ⭐⭐⭐ | 字节/腾讯 | ⭐⭐⭐⭐ |
| GoFrame | 社区 | 一站式 Web | ⭐⭐⭐ | ⭐⭐⭐ | 中小厂 | ⭐⭐⭐⭐ |
| Go-Micro | 社区 | 跨语言平台 | ⭐⭐⭐⭐ | ⭐⭐⭐ | 部分金融 | ⭐⭐⭐ |
| Gin | 社区 | HTTP 框架 | ⭐⭐ | ⭐⭐⭐⭐⭐ | 广泛 | ⭐⭐⭐ |

#### 为什么选 go-zero？

**1. 企业采用率最高**
- 腾讯、华为、美团、好未来等大厂已验证
- 钉钉/微信群高频活跃，问题响应快
- 社区活跃度 2024~2026 年持续上升，没有衰减迹象

**2. goctl 代码生成器（核心优势）**
```bash
# 一行命令生成 API 定义 + 网关配置 + RPC stub + Model 层
goctl api go -api user.api -dir .          # RESTful API 服务
goctl rpc protoc user.proto --go_out=.     # gRPC 服务
goctl model mysql ddl -src user.sql -dir . # 数据库 Model
```
> 比 Kratos 的 protoc 代码生成更强大，能少写 50% 手工代码

**3. 内置治理能力，不需要额外集成**
- 自适应限流、自适应熔断、自适应负载均衡
- 链路追踪（OpenTelemetry 原生集成）
- 缓存（内置 Redis 缓存拦截器）
- 分布式限流（基于 Redis）

**4. 云原生友好**
- 与 K8s 天然集成
- Docker 部署最佳实践
- 支持服务网格（go-zero + Istio 有完整方案）

**5. 简历价值**
- 腾讯、华为、美团都在用，面试官认可度极高
- 展示对主流企业级框架的理解

> **为什么不是 Kratos？** Kratos 文档和示例在个人项目中也很优秀，但 go-zero 在企业中的真实采用率更高，内置工具链更完整，社区活跃度持续上升。两者都基于 gRPC 和标准接口，如果团队偏好 Kratos，迁移成本很低。

> **适用规模**：个人 ✅ | 小团队 ✅ | 企业（腾讯/华为/美团已验证）✅

#### go-zero 项目结构

```
api/                       # API 定义文件（.api）
├── user.api
├── service.api
└── deploy.api
internal/
├── handler/               # HTTP Handler
├── logic/                 # 业务逻辑
├── svc/                   # ServiceContext（依赖注入）
├── config/                # 配置定义
├── middleware/             # 中间件（认证、限流、日志）
└── model/                 # 数据访问层
proto/                      # gRPC Protobuf 定义
etc/                        # 配置文件
```

---

### 2.3 API 协议：gRPC + HTTP（RESTful）

| 维度 | gRPC | RESTful（JSON） | GraphQL | WebSocket |
|------|------|-----------------|---------|-----------|
| 性能 | ⭐⭐⭐⭐⭐（Protobuf） | ⭐⭐⭐（JSON） | ⭐⭐⭐ | ⭐⭐⭐⭐ |
| 类型安全 | ✅（Protobuf Schema） | ❌ | ✅（Schema） | ❌ |
| 跨语言 | ✅ | ✅ | ✅ | ✅ |
| 调试友好 | ❌（需要工具） | ✅（浏览器） | ✅ | ❌ |
| 实时通信 | ✅（Streaming） | ❌ | ❌ | ✅ |

**选型理由：**
- **gRPC**：服务间通信（内部 RPC），高性能、类型安全、代码生成
- **HTTP RESTful**：对外暴露（通过 gRPC Gateway 自动生成），调试友好
- 后期可根据需求引入 WebSocket（实时通知）

---

### 2.4 ORM：GORM

| 方案 | 社区 | 性能 | 文档 | 推荐指数 |
|------|------|------|------|---------|
| **GORM** | ⭐⭐⭐⭐⭐ | ⭐⭐⭐⭐ | ⭐⭐⭐⭐⭐ | ⭐⭐⭐⭐⭐ |
| Ent | ⭐⭐⭐ | ⭐⭐⭐⭐⭐ | ⭐⭐⭐⭐ | ⭐⭐⭐⭐ |
| sqlx | ⭐⭐⭐⭐ | ⭐⭐⭐⭐⭐ | ⭐⭐⭐ | ⭐⭐⭐ |
| sqlc | ⭐⭐⭐ | ⭐⭐⭐⭐⭐ | ⭐⭐⭐ | ⭐⭐⭐ |

**选型理由（GORM）：**
- Go 生态事实标准，社区最活跃（Star 40k+）
- 支持 MySQL、PostgreSQL、SQLite 多驱动
- Auto Migration、Hook、Preload 等高级特性
- 中文文档完善，示例丰富
- **DANGER: GORM v1 存在 N+1 查询问题，务必使用 v2 版本**，并通过 `Preload` 或显式 JOIN 避免性能陷阱

#### 数据库迁移：golang-migrate

| 方案 | 纯 SQL | Go 嵌入 | 推荐指数 |
|------|--------|---------|---------|
| **golang-migrate** | ✅ | ✅ | ⭐⭐⭐⭐⭐ |
| Atlas | ✅ | ✅ | ⭐⭐⭐⭐ |

**选型理由：golang-migrate**，轻量无依赖，纯 SQL 迁移文件，支持向上/向下迁移。

---

### 2.5 日志组件：Uber Zap

| 方案 | 性能 | 结构化 | go-zero 适配 | 推荐指数 |
|------|------|--------|------------|---------|
| **Zap** | ⭐⭐⭐⭐⭐ | ✅ | ✅（官方示例） | ⭐⭐⭐⭐⭐ |
| Zerolog | ⭐⭐⭐⭐⭐ | ✅ | ⚠️ 需适配 | ⭐⭐⭐⭐ |
| Logrus | ⭐⭐⭐ | ✅ | ⚠️ 需适配 | ⭐⭐⭐ |

**选型理由（Zap）：**
- **Uber 开源**，专为高性能场景设计，零内存分配
- **go-zero 官方示例使用**，社区方案成熟
- 原生 JSON 格式输出，直接对接 Fluent Bit → Loki
- 天然支持注入 `traceID`、`spanID`，与 OpenTelemetry 联动

**日志输出示例：**
```go
import "go.uber.org/zap"

func (s *UserService) Login(ctx context.Context, req *pb.LoginRequest) {
    s.logger.Info("User login",
        zap.String("traceID", trace.TraceIDFromContext(ctx)),
        zap.String("username", req.Username),
    )
}
// 输出 (stdout → JSON):
// {"level":"info","ts":"...","msg":"User login","traceID":"abc123","username":"xxx"}
```

---

### 2.6 服务注册与配置中心：etcd

| 方案 | 语言 | 一致性 | 配置中心 | 内存 | 推荐指数 |
|------|------|--------|---------|------|---------|
| **etcd** | **Go** | Raft (CP) | ✅ | ~128 MB | ⭐⭐⭐⭐⭐ |
| Nacos | Java | Raft (AP/CP) | ✅ | 1 GB+ | ⭐⭐⭐⭐ |
| Consul | Go | Raft (CP) | ❌ | ~256 MB | ⭐⭐⭐ |
| Zookeeper | Java | ZAB (CP) | ❌ | ~512 MB | ⭐⭐ |

**选型理由：**
- **纯 Go 编写**，与 go-zero 技术栈 100% 统一，不再需要 JVM
- **K8s 控制面核心**——K8s 的所有状态（Pod/Service/ConfigMap）都存在 etcd 里，Kind 集群自带 etcd，零额外部署
- **Raft 共识算法**：Leader 选举 + 日志复制 + Quorum 机制，保证强一致性
- **MVCC + Watch**：基于多版本并发控制的 Watch 机制，服务列表变更实时推送，无需轮询
- **go-zero 原生支持**：通过 `go-zero-zookeeper` 类似的 discov 插件直接接入 etcd
- **配置中心**：go-zero 的 `configurator` 直接对接 etcd，通过 Watch 实现配置热更新

> **Raft 关键知识点（面试加分）**：Leader 选举（随机超时 150-300ms，防止脑裂）、日志复制（过半写入即提交 Quorum = N/2+1）、Term 递增防止过期 Leader 写入。MVCC 使得 etcd 可以保存历史版本，支持回滚。

> 面试话术："我选择 etcd 而不是 Nacos，主要考虑三点——100% Go 栈、K8s 原生集成、Raft 共识协议。etcd 是 K8s 的控制面数据库，理解 etcd 等于理解 K8s 的心脏。我在前端还做了一个注册中心控制面板，实时展示服务健康状态。"

**Nacos 对比说明（为什么不用）**：Nacos 功能也很强大（服务发现+配置中心+Web UI），但它需要 JVM，在 Go 技术栈中引入 Java 运行时是一个运维负担。etcd 在 Go 生态中更自然，且直接复用 Kind/K8s 自带的 etcd 实例。

> **适用规模**：个人 ✅ | 小团队 ✅ | 企业 ✅（K8s 控制面级可靠性）

---

### 2.7 可观测性：OpenTelemetry + Jaeger

#### OpenTelemetry（数据采集标准）

| 方案 | 链路追踪 | 指标采集 | 日志采集 | 标准化 | 推荐指数 |
|------|---------|---------|---------|--------|---------|
| **OpenTelemetry** | ✅ | ✅ | ✅ | ✅（CNCF 标准） | ⭐⭐⭐⭐⭐ |
| Jaeger SDK | ✅ | ❌ | ❌ | ❌ | ⭐⭐⭐ |
| Prometheus | ❌ | ✅ | ❌ | ❌ | ⭐⭐⭐⭐ |
| ELK | ❌ | ❌ | ✅ | ❌ | ⭐⭐⭐⭐ |
| Datadog | ✅ | ✅ | ✅ | ❌（商业） | ⭐⭐⭐⭐ |

**选型理由：**
- **CNCF 标准化**，统一的可观测性标准
- 链路追踪（Trace）、指标采集（Metrics）、日志采集（Logs）三位一体
- 厂商中立，不绑定特定存储后端
- go-zero 原生支持

#### OpenTelemetry Collector 部署

| 模式 | 适用场景 | 推荐 |
|------|---------|------|
| **Deployment** | 中心化收集，所有服务推送 | ✅ 本方案 |
| DaemonSet | 每节点一个，收集节点级数据 | ⚠️ 补充模式 |
| Sidecar | 每个 Pod 一个，零网络开销 | ❌ 资源浪费 |

**选型：Deployment 模式**——微服务通过 gRPC 将 Trace/Metrics 发送到 Collector Service，Collector 批量转发到 Jaeger + Prometheus，避免每个微服务直连多个后端。

```
微服务 (OTel SDK, gRPC exporter)
  │
  ▼
otel-collector.idp.svc:4317  (gRPC)
  │
  ├── trace → Jaeger (jaeger-collector.idp.svc:14250)
  └── metrics → Prometheus (scrape otel-collector:8889/metrics)
```

#### Jaeger（链路追踪后端）

| 方案 | 瀑布图 | 拓扑图 | 查询能力 | 资源占用 | 推荐指数 |
|------|--------|--------|---------|---------|---------|
| **Jaeger** | ✅ **完整瀑布图** | ✅ | ⭐⭐⭐⭐ | ⭐⭐⭐⭐ | ⭐⭐⭐⭐⭐ |
| SkyWalking | ✅ 瀑布图 | ✅ **高级拓扑图** | ⭐⭐⭐⭐⭐ | ⭐⭐⭐ | ⭐⭐⭐⭐⭐ |
| Zipkin | ✅ 基础瀑布图 | ❌ | ⭐⭐⭐ | ⭐⭐⭐⭐ | ⭐⭐⭐ |

**选型理由：**
- **瀑布图（Waterfall View）**：直观展示每个 Span 的耗时、调用关系和层级结构
- **服务依赖拓扑图**：展示服务间的调用关系和流量分布
- **Trace 查询**：支持按 Service、Operation、Duration、Tags 等条件过滤
- **与 OpenTelemetry 原生集成**：go-zero 支持 OTel Exporter，直接接入 Jaeger
- **与 Grafana 集成**：通过 Grafana Jaeger 插件，可在统一界面查看 Trace 和 Metrics

#### 链路追踪与日志的关联

```
用户在 Grafana 查询日志：
  {app="user-service"} | traceID="abc123"
    ↓
点击日志中的 traceID，跳转到 Jaeger
    ↓
Jaeger 展示完整瀑布图：
  API Gateway → User Service → Database
    ├─ 总耗时：150ms
    ├─ User Service：80ms
    └─ Database：50ms
```

**日志注入 traceID 示例（JSON 格式）：**
```json
{
  "timestamp": "2026-06-14T01:00:00Z",
  "level": "info",
  "msg": "User login successful",
  "traceID": "abc123",
  "spanID": "def456",
  "service": "user-service"
}
```

**LogQL 查询 traceID 示例：**
```logql
{app="user-service"} | traceID="abc123"
```

---

### 2.8 API 网关：Nginx Ingress + go-zero Gateway

#### 双层网关架构

| 层级 | 组件 | 职责 |
|------|------|------|
| **外层（K8s Ingress）** | Nginx Ingress Controller | TLS 终止、域名路由、WAF、基础限流 |
| **内层（微服务）** | gateway-service（go-zero） | JWT 鉴权、细粒度限流、请求聚合、协议转换（gRPC ↔ HTTP）|

#### Ingress Controller 选型

| 方案 | 性能 | 配置方式 | K8s 集成 | 推荐指数 |
|------|------|---------|---------|---------|
| **Nginx Ingress** | ⭐⭐⭐⭐ | K8s Ingress 资源 | ⭐⭐⭐⭐⭐ | ⭐⭐⭐⭐⭐ |
| Traefik | ⭐⭐⭐⭐ | CRD/K8s Ingress | ⭐⭐⭐⭐⭐ | ⭐⭐⭐⭐ |
| Istio Gateway | ⭐⭐⭐⭐⭐ | CRD | ⭐⭐⭐⭐⭐ | ⭐⭐⭐ |

**选型理由：Nginx Ingress**——最成熟稳定，社区资源最多，配置简洁。

**请求流向：**
```
用户 → Nginx Ingress (TLS终止) → gateway-service (鉴权/限流) → 后端微服务
```

---

## 三、前端技术选型

### 3.1 框架：Vue3 + TypeScript

| 框架 | 性能 | 学习曲线 | 生态 | 类型支持 | 推荐指数 |
|------|------|---------|------|---------|---------|
| **Vue3** | ⭐⭐⭐⭐ | ⭐⭐⭐⭐⭐ | ⭐⭐⭐⭐⭐ | ✅（TS 友好） | ⭐⭐⭐⭐⭐ |
| React | ⭐⭐⭐⭐⭐ | ⭐⭐⭐ | ⭐⭐⭐⭐⭐ | ✅ | ⭐⭐⭐⭐ |
| Angular | ⭐⭐⭐ | ⭐⭐ | ⭐⭐⭐⭐ | ✅ | ⭐⭐⭐ |

**选型理由：**
- 学习曲线平缓，开发效率高
- Composition API + TypeScript 体验优秀
- 生态完善（Vue Router、Pinia、Vite 均为同生态）
- 团队上手成本低

---

### 3.2 UI 组件库：Ant Design Vue

| 组件库 | 设计语言 | 组件丰富度 | 定制能力 | 推荐指数 |
|--------|---------|-----------|---------|---------|
| **Ant Design Vue** | 企业级（Ant Design） | ⭐⭐⭐⭐⭐ | ⭐⭐⭐⭐ | ⭐⭐⭐⭐⭐ |
| Element Plus | 企业级（Element） | ⭐⭐⭐⭐⭐ | ⭐⭐⭐⭐ | ⭐⭐⭐⭐ |
| Vuetify | Material Design | ⭐⭐⭐⭐ | ⭐⭐⭐ | ⭐⭐⭐ |
| Naive UI | 现代简洁 | ⭐⭐⭐ | ⭐⭐⭐⭐⭐ | ⭐⭐⭐ |

**选型理由：**
- Ant Design 设计语言成熟，适合企业级后台
- 组件丰富度最高，覆盖所有业务场景
- 定制能力强，支持主题定制
- 相比 Element Plus，设计风格更现代化

---

### 3.3 微前端架构：qiankun（Phase 1 引入）

| 方案 | 隔离性 | 性能 | Vite 支持 | 上手难度 | 社区活跃度 | 推荐指数 |
|------|--------|------|-----------|---------|-----------|---------|
| **qiankun** | 沙箱隔离 | ⭐⭐⭐⭐ | 需插件 | ⭐⭐⭐⭐ | ⭐⭐⭐⭐⭐ | ⭐⭐⭐⭐⭐ |
| Module Federation | 无隔离 | ⭐⭐⭐⭐⭐ | 需插件 | ⭐⭐⭐ | ⭐⭐⭐⭐⭐ | ⭐⭐⭐⭐ |
| wujie | 物理隔离 | ⭐⭐⭐⭐ | 需配置 | ⭐⭐⭐⭐ | ⭐⭐⭐ | ⭐⭐⭐ |
| micro-app | 沙箱隔离 | ⭐⭐⭐⭐ | **原生** | ⭐⭐⭐⭐⭐ | ⭐⭐⭐ | ⭐⭐⭐ |
| single-spa | 需自实现 | ⭐⭐⭐ | 需配置 | ⭐⭐ | ⭐⭐⭐⭐ | ⭐⭐⭐ |

**选型理由：**
- **社区最活跃**（Star 60k+），遇到问题容易找到答案
- 支持 Vue2/Vue3、React、Angular 混合技术栈
- 样式隔离（CSS Shadow DOM）、JS 沙箱（Proxy 隔离）
- 预加载机制，优化首屏加载
- 文档完善，中文社区友好
- 简历知名度高，面试官都认识

> ⚠️ **Phase 0 不用微前端。** 个人开发阶段，10 个页面以内的后台系统，Vue Router 单页应用更高效。微前端解决的是**多团队协作**问题，不是技术问题。Phase 1 拆微服务后引入 qiankun，面试时要主动说明"主要是演示架构思路，小团队不会这么做"。

> **适用规模**：个人 ❌ 不推荐 | 小团队 ⚠️ | 企业（3+ 前端团队）✅

---

### 3.4 状态管理：Pinia

| 方案 | Vue3 支持 | TypeScript | 性能 | 推荐指数 |
|------|----------|-----------|------|---------|
| **Pinia** | ✅（官方推荐） | ✅（原生支持） | ⭐⭐⭐⭐⭐ | ⭐⭐⭐⭐⭐ |
| Vuex | ✅（Vuex 4） | ⚠️（需配置） | ⭐⭐⭐ | ⭐⭐⭐ |

**选型理由：**
- Vue3 官方推荐的状态管理库
- TypeScript 原生支持，开发体验好
- 比 Vuex 更轻量，API 更简洁
- 支持模块化、动态注册

---

### 3.5 构建工具：Vite

| 工具 | 启动速度 | HMR | 生产构建 | 推荐指数 |
|------|---------|-----|---------|---------|
| **Vite** | ⭐⭐⭐⭐⭐（秒级） | ⭐⭐⭐⭐⭐ | ⭐⭐⭐⭐⭐（Rollup） | ⭐⭐⭐⭐⭐ |
| Webpack | ⭐⭐（分钟级） | ⭐⭐⭐ | ⭐⭐⭐⭐⭐ | ⭐⭐⭐⭐ |
| Rollup | ⭐⭐⭐ | ⭐⭐ | ⭐⭐⭐⭐⭐ | ⭐⭐⭐ |

**选型理由：**
- 开发环境启动速度快（秒级 vs 分钟级）
- 热更新（HMR）体验优秀
- 基于 ES Module，配置简单
- 生产构建使用 Rollup，打包优化好

---

## 四、基础设施选型

### 4.1 容器编排：Kubernetes

| 方案 | 功能完整性 | 学习曲线 | 社区 | 推荐指数 |
|------|-----------|---------|------|---------|
| **Kubernetes** | ⭐⭐⭐⭐⭐ | ⭐⭐ | ⭐⭐⭐⭐⭐ | ⭐⭐⭐⭐⭐ |
| Docker Swarm | ⭐⭐⭐ | ⭐⭐⭐⭐⭐ | ⭐⭐ | ⭐⭐⭐ |
| Nomad | ⭐⭐⭐⭐ | ⭐⭐⭐ | ⭐⭐⭐ | ⭐⭐⭐ |

**选型理由：**
- 容器编排事实标准
- 云原生生态核心组件
- 简历加分项（展示云原生能力）

---

### 4.2 数据库：MySQL + Redis

| 数据库 | 类型 | 适用场景 | 推荐指数 |
|--------|------|---------|---------|
| **MySQL** | 关系型 | 结构化数据（用户、权限、配置） | ⭐⭐⭐⭐⭐ |
| PostgreSQL | 关系型 | 复杂查询、JSON 字段 | ⭐⭐⭐⭐ |
| MongoDB | NoSQL | 非结构化数据（日志、模板内容） | ⭐⭐⭐ |
| **Redis** | 缓存 | 热点数据、分布式锁、会话存储 | ⭐⭐⭐⭐⭐ |
| Prometheus | 时序数据库 | 监控指标存储 | ⭐⭐⭐⭐⭐ |

**选型理由：**
- **MySQL**：关系型数据库事实标准，社区资源丰富
- **Redis**：缓存 + 分布式锁 + 会话存储，一库多用
- **Prometheus**：K8s 生态标配，监控指标存储

---

### 4.3 对象存储：MinIO

| 方案 | 成本 | S3 兼容 | K8s 部署 | 推荐指数 |
|------|------|---------|---------|---------|
| **MinIO** | 免费自建 | ✅ | ✅ | ⭐⭐⭐⭐⭐ |
| 腾讯云 COS | 按量付费 | ❌ | ✅ | ⭐⭐⭐⭐ |
| AWS S3 | 按量付费 | ✅ | ❌ | ⭐⭐⭐ |

**选型理由（MinIO）：**
- **开源免费**，兼容 S3 API，开发环境友好
- Kubernetes 原生部署，支持 Operator 模式
- 用于存储：模板文件、制品包、用户上传文件
- 后期可平滑迁移到云服务商对象存储（COS/S3）

---

### 4.4 消息队列：RabbitMQ

| 方案 | 性能 | 可靠性 | 学习曲线 | 推荐指数 |
|------|------|--------|---------|---------|
| **RabbitMQ** | ⭐⭐⭐⭐ | ⭐⭐⭐⭐⭐ | ⭐⭐⭐⭐ | ⭐⭐⭐⭐⭐ |
| Kafka | ⭐⭐⭐⭐⭐ | ⭐⭐⭐⭐ | ⭐⭐⭐ | ⭐⭐⭐⭐ |
| RocketMQ | ⭐⭐⭐⭐⭐ | ⭐⭐⭐⭐⭐ | ⭐⭐⭐ | ⭐⭐⭐ |
| NATS | ⭐⭐⭐⭐ | ⭐⭐⭐ | ⭐⭐⭐⭐⭐ | ⭐⭐⭐ |

**选型理由：**
- **RabbitMQ**：可靠的消息投递，适合订单、通知等场景
- 管理界面友好，调试方便
- 后期如需高吞吐（日志、监控），可引入 Kafka

---

### 4.5 日志方案：Zap → Fluent Bit → Loki

#### 完整日志链路

```
┌──────────────────┐     ┌──────────────────┐     ┌──────────────────┐
│  go-zero 微服务    │     │  Fluent Bit       │     │  Loki             │
│  (Uber Zap)      │────▶│  (DaemonSet)      │────▶│  (日志聚合)        │
│                  │     │                    │     │                    │
│  stdout → JSON   │     │  采集/解析/过滤    │     │  存储 + 索引       │
└──────────────────┘     └──────────────────┘     └──────────────────┘
   K8s /var/log/            每个节点一个 Pod          对象存储(S3/MinIO)
   containers/*.log
```

#### 日志采集器：Fluent Bit

| 方案 | 资源占用 | 性能 | K8s 原生 | 推荐指数 |
|------|---------|------|---------|---------|
| **Fluent Bit** | ⭐⭐⭐⭐⭐（< 1MB 内存） | ⭐⭐⭐⭐⭐ | ✅ | ⭐⭐⭐⭐⭐ |
| Fluentd | ⭐⭐⭐（> 40MB 内存） | ⭐⭐⭐⭐ | ✅ | ⭐⭐⭐ |
| Filebeat | ⭐⭐（> 30MB 内存） | ⭐⭐⭐⭐ | ⚠️ | ⭐⭐⭐ |
| Vector | ⭐⭐⭐⭐ | ⭐⭐⭐⭐⭐ | ⚠️ | ⭐⭐⭐ |

**选型理由（Fluent Bit）：**
- **极致轻量**，C 语言编写，内存占用 < 1MB
- Kubernetes 原生 DaemonSet 部署，自动采集所有 Pod 日志
- 支持多种输出（Loki、ES、Kafka），灵活可扩展
- 内置 JSON 解析器，可直接解析 Zap 输出的结构化日志

**DaemonSet 部署示意：**
```yaml
apiVersion: apps/v1
kind: DaemonSet
metadata:
  name: fluent-bit
  namespace: logging
spec:
  template:
    spec:
      containers:
      - name: fluent-bit
        image: fluent/fluent-bit:latest
        volumeMounts:
        - name: varlog
          mountPath: /var/log/containers
        - name: config
          mountPath: /fluent-bit/etc/
      volumes:
      - name: varlog
        hostPath:
          path: /var/log/containers
```

**Fluent Bit 输出配置（发送到 Loki）：**
```ini
[OUTPUT]
    Name          loki
    Match         *
    Host          loki.logging.svc.cluster.local
    Port          3100
    Labels        {job="fluent-bit", app="$kubernetes['labels']['app']"}
```

---

#### 日志存储：Loki

| 方案 | 资源占用 | 查询能力 | 集成难度 | 推荐指数 |
|------|---------|---------|---------|---------|
| **Loki** | ⭐⭐⭐⭐⭐（轻量） | ⭐⭐⭐ | ⭐⭐⭐⭐ | ⭐⭐⭐⭐⭐ |
| ELK | ⭐⭐（重） | ⭐⭐⭐⭐⭐ | ⭐⭐⭐ | ⭐⭐⭐⭐ |
| OTel Logs | ⭐⭐⭐⭐ | ⭐⭐⭐ | ⭐⭐⭐⭐⭐ | ⭐⭐⭐ |

**选型理由：**
- Grafana 生态原生集成，与 Prometheus 搭配使用
- 轻量级，只索引元数据（不索引日志内容）
- 查询语言 LogQL，学习成本低
- 适合 K8s 环境，资源占用低
- 日志内容存储到对象存储（MinIO/S3/COS），无限扩展

#### 运维 Agent 日志获取优化

为支持运维 Agent 以最小成本获取日志，采用**多层次日志获取策略**：

| 场景 | 数据源 | 延迟 | 成本 | 说明 |
|------|--------|------|------|------|
| **实时日志** | K8s Logs API | < 100ms | 零 | 直接读取容器 stdout |
| **历史日志** | Loki Query API | 秒级 | 低 | 结构化日志查询 |
| **链路追踪** | Jaeger Query API | 秒级 | 低 | 根因分析 |
| **指标数据** | Prometheus API | 秒级 | 低 | 关联分析 |

**Agent 专用日志接口设计：**
```go
// Agent 诊断日志服务
type AgentLogService struct {
    // 1. K8s Logs API - 实时日志（毫秒级）
    func GetRealtimeLogs(serviceName string) ([]string, error)
    
    // 2. Loki API - 历史日志（秒级）
    func GetHistoricalLogs(serviceName string, timeRange TimeRange) ([]LogEntry, error)
    
    // 3. Jaeger API - 链路追踪（秒级）
    func GetServiceTraces(serviceName string) ([]Trace, error)
    
    // 4. Prometheus API - 指标数据（秒级）
    func GetServiceMetrics(serviceName string) ([]Metric, error)
}
```

**日志格式要求（Agent 友好）：**
- 所有服务必须输出 **JSON 格式**结构化日志
- 必须包含 `traceID`、`spanID`、`service` 字段
- 支持 Agent 通过 LogQL 快速过滤：
  ```logql
  {app="user-service"} |= "error" | json | traceID="abc123"
  ```

---

## 五、安全与治理

### 5.1 认证授权：JWT + RBAC

| 方案 | 适用场景 | 复杂度 | 推荐指数 |
|------|---------|--------|---------|
| **JWT + RBAC** | 无状态认证 + 角色权限 | ⭐⭐ | ⭐⭐⭐⭐⭐ |
| OAuth2.0 | 第三方授权 | ⭐⭐⭐⭐ | ⭐⭐⭐⭐ |
| OIDC | SSO 单点登录 | ⭐⭐⭐⭐⭐ | ⭐⭐⭐ |
| ABAC | 基于属性的访问控制 | ⭐⭐⭐⭐ | ⭐⭐⭐ |

**选型理由：**
- **JWT**：无状态认证，适合微服务架构
- **RBAC**：Phase 0 只设**管理员 / 普通用户** 2 个角色，够演示认证和权限区分即可。Phase 1 再加细粒度权限点
- 后期可引入 OAuth2.0（第三方登录）或 OIDC（SSO）

---

### 5.2 服务治理

| 能力 | 方案 | 说明 |
|------|------|------|
| 限流 | go-zero 内置 middleware | 网关层 + 服务级别限流 |
| 熔断 | Sentinel / go-zero middleware | 服务降级、熔断保护 |
| 负载均衡 | 轮询 / 加权 | etcd + go-zero discov 插件 |
| 服务网格 | 暂不引入 | 现阶段太重，后期可考虑 Istio |

#### 服务容错具体设计（面试必问）

面试官追问"user-service 挂了，gateway 怎么处理？"时的标准答案：

**熔断（Circuit Breaker）**
```
统计窗口：10 秒
错误率阈值：50%（超过就熔断）
半开试探：熔断 30 秒后尝试 1 个请求，成功就恢复，失败继续熔断

gRPC 状态码映射：
  Unavailable / DeadlineExceeded → 计入错误
  InvalidArgument / NotFound → 不计入错误（不是服务故障）
```

**重试（Retry）**
```
最大重试次数：2
退避策略：指数退避（100ms → 200ms → 400ms）
可重试错误：Unavailable, ResourceExhausted
不可重试：Internal, DataLoss（写操作可能已成功）
```

**超时（Timeout）**
```
gateway → user-service：3 秒
gateway → platform-service：5 秒
user-service → MySQL：2 秒
gRPC Deadline 从请求 Context 自动传播
```

**兜底（Fallback）**
```
user-service 熔断时：
  gateway 返回降级响应：{"error":"service degraded","retry_after":30}
  前端展示兜底数据（缓存 5 分钟前的服务列表）
  不影响 platform-service 和 deploy-service 正常运行
```

> 面试话术："我特意做了熔断+重试+超时三级保护。核心思路是——宁可返回降级数据，也不让一个服务拖垮整个调用链。"

### 5.3 备份与灾备

| 数据 | 方案 | 频率 | 保留 |
|------|------|------|------|
| **MySQL** | 腾讯云 CDB 自动备份 + 手动导出到 COS | 每日 | 7 天 |
| **Harbor 镜像（Phase 2）** | Harbor 复制规则 → 异地 Registry | 实时 | 永久 |
| **etcd（云端自建）** | `etcdctl snapshot save` → COS | 每小时 | 30 天 |
| **Git 仓库** | GitHub 自带，无需额外处理 | - | 永久 |
| **Prometheus TSDB** | 不建议备份（重建成本低于恢复） | - | - |
| **Loki 日志** | 已存储在对象存储，自带冗余 | - | - |

> **铭凡环境**：MySQL 用 cron job 每日 `mysqldump` → MinIO。Kind 集群本身不存持久化数据，重建即恢复。

---

## 六、架构全景图

```
┌─────────────────────────────────────────────────────────────────────────┐
│                    仓库层（Multi-Repo）                                   │
│  forge-proto（公开）   │  forge（主仓库）│  forge-infra（IaC）│  forge-agent │
│  - API 契约          │  - 后端 + 前端       │  - Terraform     │  - AI 运维     │
│  - buf 治理          │  - Helm Charts       │  - Ansible       │                │
└─────────────────────────────────────────────────────────────────────────┘
                                    │
                                    ▼
┌─────────────────────────────────────────────────────────────────────────┐
│                          前端（qiankun 微前端）                            │
├─────────────────────────────────────────────────────────────────────────┤
│  Shell（主应用）                                                         │
│  ├── service-mgmt/   （服务管理）                                        │
│  ├── template-center/（模板中心）                                        │
│  ├── deploy-center/  （部署中心）                                        │
│  ├── monitor/        （监控大屏）                                        │
│  └── settings/       （系统设置）                                        │
└─────────────────────────────────────────────────────────────────────────┘
                                    │
                                    ▼
┌─────────────────────────────────────────────────────────────────────────┐
│                        Nginx Ingress（TLS 终止 / 域名路由）               │
└─────────────────────────────────────────────────────────────────────────┘
                                    │
                                    ▼
┌─────────────────────────────────────────────────────────────────────────┐
│                       gateway-service（鉴权 / 限流 / gRPC ↔ HTTP）       │
└─────────────────────────────────────────────────────────────────────────┘
                                    │
              ┌─────────────────────┼─────────────────────┐
              ▼                     ▼                     ▼
┌──────────────────────┐ ┌──────────────────┐ ┌──────────────────────┐
│  user-service        │ │ service-service  │ │ deploy-service        │
│  - JWT 认证           │ │ - 服务管理        │ │ - K8s 部署            │
│  - RBAC 权限          │ │ - 代码仓库        │ │ - 灰度发布            │
└──────────────────────┘ └──────────────────┘ └──────────────────────┘
              │                     │                     │
              └─────────────────────┼─────────────────────┘
                                    │
         ┌──────────────────────────┼──────────────────────────┐
         ▼                          ▼                          ▼
┌──────────────────┐  ┌──────────────────────┐  ┌──────────────────────┐
│  etcd (Go)       │  │  OpenTelemetry       │  │  Kubernetes          │
│  - 服务注册       │  │  - Trace / Metrics   │  │  - 容器编排           │
│  - 配置中心       │  │  - OTel Collector    │  │  - 自动扩缩容         │
└──────────────────┘  └──────────────────────┘  └──────────────────────┘
         │                     │                          │
         ▼              ┌──────┴──────┐                  ▼
┌──────────────────┐    ▼             ▼         ┌──────────────────────┐
│  MySQL + Redis  │  Jaeger        Prometheus  │  MinIO                │
│  - 业务数据      │  - 瀑布图       - 指标采集  │  - 模板文件            │
│  - 缓存 / 会话   │  - 拓扑图       - 时序存储  │  - 制品包              │
└──────────────────┘  └──────┬──────┘         └──────────────────────┘
                             │
                             ▼
                    ┌────────────────────────────────────────────────────┐
                    │              Grafana（统一可观测性门户）              │
                    │  ├── Prometheus（指标展示）                          │
                    │  ├── Jaeger（链路追踪 - 瀑布图）                      │
                    │  └── Loki（日志查询）                                │
                    └────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────────────┐
│                         日志采集管道                                      │
│  go-zero(Zap) → stdout → /var/log/containers → Fluent Bit(DaemonSet) → Loki │
└─────────────────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────────────┐
│                    生产级 CI/CD 流水线                                     │
│                                                                          │
│  GitHub Actions → [Lint/Test/Build/SBOM/Trivy] → GHCR                       │
│                              │                                           │
│                              ▼                                           │
│  ArgoCD (GitOps) → Helm Charts → Argo Rollouts (Canary) → K8s           │
│                              │                                           │
│                              ▼                                           │
│  Dev (自动) → Staging (审批) → Prod (审批 + 灰度)                         │
└─────────────────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────────────┐
│                        运维 Agent（AI Agent）                             │
│  ├── K8s Logs API    → 实时日志（毫秒级）                                 │
│  ├── Loki Query API  → 历史日志（秒级）                                   │
│  ├── Jaeger Query API → 链路追踪（秒级）                                   │
│  └── Prometheus API  → 指标数据（秒级）                                    │
└─────────────────────────────────────────────────────────────────────────┘
```

---

## 七、技术栈总结

### 后端

| 组件 | 选型 | 理由 |
|------|------|------|
| 语言 | Go | 云原生首选 |
| 框架 | go-zero | 企业主流微服务框架 |
| API 协议 | gRPC + HTTP | 高性能内部 RPC + 对外调试友好 |
| 协议治理 | buf（forge-proto 仓库） | 代码生成、规范检查、向后兼容 |
| ORM | GORM v2 | Go 生态标准 |
| 数据库迁移 | golang-migrate | 纯 SQL，向上/向下迁移 |
| 日志组件 | Uber Zap | 高性能结构化日志 |
| 注册配置 | etcd（Go 编写，Kind 自带） | 100% Go 栈，Raft 共识 |
| 网关 | Nginx Ingress + gateway-service | 双层架构 |

### 可观测性

| 组件 | 选型 | 理由 |
|------|------|------|
| 采集标准 | OpenTelemetry | CNCF 标准 |
| 链路追踪 | Jaeger（瀑布图 + 拓扑图） | go-zero 原生集成 |
| 指标采集 | Prometheus | K8s 生态标配 |
| 日志采集 | Fluent Bit (DaemonSet) | 极致轻量 |
| 日志存储 | Loki | Grafana 生态，轻量 |
| 告警 | AlertManager | Prometheus 生态，支持钉钉/企微/邮件 |
| 可视化 | Grafana | 统一门户（Metrics + Trace + Logs）|

### 基础设施

| 组件 | 选型 | 理由 |
|------|------|------|
| 容器编排 | Kubernetes | 事实标准 |
| 数据库 | MySQL + Redis | 关系型 + 缓存 |
| 对象存储 | MinIO | S3 兼容，免费自建 |
| 消息队列 | RabbitMQ | 可靠投递 |

### CI/CD 与安全

| 组件 | 选型 | Phase | 适用规模 |
|------|------|-------|---------|
| CI 引擎 | GitHub Actions | Phase 1 | 个人 ✅ / 小团队 ✅ |
| 镜像仓库 | GHCR（Phase 0）→ Harbor（Phase 2） | 个人零运维 / 企业完整能力 |
| GitOps 引擎 | ArgoCD | Phase 1 | 个人 ✅ / 小团队 ✅ / 企业 ✅ |
| 部署模板 | Helm Chart | Phase 1 | 个人 ✅ / 小团队 ✅ / 企业 ✅ |
| 渐进交付 | Argo Rollouts | Phase 3 | 小团队 ✅ / 企业 ✅ |
| 漏洞扫描 | Trivy (CI) + GHCR | Phase 0 | 个人 ✅ / 小团队 ✅ / 企业 ✅ |
| SBOM | Syft | Phase 2 | 企业级（合规审计） |
| 镜像签名 | Cosign (OIDC 无密钥) | Phase 2 | 企业级（安全审计） |
| 构建溯源 | SLSA Level 3 | Phase 3 | 企业级（安全审计） |
| 准入控制 | Kyverno | Phase 3 | 企业级（多租户安全） |
| 密钥管理 | External Secrets + Vault | Phase 3 | 企业级（多环境密钥轮转） |
| 依赖更新 | Renovate | Phase 3 | 个人 ✅ / 小团队 ✅ |

### 前端

| 组件 | 选型 | 理由 |
|------|------|------|
| 框架 | Vue3 + TypeScript | 开发效率高 |
| UI 组件库 | Ant Design Vue | 企业级设计 |
| 微前端 | qiankun（Phase 1 引入） | Phase 0 用 Vue Router |
| 状态管理 | Pinia | Vue3 官方推荐 |
| 构建工具 | Vite | 秒级启动 |

---

### 过度设计预警表

> **架构师的价值不在于能用多少个组件，而在于知道什么时候不用哪些组件。**

| 组件 | 原方案 | 实际决策 | 原因 |
|------|--------|---------|------|
| **6 个微服务** | Phase 0 全拆 | Phase 0 只做 3 个 | 1 人开发，运维成本远超收益 |
| **qiankun 微前端** | Phase 0 引入 | Phase 1 引入 | 10 页后台不需要，先单页上线 |
| **Cosign 签名** | Phase 0 CI 集成 | Phase 2 规划 | 没有外部攻击面，签名无实际价值 |
| **SBOM 生成** | Phase 0 CI 集成 | Phase 2 规划 | 无合规审计需求 |
| **SLSA 溯源** | Phase 0 CI 集成 | Phase 3 规划 | 个人项目无供应链攻击风险 |
| **Kyverno** | Phase 0 部署 | Phase 3 规划 | 准入控制在没有多租户时是摆设 |
| **Vault** | Phase 0 部署 | Phase 3 规划 | K8s Secret + Sealed Secrets 够用 |
| **运维 Agent** | 概念化模块 | Phase 3 + 具体实现路径 | Phase 0~2 先做核心链路 |
| **Argo Rollouts** | Phase 0 引入 | Phase 2 引入 | Phase 0 用 ArgoCD 原生 Sync 即可 |
| **Harbor** | Phase 0 自建 | Phase 2 自建 | Phase 0 用 GHCR，零运维，Phase 2 展示企业能力 |

> 面试话术："这份设计是理想化的企业级全景图。实际开发中，我已明确标注了哪些组件是规划、哪些已砍掉。Phase 0 演示版本只实现核心的认证、部署、可观测性三条链路。"

---

## 八、后续计划

> **开发策略**：Demo 优先，4 周出可演示版本投简历。Phase 0 用 3 个核心微服务演示架构模式，Phase 1 按需扩展。

### Phase 0：简历 Demo（第 1~4 周）🎯 立即投简历

**目标**：面试 30 分钟能演示完整链路——微服务 + 可观测性 + CI/CD + GitOps。3 个核心服务足够展示架构思维。

**仓库与基础设施（第 1 周）**
- [ ] 创建 forge-proto 仓库（buf + Go/TS 代码生成）
- [ ] 创建 forge 主仓库
- [ ] 配置 GHCR 镜像仓库（GitHub 原生，零部署）
- [ ] 部署 ArgoCD（GitOps 引擎）
- [ ] 编写 Helm Chart 模板
- [ ] 使用 Kind 自带 etcd（服务注册 + 配置中心），部署 MySQL + Redis

**3 个核心微服务（第 1~2 周）**
- [ ] **gateway-service**：JWT 鉴权 + gRPC ↔ HTTP 转换 + 限流
- [ ] **user-service**：注册/登录（JWT 签发）+ RBAC 权限
- [ ] **platform-service**：服务 CRUD + K8s 部署对接 + 模板管理（聚合 logic/template/deploy 三个模块）
- [ ] GitHub Actions：Push → Build → GHCR → ArgoCD Sync（3 个服务独立触发）

> 面试话术："Phase 0 用 3 个微服务演示核心架构模式——gateway 展示网关层，user 展示认证服务，platform 聚合业务能力。等团队规模扩大再按康威定律垂直拆成 6 个。"

**README 中直接加这段（面试官读到会给你加 10 分）**：
> 关于微服务拆分的思考：
> - 5 人以下团队：单体架构足够，不要为了微服务而微服务
> - 5~20 人团队：3~5 个微服务，按业务边界拆分
> - 20 人以上团队：6~10 个微服务，按康威定律对应团队组织架构
> 
> 微服务不是银弹，拆分核心原则：**高内聚、低耦合、按变更频率拆**。

**前端（第 2.5 周）**  ← Vue Router 单页，用现成模板加速
- [ ] 基于 **Ant Design Vue Pro** 模板搭建，直接改接口地址
- [ ] Vue Router 单页应用（Phase 0 不拆微前端）
- [ ] 登录页 + 服务列表 + 部署页面
- [ ] **注册中心控制面板**（etcd 可视化，1 天）：
  - 实时服务列表 + 健康状态（Vue3 + WebSocket 监听 etcd Watch 事件）
  - 填补 etcd 无原生 UI 的短板，展示前端 + 后端 + K8s 三重能力
- [ ] **部署流水线可视化**（1 天）：
  - 展示 ArgoCD 同步状态、最近部署历史、回滚按钮
  - 类似腾讯云 TKE 的部署控制台效果
- [ ] 集成 forge-proto TypeScript 类型

> 💡 不要从零写前端。Ant Design Vue Pro 已内置登录页、布局、菜单、表格、表单，1 天就能出成品。

**可观测性（第 3 周）**  ⭐ 面试核心卖点

- [ ] Prometheus + Grafana（指标采集 + 3 个核心 Dashboard）
  - **服务概览面板**：QPS、成功率、P50/P95 延迟
  - **链路追踪面板**：Jaeger 瀑布图嵌入，traceID 蓝色可点击链接
  - **部署流水线面板**：最近 10 次部署状态、版本、耗时
- [ ] Jaeger 瀑布图 + 拓扑图
  - **必须演示跨服务调用**：`gateway → user → platform`
  - 瀑布图上能看到 3 个服务的 Span，每个 Span 的耗时
- [ ] Fluent Bit + Loki（日志聚合 + LogQL 查询）
- [ ] Grafana 统一门户（Metrics + Trace + Logs 三合一）
- [ ] traceID 注入 + 日志点击跳转 Jaeger 瀑布图

> 💡 Grafana Dashboard 是面试第一印象。打开面板，面试官眼睛一亮就赢了 80%。Jaeger 必须演示跨服务调用链，这才是"全链路追踪"。

**CI/CD 安全基线（第 3.5 周）**  ← 只做 Trivy，其余放后续
- [ ] Trivy 漏洞扫描（CI 中集成，Critical/High 阻断）
- [ ] Cosign/SBOM/SLSA/Kyverno → **Phase 2-3 规划**

**打磨与文档（第 4 周）**

- [ ] README 必含 4 项（面试官直接打开看的）：
  - **架构图**（draw.io 画的，90% 个人项目没有）
  - **技术选型对比表**（证明你是选型不是跟风）
  - **踩坑记录**（3~5 个真实踩坑经历，边做边补）：
    ```
    踩坑 1：go-zero gRPC 调用 traceID 透传问题
      问题：跨服务调用时 traceID 丢失，链路追踪断了
      解决：自定义中间件，从 metadata 提取 traceID 注入 context，实现全链路透传

    踩坑 2：Fluent Bit 采集多行日志合并问题
      问题：异常堆栈日志被拆成多条
      解决：配置 multiline 解析规则，按时间戳自动合并多行日志

    踩坑 3：ArgoCD 同步权限问题
      问题：Helm 部署时没有权限创建 ServiceAccount
      解决：给 ArgoCD Application 配置正确的 RBAC 权限
    ```
    > ⚠️ 99% 的个人项目 README 没有踩坑记录，你有就直接和其他人拉开差距
  - **后续规划**（Phase 1~3，体现长远思考）
- [ ] Grafana Dashboard 美化
- [ ] 录制 5 分钟演示视频（放 README 最前面）：
  ```
  0:00-0:30  架构介绍
  0:30-1:30  登录→服务列表→一键部署
  1:30-3:00  Grafana：指标→日志→跳 Jaeger 瀑布图
  3:00-4:00  ArgoCD GitOps 部署演示
  4:00-5:00  技术栈总结
  ```
- [ ] 部署到云服务器，绑定域名
- [ ] 📬 **投简历**

---

### Phase 1：功能扩展 + 架构演进（第 5~8 周）

- [ ] platform-service 垂直拆分为 service-service + deploy-service + template-service（3→6）
- [ ] 引入 qiankun 微前端（配合微服务拆分解耦）
- [ ] 部署 Harbor（企业级镜像仓库，展示漏洞扫描 + 镜像复制）
- [ ] MinIO 部署（模板文件 + 制品存储）
- [ ] RabbitMQ 部署 + 异步任务
- [ ] 权限系统完整化（RBAC 角色 + 权限点）
- [ ] 部署中心：一键部署 → K8s（对接 ArgoCD API，灰度发布）
- [ ] **K8s Operator（可选，2~3 天，极加分）**：
  - 用 `controller-runtime`（Go）写一个简单的 Operator
  - 监听自定义资源 `Application`，自动创建 Deployment + Service + Ingress
  - 面试价值：证明你对 K8s 控制循环（Informer → WorkQueue → Reconcile）的理解远超普通用户
- [ ] 模板中心：模板管理 + MinIO 存储
- [ ] 前端各模块细化（表单校验、加载态、错误处理）
- [ ] API 文档（OpenAPI/Swagger）

---

### Phase 2：可观测性与供应链加固（第 9~12 周）

- [ ] Argo Rollouts Canary 灰度发布
- [ ] Prometheus AlertManager 告警规则
- [ ] Renovate 自动依赖升级
- [ ] Syft SBOM 生成
- [ ] Cosign 镜像签名（OIDC 无密钥）
- [ ] idp-infra 仓库：Terraform IaC
- [ ] Grafana Dashboard 模板化导出

---

### Phase 3：生产级安全与高级功能（第 13~24 周）

- [ ] SLSA Level 3 构建溯源
- [ ] Kyverno 准入控制（拒绝未签名/高危镜像）
- [ ] External Secrets Operator + Vault 密钥管理
- [ ] 多环境串联（Dev → Staging → Prod）
- [ ] 审批流程（ArgoCD Approval + 变更单）
- [ ] 成本核算
- [ ] **注册中心控制面板**：前端展示 etcd 服务列表、健康状态、Watch 实时推送
- [ ] 运维 Agent（Phase 3）——具体实现路径：
  - **LLM**：OpenAI API / DeepSeek API（成本 <¥50/月）
  - **触发**：Prometheus AlertManager Webhook → Agent 收到告警 → 调用 LLM 分析日志
  - **能力**：
    - 一句话诊断 Pod CrashLoopBackOff（拉最近 50 行日志 + Prometheus 指标 → LLM 输出根因 + 修复建议）
    - 不承诺自动修复（太危险），只输出诊断报告 + 推荐 kubectl 命令
  - **Demo 场景**：手动触发一个假告警 → Agent 10 秒内返回诊断报告 → 在 Grafana 面板展示

---

### 时间线总览

```
Week 1~2   ████████  3 个核心微服务 + CI/CD 跑通
Week 3     ████████  可观测性全套（杀手锏）
Week 4     ████████  打磨 + 投简历
────────────────────────────────────────  🎯 Demo 版完成（够面 20-25k）
Week 5~8   ░░░░░░░░  3→6 微服务 + qiankun + 功能完善
Week 9~12  ░░░░░░░░  安全加固（SBOM/签名/灰度/告警）
Week 13~24 ░░░░░░░░  生产级安全（Kyverno/Vault/Agent）
────────────────────────────────────────  🏆 生产级完整版
```

---

## 九、测试策略

### 测试层次

| 层次 | 工具 | 范围 | 覆盖率目标 |
|------|------|------|-----------|
| **单元测试** | Go testing + testify | service 层、dao 层 | ≥ 70% |
| **集成测试** | Go testing + testcontainers-go | API 层（含真实 MySQL/Redis）| ≥ 50% |
| **API 测试** | go testify HTTP test | RESTful + gRPC 接口 | 核心接口 100% |
| **前端测试** | Vitest + Vue Test Utils | 组件 + Store | ≥ 60% |
| **端到端测试** | Playwright | 关键用户路径 | 核心流程 100% |

### 测试工具选型

| 工具 | 用途 | 推荐指数 |
|------|------|---------|
| **testify** | Go 断言库，社区标准 | ⭐⭐⭐⭐⭐ |
| **testcontainers-go** | 集成测试容器管理（MySQL/Redis）| ⭐⭐⭐⭐⭐ |
| **gomock / mockery** | Mock 生成 | ⭐⭐⭐⭐ |
| **Vitest** | 前端单元测试（Vite 原生）| ⭐⭐⭐⭐⭐ |
| **Playwright** | 端到端测试 | ⭐⭐⭐⭐⭐ |

**选型理由：**
- **testcontainers-go**：在 Docker 中启动真实 MySQL/Redis 进行集成测试，无需 Mock 数据库
- **Vitest**：与 Vite 共享配置，零额外配置成本
- **Playwright**：相比 Cypress，对微前端架构支持更好

---

## 十、CI/CD 与 GitOps

### 10.1 整体流水线

```
┌─────────────────────────────────────────────────────────────────────────┐
│                        CI 阶段（GitHub Actions）                           │
├─────────────────────────────────────────────────────────────────────────┤
│  PR 提交                                                                 │
│    ├── golangci-lint / eslint                                           │
│    ├── go test -race（testcontainers-go 真实 MySQL）                      │
│    ├── 覆盖率门槛（< 70% 阻断合并）                                        │
│    └── Renovate 自动依赖升级 PR                                           │
│                                                                          │
│  PR 合并到 main                                                           │
│    ├── 多阶段 Docker Build（BuildKit + GH Cache）                          │
│    ├── Syft 生成 SBOM                                                     │
│    ├── Trivy 漏洞扫描（Critical/High 阻断）                                  │
│    ├── Cosign 签名（Phase 2）                                               │
│    └── Push to GHCR（GitHub 原生，零部署）                                    │
│                                                                          │
└─────────────────────────────────────────────────────────────────────────┘
                                    │
                                    ▼
┌─────────────────────────────────────────────────────────────────────────┐
│                      CD 阶段（ArgoCD + Helm）                              │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                          │
│  Dev 集群                                                                 │
│    └── Push 即自动部署（ArgoCD 检测 GHCR tag 变更）                           │
│                                                                          │
│  Staging/Prod 集群（Phase 2 Harbor 引入后）                                  │
│    ├── Harbor 镜像复制（dev → staging → prod）                               │
│    ├── 人工审批（ArgoCD UI 一键 Promote）                                    │
│    └── Argo Rollouts Canary（20% → 50% → 100%，自动回滚）                     │
│                                                                          │
└─────────────────────────────────────────────────────────────────────────┘
```

### 10.2 CI：GitHub Actions

#### 触发策略

```yaml
# .github/workflows/ci-gateway-service.yaml
name: CI - Gateway Service

on:
  pull_request:
    paths:
      - 'backend/api/gateway/**'
      - 'backend/proto/**'
      - 'backend/pkg/**'      # 共享库变动触发所有服务

jobs:
  lint:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: golangci/golangci-lint-action@v6
        with: { working-directory: backend/api/gateway }

  test:
    needs: lint
    runs-on: ubuntu-latest
    services:
      mysql:
        image: mysql:8.0
        env: { MYSQL_ROOT_PASSWORD: test, MYSQL_DATABASE: test }
    steps:
      - uses: actions/setup-go@v5
        with: { go-version: '1.22' }
      - run: go test -v -race -coverprofile=coverage.out ./...
        working-directory: backend/api/gateway

  build-and-push:
    needs: test
    if: github.ref == 'refs/heads/main'
    runs-on: ubuntu-latest
    permissions:
      contents: read
      id-token: write          # Cosign OIDC 签名
      packages: write
    steps:
      - uses: docker/build-push-action@v6
        with:
          context: backend/api/gateway
          push: true
          tags: ghcr.io/${{ github. }}/gateway-logic:${{ github.sha }}
          cache-from: type=gha
          cache-to: type=gha,mode=max

      - uses: aquasecurity/trivy-action@master
        with:
          image-ref: ghcr.io/${{ github. }}/gateway-logic:${{ github.sha }}
          format: sarif
          severity: CRITICAL,HIGH
          exit-code: 1          # 高危阻断
```

#### 容器构建（多阶段 Dockerfile）

```dockerfile
# Stage 1: Build
FROM golang:1.22-alpine AS builder
WORKDIR /app
COPY go.mod go.sum ./
RUN go mod download
COPY . .
RUN CGO_ENABLED=0 go build -ldflags="-s -w" -o /server ./cmd/server/

# Stage 2: Runtime（distroless, ~15MB）
FROM gcr.io/distroless/static-debian12:nonroot
COPY --from=builder /server /server
USER nonroot:nonroot
ENTRYPOINT ["/server"]
```

### 10.3 CD：ArgoCD + Helm

| 选型 | 理由 |
|------|------|
| **GitOps 引擎** | ArgoCD —— Web UI 完善，多集群支持，60% 市场份额 |
| **部署模板** | Helm Chart —— 模板化、版本化、values 按环境覆盖 |
| **渐进交付** | Argo Rollouts —— Canary/Blue-Green 声明式，自动回滚 |
| **镜像更新** | ArgoCD Image Updater —— Phase 0 不启用（GHCR tag 固定）；Phase 2 Harbor 引入后启用 |

#### ArgoCD 对比 FluxCD

| 维度 | ArgoCD | FluxCD |
|------|--------|--------|
| **Web UI** | ✅ 完善 | ⚠️ 2026 年新出，仍不如 ArgoCD |
| **多集群** | ✅ ApplicationSets | ❌ 需 Git 结构组织 |
| **资源占用** | 1~4 GB | < 500 MB |
| **安全模型** | 集中式 RBAC + SSO | 去中心化、攻击面更小 |

**选型：ArgoCD**——生产级 IDP 需要多环境、多集群、审批流，ArgoCD 更匹配。

> **适用规模**：个人 Demo ✅ | 小团队 ✅ | 企业级 ✅

#### Argo Rollouts 渐进式发布

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Rollout
metadata:
  name: gateway-service
spec:
  replicas: 5
  strategy:
    canary:
      steps:
        - setWeight: 20          # 20% 流量 → v2
        - pause: {duration: 5m}
        - setWeight: 50           # 50%
        - pause: {duration: 5m}
        - setWeight: 100          # 全量
      analysis:
        templates:
          - templateName: error-rate-check
          - templateName: latency-check
```

### 10.4 镜像仓库：GHCR（Phase 0）→ Harbor（Phase 2）

| 方案 | 成本 | 运维 | 漏洞扫描 | 推荐 |
|------|------|------|---------|------|
| **GHCR (Phase 0)** | 免费 | **零运维** ✅ | Trivy (CI 侧) | ⭐⭐⭐⭐⭐ |
| Harbor (Phase 2) | 自建 2.5GB 内存 | 需维护 | 内置 Trivy | ⭐⭐⭐⭐ |

**选型决策**：
- **Phase 0**：用 **GitHub Container Registry (ghcr.io)**——代码在 GitHub，推送镜像零配置，免费额度 500MB 绰绰有余，零运维
- **Phase 2**：自建 Harbor 以演示企业级镜像管理能力——漏洞扫描、镜像复制、Cosign 签名验证

> 面试话术："Phase 0 我选择了 GHCR 而不是自建 Harbor，因为个人项目不需要镜像复制的复杂度。GHCR 和 GitHub Actions 无缝集成，Trivy 在 CI 侧完成漏洞扫描，效果一样但运维成本降到零。Phase 2 会补上 Harbor 来展示完整的企业级镜像管理。"

> **适用规模**：GHCR 个人 ✅ | Harbor 小团队 ✅ / 企业 ✅

### 10.5 安全供应链

| 环节 | 工具 | 状态 | 说明 |
|------|------|------|------|
| **漏洞扫描** | Trivy (CI) | ✅ Phase 0 实现 | Critical/High 阻断 CI |
| **SBOM 生成** | Syft | 📋 Phase 2 | 记录所有依赖，审计必备 |
| **镜像签名** | Cosign (OIDC 无密钥) | 📋 Phase 2 | GitHub OIDC 自动签发，不存私钥 |
| **构建溯源** | SLSA Level 3 | 📋 Phase 3 | 记录谁、何时、用何工具构建 |
| **准入控制** | Kyverno | 📋 Phase 3 | 拒绝未签名/高危漏洞镜像 |

> Phase 0 面试技巧：主动说明"安全供应链目前只实现了 Trivy 扫描，Cosign/SBOM/SLSA 已规划但未实现"，展示自知之明。

### 10.6 环境策略

| 环境 | 触发方式 | 审批 | 数据库 | 分支 |
|------|---------|------|--------|------|
| **dev** | PR 合并自动部署 | 无 | 独立 MySQL | main |
| **staging** | 手动 Promote | ✅ 1 人 | 脱敏生产数据 | main |
| **prod** | 手动 Promote | ✅ 2 人 | 生产 MySQL | main tag |

**分支策略：Trunk-Based Development**

```
main (唯一长期分支)
  └── feat/user-auth    ← 短生命周期（< 2 天）
  └── fix/gateway-oom   ← 快速修复
  └── feat/rollout-xxx  ← 大功能用 Feature Flag 渐进上线
```

### 10.7 密钥管理：External Secrets Operator

```yaml
apiVersion: external-secrets.io/v1beta1
kind: ExternalSecret
metadata:
  name: db-password
spec:
  refreshInterval: 1h
  secretStoreRef:
    name: vault-backend
  target:
    name: db-secret
  data:
    - secretKey: password
      remoteRef:
        key: idp/prod/mysql/password   # 从 Vault 拉取，Git 中无明文
```

| 方案 | 适用场景 | 推荐 |
|------|---------|------|
| **External Secrets Operator + Vault** | 生产级，Phase 4 引入 | ⭐⭐⭐⭐⭐ |
| Sealed Secrets | 轻量替代，无需 Vault | ⭐⭐⭐⭐ |

### 10.8 CI/CD 组件总览

| 环节 | 选型 | Phase |
|------|------|-------|
| **CI 引擎** | GitHub Actions | Phase 0 |
| **镜像仓库** | GHCR（Phase 0）→ Harbor（Phase 2） | Phase 0 |
| **GitOps 引擎** | ArgoCD | Phase 0 |
| **部署模板** | Helm Chart | Phase 0 |
| **容器构建** | Docker BuildKit + GH Cache | Phase 0 |
| **漏洞扫描** | Trivy (CI) | Phase 0 |
| **协议治理** | buf (forge-proto 仓库) | Phase 0 |
| **渐进交付** | Argo Rollouts | Phase 2 |
| **SBOM** | Syft | Phase 2 |
| **镜像签名** | Cosign (OIDC 无密钥) | Phase 2 |
| **依赖更新** | Renovate | Phase 2 |
| **构建溯源** | SLSA Level 3 | Phase 3 |
| **准入控制** | Kyverno | Phase 3 |
| **密钥管理** | External Secrets + Vault | Phase 3 |

---

*文档版本：v3.3*  
*最后更新：2026-06-14*
*变更：etcd 控制面板（WebSocket Watch）、部署流水线可视化、K8s Operator（Informer/WorkQueue/Reconcile）*

---

## 附录 A：开发环境配置

### A.1 硬件

| 项目 | 规格 |
|------|------|
| 主机 | 铭凡 UM890 Pro |
| CPU | 8 核 16 线程 |
| 内存 | 64 GB |
| 磁盘 | 1 TB（可外接扩展） |
| OS | Windows 11 + WSL2 |

### A.2 WSL2 配置

```ini
# C:\Users\<用户名>\.wslconfig
[wsl2]
memory=24GB
processors=12
swap=0
```

### A.3 Kind 集群

```bash
# kind-config.yaml
kind: Cluster
apiVersion: kind.x-k8s.io/v1alpha4
nodes:
  - role: control-plane
  - role: worker
  - role: worker

# 创建
kind create cluster --name idp --config kind-config.yaml

# Nginx Ingress（Kind 专用）
kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/main/deploy/static/provider/kind/deploy.yaml
```

### A.4 开发环境资源消耗（保守估算）

| 组件 | 内存 | 说明 |
|------|------|------|
| WSL2 + Docker | 3 GB | `.wslconfig` 限制 24 GB |
| Kind 3 Node | 2.5 GB | 1 Control + 2 Worker |
| etcd（Kind 自带） | 128 MB | 复用 K8s 控制面 etcd，零额外部署 |
| MySQL + Redis | 2.5 GB | 单副本 |
| GHCR | 0 GB | GitHub 原生，零本地资源 |
| ArgoCD | 1 GB | 单实例 |
| Jaeger | 1.5 GB | 100% 采样，Elasticsearch 后端 |
| Prometheus | 2 GB | 15 天保留 |
| Loki + Fluent Bit | 0.5 GB | 7 天保留 |
| Grafana | 0.3 GB | 单实例 |
| 3 个 go-zero 微服务 | 1.5 GB | gateway + user + platform |
| RabbitMQ + MinIO | 1 GB | Phase 1 引入 |
| Windows 系统 | 6 GB | IDE + Chrome + 终端 |
| **保守估算** | **~25 GB** | 64 GB 总量，剩余 39 GB |
| **全套满载** | **~30 GB** | 所有组件同时高负载，剩余 34 GB |

> ⚠️ 实际使用中，大部分组件大部分时间在 idle 状态，日常内存占用约 18~22 GB。高峰期（CI 构建 + Jaeger 写入 + Prometheus 压缩）才会到 30 GB。64 GB 总量绰绰有余。

### A.5 开发 → 上云流程

```
铭凡 Kind 集群（dev）
  │  Helm values: values-dev.yaml
  │  镜像仓库: GHCR（Phase 0）
  │  CI: GitHub Actions → GHCR → ArgoCD → Kind
  │
  │  验证通过
  │
  ▼
腾讯云 TKE 集群（prod）
  │  Helm values: values-prod.yaml（同一套 Chart）
  │  镜像仓库: Harbor 或 TCR（Phase 2）
  │  MySQL/Redis: 云托管版
  │  CI: GitHub Actions → Harbor → ArgoCD → TKE
```
