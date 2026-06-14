# IDP 开发计划 v2.0（platform 优先策略）

> **目标**：4 周内完成 Phase 0 简历 Demo，具备完整演示能力后立即投简历。

---

## 0. 本地环境与成本评估

### 0.0 命名体系

> 详见 `docs/forge-architecture.md` 1.1.1 节。

| 层级 | 命名规则 | 示例 |
|------|----------|------|
| **项目名称** | `forge` | Forge IDP |
| **GitHub 组织** | `mirai-zen` | github.com/mirai-zen |
| **仓库名** | `forge-{service}` | `forge-gateway`, `forge-user`, `forge-platform` |
| **协议仓库** | `forge-proto` | github.com/mirai-zen/forge-proto |
| **K8s Namespace** | `forge-{env}` | `forge-dev`, `forge-prod` |
| **Service (K8s)** | `forge-{service}` | `forge-gateway`, `forge-user` |
| **Docker Image** | `ghcr.io/{org}/{service}` | `ghcr.io/mirai-zen/forge-gateway` |

### 0.1 硬件配置

| 项目 | 规格 |
|------|------|
| 主机 | 铭凡 UM890 Pro |
| CPU | 8 核 16 线程 |
| 内存 | 64 GB |
| 磁盘 | 1 TB SSD（可外接扩展） |
| OS | Windows 11 + WSL2 (Ubuntu) |
| K8s | Kind 集群（1 Control + 2 Worker） |

### 0.2 WSL2 配置

```ini
# C:\Users\<用户名>\.wslconfig
[wsl2]
memory=24GB
processors=12
swap=0
```

### 0.3 Phase 0 实际资源消耗（优化后）

> 相比最初估算，Nacos→etcd 省了 1GB，Harbor→GHCR 省了 2.5GB。

| 组件 | 内存 | 说明 |
|------|------|------|
| WSL2 + Docker | 3 GB | `.wslconfig` 限制 24 GB |
| Kind 3 Node | 2.5 GB | 1 Control + 2 Worker |
| etcd（Kind 自带） | 128 MB | 复用 K8s 控制面 etcd，零额外部署 |
| MySQL | 2 GB | 单副本，1 GB InnoDB Buffer |
| Redis | 256 MB | 单副本 |
| ArgoCD | 1 GB | 单实例 |
| Jaeger | 1.5 GB | 100% 采样 |
| Prometheus | 2 GB | 15 天保留 |
| Loki + Fluent Bit | 0.5 GB | 7 天保留 |
| Grafana | 0.3 GB | 单实例 |
| 3 个 go-zero 微服务 | 1.5 GB | gateway + user + platform，各 ~500MB |
| Windows 系统 | 6 GB | IDE + Chrome + 终端 |
| **日常实际** | **~22 GB** | 大部分组件 idle 状态 |
| **满载峰值** | **~26 GB** | CI 构建 + Jaeger 写入同时发生 |
| **剩余** | **~38 GB** | 绰绰有余 |

> ⚠️ 之前估算 ~30GB 是因为包含了 Harbor (2.5GB) 和 Nacos (1GB)。换 GHCR + etcd 后实际只需 ~22GB，64GB 总量从"勉强"变成"从容"。

### 0.4 上云成本评估

#### 方案 A：演示用（面试期间开，之后关）

| 资源 | 规格 | 月费（腾讯云） |
|------|------|:--:|
| 轻量应用服务器 | 4c8g 80GB SSD | ~120 |
| 域名 + SSL | 1 年 | ~10 |
| **月费** | | **~130 元** |

部署方式：单机 K3s + 全套组件。适合面试时打开域名演示，平时关掉省钱。

#### 方案 B：长期生产（Phase 4 完整版）

| 资源 | 规格 | 月费（腾讯云） |
|------|------|:--:|
| TKE 节点 × 3 | 4c8g | ~1,000 |
| MySQL CDB | 2c4g | ~300 |
| Redis | 1GB 标准版 | ~128 |
| CLB 公网 | 1 个 | ~30 |
| 云盘 500GB | SSD | ~175 |
| 带宽 | 5 Mbps | ~125 |
| **月费** | | **~1,758 元** |

#### 成本对比

| | 铭凡（你的） | 云演示版 | 云生产版 |
|---|:---:|:---:|:---:|
| 月费 | ~50（电费） | ~130 | ~1,758 |
| 年费 | ~600 | ~1,560 | ~21,000 |
| 公网访问 | ❌ 需穿透 | ✅ 有域名 | ✅ 有域名 |
| 高可用 | ❌ 单机 | ❌ 单机 | ✅ 多节点 |
| 适合 | 日常开发 | 面试演示 | 长期服务 |

> **建议**：铭凡一直用，面试前一周花 130 开云演示版、绑域名、录视频。面试结束评估是否有必要长期上云。

### 0.5 工具安装

```bash
# 确认 Kind 集群正常运行
kubectl get nodes    # 3 个 Ready 状态

# 确认 etcd 可用（Kind 自带）
kubectl exec -it kind-control-plane -- etcdctl endpoint health

# 安装 goctl
go install github.com/zeromicro/go-zero/tools/goctl@latest

# 安装 buf
brew install bufbuild/buf/buf

# 确认 Docker Desktop 运行
docker ps
```

---

## 0.6 日常关机/开机流程

```bash
# 关机前（不需要停 Kind，Docker Desktop 关了就自动停）
# 数据都在 Docker Volume 里，不会丢

# 开机后
# Docker Desktop 自动启动
kubectl get nodes   # Kind 集群自动恢复
# MySQL/Redis/etc 如果是 K8s Pod，也会自动恢复
# 需要手动恢复的：端口转发
kubectl port-forward svc/argocd-server -n argocd 8080:443 &
kubectl port-forward svc/prometheus-grafana -n monitoring 3000:80 &
```
```

---

## Phase 0 功能规格

> 详细方案见 [`docs/services/platform-api.md`](services/platform-api.md)

### 功能概览

| 模块 | 功能 | 方案文档 |
|------|------|---------|
| 项目管理 | 创建项目（模板 + 自动仓库）、项目列表、项目详情 | [platform-api](services/platform-api.md) |
| 服务管理 | 创建服务（模板 + 自动 PR）、服务详情 | [platform-api](services/platform-api.md) |
| 部署管理 | 新建部署（GH Actions）、实时状态查询（ArgoCD） | [platform-api](services/platform-api.md) |

### 技术方案总览

| 环节 | 方案 | 关键技术 |
|------|------|---------|
| 创建项目 | GitHub API 创建仓库 + 渲染项目模板 | `go-github` + `text/template` |
| 创建服务 | 渲染模板 → GitHub API 提交 PR | `text/template` + CreateFile/PullRequest |
| 模板存储 | `deploy/templates/` 目录 | `.tpl` 文件 + `template.yaml` |
| 新建部署 | GitHub Actions `workflow_dispatch` | POST actions dispatches |
| 部署执行 | GH Actions → push GHCR → ArgoCD 同步 | Docker + Helm + ArgoCD |
| 状态查询 | 实时调 ArgoCD/K8s API（不存库） | GET ArgoCD application status |
| 环境隔离 | K8s Namespace：forge-dev / forge-staging / forge-prod | 每环境独立 values.yaml |

### 不在 Phase 0 范围

| 功能 | 说明 |
|------|------|
| 部署回滚 | Phase 1 |
| 自定义环境 | 固定三环境 |
| 用户认证 | Day 8 补位 |
| 多服务模板 | 先做一个 go-zero 模板 |

---

## Week 1：platform 核心 + gateway + GitOps 流水线

---

## Week 1：platform 核心 + gateway + GitOps 流水线

> **策略**：跳过 user-service，直接从 platform-service（IDP 核心）起步。Auth 先用硬编码，核心链路跑通后再补。

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
  ├── Git Tag（v1.3.0，语义化版本）
  └── GitHub Release
```

---

### Day 0：仓库初始化 + CI/CD 配置 ✅ 已完成

#### 创建 forge-proto 协议仓库

```bash
mkdir forge-proto && cd forge-proto

# 按服务独立 go.mod（与 forge 对齐）
mkdir -p user/gen && cd user/v1 && go mod init github.com/mirai-zen/forge-proto/user && cd ../..
mkdir -p gateway/gen && cd gateway/v1 && go mod init github.com/mirai-zen/forge-proto/gateway && cd ../..
mkdir -p platform/gen && cd platform/v1 && go mod init github.com/mirai-zen/forge-proto/platform && cd ../..

# Go workspace
go work init ./user ./gateway ./platform

# buf.gen.yaml（buf 代码生成配置）

git init && git add . && git commit -m "init: proto repo"
git remote add origin git@github.com:mirai-zen/forge-proto.git
git push -u origin main
```

#### 创建 forge 后端 Monorepo ✅

```bash
mkdir forge && cd forge

# 三个服务各自独立 go.mod
mkdir -p user/cmd user/internal/{handler,logic,svc,config} user/configs
cd user && go mod init github.com/mirai-zen/forge/user && cd ..
mkdir -p gateway/cmd gateway/internal/{handler,logic,svc,config} gateway/configs
cd gateway && go mod init github.com/mirai-zen/forge/gateway && cd ..
mkdir -p platform/cmd platform/internal/{handler,logic,svc,config} platform/configs
cd platform && go mod init github.com/mirai-zen/forge/platform && cd ..

# 部署配置
mkdir -p deploy/charts/{user,gateway,platform}/templates deploy/argocd
go work init ./user ./gateway ./platform

git init && git add . && git commit -m "init: forge monorepo"
git remote add origin git@github.com:mirai-zen/forge.git
git push -u origin main
```

#### 仓库创建清单

```
github.com/mirai-zen/
├── forge-proto          ✅ 公开仓库，Phase 0
├── forge                ✅ 私有仓库，Phase 0
├── forge-web            ✅ 私有仓库，Phase 0
└── （其余仓库按需创建）
```

---

### Day 1：platform.proto + platform-service CRUD（IDP 核心）

**protocol 层：**
```bash
cd forge-proto

# 编写 platform/platform.proto
# - ServiceManagement (CRUD)
# - DeployManagement (触发部署、查询状态)
# - TemplateManagement (模板 CRUD)

buf generate
git tag platform/v0.1.0 && git push --tags && cd ../..
```

**platform.proto 接口定义：**
```protobuf
syntax = "proto3";
package platform.v1;
option go_package = "github.com/mirai-zen/forge-proto/platform/gen;platformv1";

service Platform {
  // 服务管理
  rpc CreateService(CreateServiceReq) returns (CreateServiceResp);
  rpc ListServices(ListServicesReq) returns (ListServicesResp);
  rpc GetService(GetServiceReq) returns (GetServiceResp);
  rpc DeleteService(DeleteServiceReq) returns (DeleteServiceResp);

  // 部署管理
  rpc DeployService(DeployServiceReq) returns (DeployServiceResp);
  rpc GetDeployStatus(GetDeployStatusReq) returns (GetDeployStatusResp);
  rpc ListDeployments(ListDeploymentsReq) returns (ListDeploymentsResp);
}

message CreateServiceReq {
  string name = 1;
  string description = 2;
  string repository_url = 3;
  string branch = 4;
}

message CreateServiceResp {
  uint64 id = 1;
  string message = 2;
}

message ListServicesReq {
  string status = 1;   // active / inactive / all
  int32 page = 2;
  int32 page_size = 3;
}

message ListServicesResp {
  repeated ServiceInfo services = 1;
  int32 total = 2;
}

message ServiceInfo {
  uint64 id = 1;
  string name = 2;
  string description = 3;
  string status = 4;
  string created_at = 5;
}

// ... 其余 message 定义
```

**实现层（forge/platform/）：**
```bash
cd forge/platform

# 引入 proto 依赖
go get github.com/mirai-zen/forge-proto/platform@v0.1.0

# 搭建 go-zero 骨架
# cmd/main.go         → 启动入口
# internal/handler/   → HTTP → gRPC 转换
# internal/logic/     → 业务编排
# internal/svc/       → 依赖注入（MySQL / etcd）
# internal/config/    → 配置结构体
```

**platform-service 目录结构：**
```
forge/platform/
├── go.mod / go.sum
├── cmd/
│   └── main.go
├── internal/
│   ├── handler/
│   │   └── platformhandler.go    # HTTP handler
│   ├── logic/
│   │   └── platformlogic.go      # 业务逻辑
│   ├── svc/
│   │   └── svc.go           # ServiceContext
│   └── config/
│       └── config.go
├── Dockerfile
└── configs/
    └── platform.yaml.example
```

**今日产出：**
- ✅ platform.proto 定义完成（服务管理 + 部署管理）
- ✅ platform-service 框架搭建 + 编译通过
- ✅ `POST /api/platform/services` 创建服务接口可调用
- ✅ `GET /api/platform/services` 服务列表可查询

---

### Day 2：MySQL 集成 + gateway 路由

**MySQL + Redis 部署：**
```bash
# Kind 集群部署基础设施
kubectl create namespace forge-dev
kubectl apply -f deploy/k8s/infra/mysql.yaml
kubectl apply -f deploy/k8s/infra/redis.yaml

# goctl 生成 Model
goctl model mysql ddl -src platform.sql -dir internal/model

# etcd 注册（复用 Kind 自带 etcd）
# configs/platform.yaml.example
Etcd:
  Hosts:
    - kind-control-plane:2379
  Key: platform.rpc
```

**gateway-service（auth-lite 模式）：**
```bash
cd forge/gateway

# gateway 职责：
# 1. 路由转发（/api/platform/* → platform-service）
# 2. 简单鉴权（先硬编码 token，无需 user-service）
# 3. traceID 注入
# 4. 请求日志

go get github.com/mirai-zen/forge-proto/gateway@v0.1.0
```

**auth-lite 实现：**
```go
// gateway 中间件：硬编码 admin token
const AdminToken = "forge-admin-demo-token"

func AuthMiddleware(next http.HandlerFunc) http.HandlerFunc {
    return func(w http.ResponseWriter, r *http.Request) {
        token := r.Header.Get("Authorization")
        if token != "Bearer "+AdminToken {
            http.Error(w, "unauthorized", 401)
            return
        }
        next(w, r)
    }
}
```

**今日产出：**
- ✅ MySQL + Redis 在 Kind 集群中运行
- ✅ platform-service 读写 MySQL（服务 CRUD 数据持久化）
- ✅ gateway 路由转发 `GET /api/platform/services` 可调通
- ✅ 硬编码鉴权可用（等后续替换为正式 JWT）

---

### Day 3：ArgoCD + Helm + CI 流水线（GitOps）

**部署 ArgoCD：**
```bash
kubectl create namespace argocd
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

# 获取初始密码
kubectl get secret argocd-initial-admin-secret -n argocd -o jsonpath="{.data.password}" | base64 -d

# 端口转发（演示用）
kubectl port-forward svc/argocd-server -n argocd 8080:443 &
```

**编写 Helm Chart：**
```bash
mkdir -p deploy/charts/platform/templates
# templates/: deployment.yaml, service.yaml, configmap.yaml
# values.yaml / values-dev.yaml

# ArgoCD Application
# deploy/argocd/platform.yaml → 监听 GitHub 仓库 deploy/charts/platform/
```

**GitHub Actions CI（platform 服务）：**
```yaml
# .github/workflows/platform-ci.yml
name: Platform CI
on:
  push:
    paths:
      - 'platform/**'
jobs:
  build:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-go@v5
        with: { go-version: '1.25' }
      - run: cd platform && go vet ./... && go test ./... && go build ./...
      - uses: docker/login-action@v3
        with:
          registry: ghcr.io
          username: ${{ github.actor }}
          password: ${{ secrets.GITHUB_TOKEN }}
      - uses: docker/build-push-action@v5
        with:
          context: ./platform
          push: true
          tags: ghcr.io/mirai-zen/forge-platform:${{ github.sha }}
```

**今日产出：**
- ✅ ArgoCD Web UI 可访问
- ✅ `helm install platform deploy/charts/platform` 部署成功
- ✅ Git Push → GitHub Actions → 镜像 push GHCR → ArgoCD 自动同步 → Pod Running
- ✅ GitOps 核心链路打通

---

### Day 4：可观测性三合一（Grafana + Jaeger + Loki）

**一键部署可观测性栈：**
```bash
# Prometheus + Grafana
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm install prometheus prometheus-community/kube-prometheus-stack -n monitoring --create-namespace

# Jaeger（链路追踪）
helm repo add jaegertracing https://jaegertracing.github.io/helm-charts
helm install jaeger jaegertracing/jaeger -n monitoring

# Loki Stack（日志）
helm repo add grafana https://grafana.github.io/helm-charts
helm install loki grafana/loki-stack -n monitoring \
  --set fluent-bit.enabled=true
```

**验证三步联动：**
```bash
# 1. 发请求 → 拿到 traceID
curl -H "Authorization: Bearer forge-admin-demo-token" \
     http://localhost/api/platform/services

# 2. Grafana → Explore → Loki → 搜 traceID → 看到日志
# 3. 点击日志中的 traceID → 跳转 Jaeger 瀑布图
```

**Grafana Dashboard（3 个核心面板）：**
1. 服务概览：QPS / 延迟 / 错误率 / CPU / 内存
2. Jaeger 瀑布图嵌入：网关 → platform 调用链
3. 部署历史：最近 N 次部署状态

**今日产出：**
- ✅ Grafana `http://localhost:3000` 可访问
- ✅ Jaeger `http://localhost:16686` 瀑布图可见
- ✅ Loki 日志可 LogQL 查询
- ✅ 日志中 traceID 蓝色链接 → 点击跳转 Jaeger
- ✅ 三合一联动：Metrics + Trace + Logs 一体化

---

### Day 5：Vue 前端 MVP（控制面板）

**脚手架搭建：**
```bash
git clone https://github.com/pure-admin/vue-pure-admin forge-web
cd forge-web && npm install

# Ant Design Vue 组件库已内置
# 硬编码 token 到 axios interceptor
```

**三个核心页面：**

| 页面 | 路由 | 功能 |
|------|------|------|
| **Dashboard** | `/` | 概览卡片：服务数、部署数、健康率 |
| **服务管理** | `/services` | 服务列表 + 搜索 + 新增/删除 + 一键部署 |
| **部署历史** | `/deployments` | 最近部署记录 + 状态标签 |

**axios interceptor（auth-lite）：**
```typescript
// src/api/config.ts
const TOKEN = 'forge-admin-demo-token'
api.interceptors.request.use(config => {
  config.headers.Authorization = `Bearer ${TOKEN}`
  return config
})
```

**今日产出：**
- ✅ 前端跑起来，3 个页面可导航
- ✅ 服务管理页：展示 platform-service 返回的服务列表
- ✅ 一键部署按钮：前端 → gateway → platform → ArgoCD
- ✅ 完整演示链路：登录（跳过）→ 服务列表 → 一键部署 → 流水线可视化

---

## Week 2：前端打磨 + user-service 补位

### Day 6-7：前端增强 + etcd 可视化

**注册中心控制面板：**
```vue
<!-- src/views/registry/index.vue -->
<template>
  <a-tree :tree-data="serviceTree" />
  <a-tag v-for="svc in services"
         :color="svc.healthy ? 'green' : 'red'">
    {{ svc.name }} - {{ svc.status }}
  </a-tag>
</template>
```

**部署流水线可视化：**
```vue
<!-- src/views/deploy/index.vue -->
<a-steps>
  <a-step status="finish" title="构建" />
  <a-step status="finish" title="推送" />
  <a-step status="process" title="部署中" />
  <a-step status="wait" title="运行中" />
</a-steps>
```

**今日产出：**
- ✅ etcd 服务树实时刷新（WebSocket）
- ✅ 部署流水线步骤可视化
- ✅ 部署回滚按钮

### Day 8：user-service 补位（替换 auth-lite）

```bash
cd forge-proto
# 编写 user/user.proto（注册/登录）
buf generate
git tag user/v0.1.0 && git push --tags

cd forge/user
go get github.com/mirai-zen/forge-proto/user@v0.1.0
```

**user-service 实现：**
- 注册（username + password + email → MySQL）
- 登录（返回 JWT token）
- gateway 中间件替换为真实 JWT 校验

**今日产出：**
- ✅ `POST /api/user/register` 用户注册
- ✅ `POST /api/user/login` 返回 JWT
- ✅ gateway 从 auth-lite 切换到真实 JWT 鉴权
- ✅ 完整 3 服务链路：`gateway → user → platform`

### Day 9-10：前端登录页 + 打磨

**登录页：**
```vue
<!-- src/views/login/index.vue -->
<a-form>
  <a-input v-model:value="username" />
  <a-input-password v-model:value="password" />
  <a-button @click="login">登录</a-button>
</a-form>
<!-- 调 POST /api/user/login → 存 JWT → 跳转 Dashboard -->
```

**打磨清单：**
- 登录页接入真实 user-service
- Dashboard 数据接入 Grafana 截图
- 部署页对接 ArgoCD API 状态查询
- 全局 loading / error 处理

---

## Week 3：可观测性全套（面试核心）

### Day 11：Prometheus + Grafana

```bash
# 一行部署（kube-prometheus-stack Helm Chart）
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm install prometheus prometheus-community/kube-prometheus-stack -n monitoring --create-namespace

# Grafana 初始密码
kubectl get secret prometheus-grafana -n monitoring -o jsonpath="{.data.admin-password}" | base64 -d
```

**Grafana 三个 Dashboard（面试必看）：**
1. **服务概览面板**：QPS、成功率、P50/P95 延迟、CPU/内存
2. **链路追踪面板**：Jaeger 瀑布图嵌入、traceID 蓝色超链接
3. **部署流水线面板**：最近 10 次部署、版本号、耗时、触发人

> ⚠️ Dashboard 必须好看！字体统一、颜色有逻辑（绿=健康、黄=警告、红=异常）、面板对齐

**今日产出：**
- ✅ `http://localhost:3000` 打开 Grafana
- ✅ 3 个 Dashboard 可展示

### Day 12：Jaeger + 跨服务调用链

```bash
helm repo add jaegertracing https://jaegertracing.github.io/helm-charts
helm install jaeger jaegertracing/jaeger -n monitoring
```

**跨服务 traceID 透传验证：**
```bash
# 发一个请求
curl -H "Authorization: Bearer $TOKEN" http://localhost/api/services

# 在 Gateway 日志中找到 traceID
kubectl logs gateway-service-xxx | grep traceID

# 打开 Jaeger → 粘贴 traceID → 看到：
# gateway-service (10ms) → user-service (5ms) → platform-service (25ms)
```

**今日产出：**
- ✅ Jaeger 瀑布图可见 3 个服务的 Span
- ✅ 从 Gateway 日志复制 traceID → Jaeger 一键跳转
- ✅ Grafana Dashboard 中嵌入 Jaeger iframe

### Day 13-14：Loki + 日志联动

```bash
helm repo add grafana https://grafana.github.io/helm-charts
helm install loki grafana/loki-stack -n monitoring \
  --set fluent-bit.enabled=true \
  --set promtail.enabled=false
```

**日志联动验证：**
```bash
# Grafana → Explore → Loki
# LogQL: {app="gateway-service"} |= "error"

# 点击日志中的 traceID → 自动跳转 Jaeger 瀑布图
```

**今日产出：**
- ✅ Fluent Bit DaemonSet 运行（每个 Node 一个 Pod）
- ✅ Loki 接收日志 + LogQL 可查询
- ✅ 日志中 traceID 蓝色链接 → 点击跳转 Jaeger
- ✅ 完整三合一：Grafana 中 Metrics + Trace + Logs 都可查

---

## Week 4：打磨 + 文档 + 投简历

### Day 15：README 四件套

```markdown
# Forge - 云原生内部开发者平台

![架构图](./docs/architecture.png)   ← draw.io 画的

## 技术选型对比表
| 技术 | 备选方案 | 为什么选这个 |
|-----|---------|------------|
| go-zero | Kratos/Gin | 企业采用率最高，内置工具链完整 |
...

## 踩坑记录
### 1. go-zero gRPC 调用 traceID 透传
问题：跨服务调用时 traceID 丢失
解决：自定义中间件从 metadata 提取 traceID 注入 context

### 2. Fluent Bit 多行日志合并
...

## 后续规划
Phase 1-3（参见 docs/forge-architecture.md）
```

### Day 16：Grafana Dashboard 美化

- 统一 Panel 间距、字体、颜色
- 给每个 Panel 加描述
- 截图放到 README 里

### Day 17：Demo 视频

```
0:00-0:30  架构介绍（draw.io 图 + 口述）
0:30-1:30  登录 → 服务列表 → 一键部署 → 30 秒看到 Pod Running
1:30-2:30  注册中心控制面板：etcd 服务树实时刷新
2:30-3:30  Grafana：指标 → 日志（搜 traceID）→ Jaeger 瀑布图
3:30-4:30  ArgoCD：Git Push → 自动同步 → 部署流水线可视化
4:30-5:00  技术栈总结
```

**录制工具**：OBS（免费）或 macOS 自带的 QuickTime

### Day 18：云服务器部署

```bash
# 腾讯云/阿里云一台 4c8g 服务器
# 安装 K3s（比 Kind 更适合单机生产）
curl -sfL https://get.k3s.io | sh -

# 部署同一套 Helm Charts（values-prod.yaml）
# 配置域名 + SSL（Let's Encrypt）
```

### Day 19-20：投简历 + 准备面试

- 简历项目栏写："Forge - 云原生内部开发者平台（IDP）"，附 GitHub 链接 + Demo 视频链接
- 准备 6 个面试问答：
  1. "为什么选 go-zero 不是 Kratos？"
  2. "为什么 etcd 不是 Nacos？"
  3. "服务容错怎么做的？"（熔断/重试/超时/兜底 → 张嘴就来）
  4. "traceID 怎么透传的？"（中间件 → metadata → context）
  5. "GitOps 流程是什么？"（Push → GHCR → ArgoCD → K8s）
  6. "这个项目最大的挑战是什么？"（选一个踩坑记录展开）

---

## 工时总计

```
Day 1-2    ████████████  platform-service + MySQL + gateway 路由
Day 3      ██████        ArgoCD + Helm + GitOps CI 流水线
Day 4      ██████        可观测性三合一（Grafana + Jaeger + Loki）
Day 5      ██████        Vue 前端 MVP（服务管理 + 一键部署）
Day 6-7    ████████████  前端增强（etcd 可视化 + 流水线可视化）
Day 8      ██████        user-service 补位（替换 auth-lite）
Day 9-10   ████████████  前端登录页 + 打磨
Day 11-14  ████████████  可观测性全套（对标原 Week 3）
Day 15-20  ████████████  打磨 + 投简历
────────────────────────────────────────
核心亮点：Day 3 即可演示 GitOps 完整链路，Day 5 即可演示全栈 IDP
```

---

## 每日检查清单

每天关机前确认：

```bash
# ✅ platform-service CRUD 可用
# ✅ gateway 路由转发正常
# ✅ ArgoCD 可见 + Git Push 自动同步
# ✅ Grafana / Jaeger / Loki 可访问
# ✅ 前端可演示完整链路
# ✅ user-service JWT 鉴权正常（Day 8 起）
```

---

*文档版本：v2.0*
*日期：2026-06-15*
