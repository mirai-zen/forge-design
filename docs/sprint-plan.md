# IDP 开发计划（Day 1 → Week 4）

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

## Week 1：基础设施 + user-service 端到端

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

### Day 0：仓库初始化 + CI/CD 配置

#### 创建 forge-proto 协议仓库

```bash
mkdir forge-proto && cd forge-proto

# 按服务独立 go.mod（与 forge 对齐）
mkdir -p user/gen
cd user/v1 && go mod init github.com/mirai-zen/forge-proto/user && cd ../..

mkdir -p gateway/gen
cd gateway/v1 && go mod init github.com/mirai-zen/forge-proto/gateway && cd ../..

mkdir -p platform/gen
cd platform/v1 && go mod init github.com/mirai-zen/forge-proto/platform && cd ../..

# Go workspace
go work init ./user ./gateway ./platform

# buf.gen.yaml（buf 代码生成配置）
# （详见 forge-architecture.md 1.4 节）

git init && git add . && git commit -m "init: proto repo"
git remote add origin git@github.com:mirai-zen/forge-proto.git
git push -u origin main
```

#### 创建 forge 后端 Monorepo

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

# Go workspace（本地开发）
go work init ./user ./gateway ./platform

git init && git add . && git commit -m "init: forge monorepo"
git remote add origin git@github.com:mirai-zen/forge.git
git push -u origin main
```

#### 仓库创建清单

```
github.com/mirai-zen/
├── forge-proto          ✅ 公开仓库，Phase 0
├── forge         ✅ 私有仓库，Phase 0
├── forge-web            ✅ 私有仓库，Phase 0
└── （其余仓库按需创建）
```

### Day 1：user.proto + user-service 端到端

**protocol 层：**
```bash
cd forge-proto

# 编写 user/user.proto（注册/登录）
option go_package = "github.com/mirai-zen/forge-proto/user/gen;userv1";

buf generate
git tag user/v0.1.0 && git push --tags && cd ../..
```

**实现层（forge/user/）：**
```bash
cd forge/user

# 引入 proto 依赖（只拉 user proto，不拉全量）
go get github.com/mirai-zen/forge-proto/user@0.1.0

# 基础文件
touch cmd/main.go
touch internal/handler/user.go
touch internal/logic/user.go
touch internal/user.go
touch internal/config/config.example.yaml
```

**user-service 目录结构：**

message RegisterResponse {
    string user_id = 1;
    string message = 2;
}

message LoginRequest {
    string username = 1;
    string password = 2;
}

message LoginResponse {
    string token = 1;           // JWT
    int64 expires_at = 2;
}
```

```bash
buf generate
git tag v0.1.0 && git push --tags
```

### Day 1-2：forge user-service 端到端

**实现层（forge/user/）：**
```bash
cd forge/user

# 引入 proto 依赖
go get github.com/mirai-zen/forge-proto@v0.1.0
```

**user-service 目录结构：**
```
forge/user/
├── go.mod
├── go.sum
├── cmd/
│   └── main.go              # 启动入口
├── internal/
│   ├── handler/             # HTTP 层：参数校验、请求绑定、返回响应
│   │   └── user.go
│   ├── logic/             # 业务逻辑层：用例编排
│   │   └── user.go
│   ├──           # 数据访问层：MySQL 查询
│   │   └── user.go
│   └── config/              # 配置映射结构体
│       └── config.go
├── internal/config/
│   └── user.yaml            # 运行时配置
├── Dockerfile
└── README.md
```

**今日产出：**
- ✅ forge-proto 仓库初始化 + v0.1.0 tag
- ✅ forge monorepo 创建（user/gateway/platform）
- ✅ user.proto 注册/登录接口定义
- ✅ `POST /api/user/register` 可调用（返回 user_id）

### Day 3：MySQL + Redis + etcd 集成

```bash
# Kind 集群部署 MySQL
kubectl create namespace idp
kubectl apply -f deploy/k8s/infra/mysql.yaml
kubectl apply -f deploy/k8s/infra/redis.yaml

# goctl 生成 Model
goctl model mysql ddl -src user.sql -dir internal/model

# etcd 注册中心配置（复用 Kind 自带 etcd）
# internal/config/config.example.yaml
Etcd:
  Hosts:
    - kind-control-plane:2379
  Key: user-service.rpc
```

**今日产出：**
- ✅ MySQL + Redis 运行
- ✅ user-service 写入 MySQL，JWT 签发成功
- ✅ user-service 注册到 etcd（`etcdctl get --prefix user-service` 可见）

### Day 4：ArgoCD + Helm Chart + CI

```bash
# 部署 ArgoCD
kubectl create namespace argocd
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

# 编写 Helm Chart
mkdir -p deploy/charts/user-logic/templates
# templates/: deployment.yaml, service.yaml, configmap.yaml
# values.yaml / values-dev.yaml

# ArgoCD Application
# deploy/argocd/user-service.yaml
```

**GitHub Actions CI（每服务独立 Workflow）：**
```
.github/workflows/user-ci.yml      # 监听 user/** 变更
├── build:  go vet → go test → go build
└── docker: docker build → push ghcr.io/mirai-zen/forge-user
```
> 详见 `forge-architecture.md` CI/CD 设计章节

**今日产出：**
- ✅ ArgoCD Web UI 可访问
- ✅ 手动 `helm install user-service` 成功
- ✅ `git push main` → GitHub Actions → 镜像 push 到 GHCR → ArgoCD 自动同步 → Pod Running

### Day 5：gateway-service + 跨服务调用

```bash
cd forge/gateway

# 引入 proto
go get github.com/mirai-zen/forge-proto@v0.1.0
```

**gateway 职责：**
1. JWT 鉴权（从 Header 提取 token → 调 user-service 验证）
2. 限流（go-zero 内置）
3. gRPC ↔ HTTP 转换
4. traceID 注入（从请求头提取 → 写入 context）

**今日产出：**
- ✅ `POST /api/user/login` → gateway → user-service → 返回 JWT
- ✅ `GET /api/services` → gateway 鉴权 → platform-service（下一步）

---

## Week 2：完整微服务 + 前端

### Day 6-7：platform-service

```bash
cd forge/platform
go get github.com/mirai-zen/forge-proto@v0.1.0
```

**platform-service 聚合三个模块：**
```
internal/
├── logic/
│   ├── logic/     # 服务 CRUD
│   ├── deploy/      # K8s 部署对接（kubectl apply）
│   └── template/    # 模板管理（存 MySQL TEXT 字段）
```

**今日产出：**
- ✅ `POST /api/services` 创建服务
- ✅ `GET /api/services` 服务列表
- ✅ `POST /api/services/:id/deploy` 触发部署
- ✅ 3 个服务调用链完整：`gateway → user → platform`

### Day 8：Jenkins 集成

等等，不用 Jenkins——用 **GitHub Actions 触发 Kind 集群内的部署**。

### Day 8：前端脚手架 + 登录页

```bash
# 用 vue-pure-admin 或 Ant Design Vue Pro 模板
git clone https://github.com/pure-admin/vue-pure-admin
cd vue-pure-admin
npm install

# 改写登录页
# src/views/login/index.vue → 调 POST /api/user/login
# 存 JWT 到 localStorage → axios interceptor 全局携带
```

**今日产出：**
- ✅ 前端跑起来
- ✅ 登录页可输入用户名密码
- ✅ 登录成功 → 跳转 Dashboard

### Day 9：服务列表 + 注册中心控制面板

**服务列表页：**
```vue
<!-- src/views/logic/index.vue -->
<template>
  <a-table :dataSource="services" :columns="columns" />
  <a-button @click="deploy(row)">一键部署</a-button>
</template>
```

**注册中心控制面板（etcd 可视化）：**
```vue
<!-- src/views/registry/index.vue -->
<template>
  <a-tree :tree-data="serviceTree" />  <!-- etcd 服务树 -->
  <a-tag v-for="svc in services" 
         :color="svc.healthy ? 'green' : 'red'">
    {{ svc.name }} - {{ svc.status }}
  </a-tag>
</template>
<script setup>
// WebSocket 连接后端 → 后端 etcd Watch → 推送到前端
const ws = new WebSocket('ws://gateway-logic/ws/registry')
ws.onmessage = (e) => { /* 解析 JSON，更新服务树 */ }
</script>
```

**今日产出：**
- ✅ 服务列表可展示、可搜索
- ✅ 注册中心面板：etcd 服务树 + 健康状态实时刷新

### Day 10：部署页面 + 一键部署

**部署页面：**
```vue
<!-- src/views/deploy/index.vue -->
<template>
  <a-form> <!-- 选择服务、版本号 → 点部署 --> </a-form>
  <a-modal> <!-- loading 弹窗：正在部署... → 部署成功！ --> </a-modal>
  <a-timeline> <!-- 最近 10 次部署记录 --> </a-timeline>
</template>
```

**部署流水线可视化：**
```vue
<template>
  <!-- 调用 ArgoCD API：GET /api/applications/:name -->
  <!-- 展示 sync status、last deployed、health -->
  <a-steps>
    <a-step status="finish" title="构建" />
    <a-step status="finish" title="推送" />
    <a-step status="process" title="部署中" />  <!-- ArgoCD Sync 状态 -->
    <a-step status="wait" title="运行中" />
  </a-steps>
  <a-button @click="rollback">回滚</a-button>
</template>
```

**今日产出：**
- ✅ 一键部署按钮 → 前端调 API → ArgoCD Sync → Pod 跑起来
- ✅ 部署流水线可视化：能看到当前部署在哪一步
- ✅ 回滚按钮可用

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
Day 1-5    ████████████  proto + user-service 端到端
Day 6-10   ████████████  platform + 前端三位一体
Day 11-14  ████████████  可观测性三合一
Day 15-20  ████████████  打磨 + 投简历
────────────────────────────────────────
总工时：~100 小时（周末两天 × 10 小时 × 5 周 + 工作日晚 2 小时 × 20 天）
如果你全职做：2 周。如果你周末做：5 周。
```

---

## 每日检查清单

每天关机前确认：

```bash
# ✅ user-service 可注册/登录
# ✅ gateway 可鉴权
# ✅ platform 可调通
# ✅ ArgoCD 可见
# ✅ Grafana 可访问
# ✅ Jaeger 瀑布图
# ✅ Loki 日志可查
# ✅ 前端可演示
```

---

*文档版本：v1.0*
*日期：2026-06-14*
