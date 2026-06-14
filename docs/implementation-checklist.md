# Forge - 落地执行检查清单

> 本文档记录方案落地时需要处理的所有实际执行细节，确保从构思到落地的每一步都有据可查。

---

## 0. 硬件与环境概览

### 0.1 开发机（MacBook M4 Pro）

| 项目 | 规格 | 用途 |
|------|------|------|
| 主机 | MacBook M4 Pro | 主要开发机 |
| OS | macOS Sonoma/Sequoia | 开发环境 |
| 网络 | 家庭/公司网络 | 日常开发 |

**待确认：**
- [ ] macOS 具体版本（Sonoma 14.x / Sequoia 15.x）
- [ ] 内存大小（18GB / 36GB / 36GB+）
- [ ] 磁盘剩余空间
- [ ] 是否已安装 Homebrew

### 0.2 测试机（铭凡 UM890 Pro）

| 项目 | 规格 | 用途 |
|------|------|------|
| 主机 | 铭凡 UM890 Pro | 测试/部署验证 |
| CPU | 8 核 16 线程 | 运行 Kind 集群 |
| 内存 | 64 GB | 承载全套组件 |
| 磁盘 | 1 TB SSD | 存储 |
| OS | Windows 11 + WSL2 (Ubuntu) | 开发环境 |
| K8s | Kind 集群（1 Control + 2 Worker） | 本地 K8s |

**待确认：**
- [ ] WSL2 Ubuntu 版本（22.04 / 24.04）
- [ ] Docker Desktop 版本
- [ ] 两台机器是否在同一个局域网
- [ ] 铭凡机器的公网 IP（固定/动态）

### 0.3 网络拓扑

```
MacBook M4 Pro (开发)
    │
    │ SSH / Git
    │
铭凡 UM890 Pro (测试)
    │
    │ Kind Cluster (3 Nodes)
    │   ├── Control Plane (etcd + API Server)
    │   ├── Worker Node 1
    │   └── Worker Node 2
    │
    │ 本地服务：
    │   ├── MySQL:3306
    │   ├── Redis:6379
    │   ├── ArgoCD:8080/8081
    │   ├── Grafana:3000
    │   ├── Jaeger:16686
    │   ├── Prometheus:9090
    │   └── Loki:3100
```

---

## 1. 开发环境配置

### 1.1 MacBook M4 Pro 环境

#### 1.1.1 基础工具安装

```bash
# Homebrew（如果未安装）
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

# 核心开发工具
brew install git
brew install go@1.22          # Go 1.22.x
brew install node@20          # Node.js 20 LTS
brew install docker           # Docker Desktop for Mac
brew install kubelet kubectl  # K8s CLI（或用 brew install kind kubectl）
brew install helm
brew install bufbuild/buf/buf
brew install tanzu-community-edition  # 或 Colima（替代 Docker Desktop）

# 可选：版本管理
brew install asdf             # 多版本管理
# 或
brew install nvm              # Node 版本管理
brew install goenv            # Go 版本管理
```

**待确认：**
- [ ] Docker Desktop vs Colima（Colima 更轻量，免费）
- [ ] Go 版本锁定（1.22 / 1.23）
- [ ] Node.js 版本锁定（20 LTS / 22）

#### 1.1.2 IDE 配置

```bash
# VS Code 扩展推荐
# Go (golang.go) - Go 语言支持
# TypeScript + JavaScript (Microsoft) - TS 支持
# Vue - Vue3 语法高亮
# Ant Design Vue Snippets - 组件库快捷方式
# Error Lens - 行内错误提示
# GitLens - Git 增强
# Draw.io Integration - 架构图绘制
# YAML / JSON / Dockerfile - 格式支持
```

**待确认：**
- [ ] VS Code 还是 GoLand（GoLand 收费，VS Code 免费）
- [ ] 是否需要安装 Vue 语言服务器（`vue-language-server`）

#### 1.1.3 SSH 配置

```bash
# ~/.ssh/config
Host mirai-zen
    HostName github.com
    User git
    IdentityFile ~/.ssh/id_ed25519

Host mingfan-test
    HostName <铭凡机器IP>
    User <用户名>
    IdentityFile ~/.ssh/id_ed25519
```

**待确认：**
- [ ] SSH 密钥类型（ed25519 / rsa）
- [ ] GitHub Token 还是 SSH Key 推送代码
- [ ] 铭凡机器的 IP 地址（局域网 IP / 公网 IP）

### 1.2 铭凡 UM890 Pro 环境

#### 1.2.1 WSL2 基础工具

```bash
# Ubuntu WSL2
sudo apt update && sudo apt upgrade -y
sudo apt install -y git curl wget jq yq
sudo apt install -y docker.io
sudo systemctl enable docker
sudo systemctl start docker
sudo usermod -aG docker $USER

# 核心工具
curl -Lo ./kind https://kind.sigs.k8s.io/dl/v0.23.0/kind-linux-amd64
chmod +x kind && sudo mv kind /usr/local/bin/

curl -Lo ./helm.tar.gz https://get.helm.sh/helm-v3.14.0-linux-amd64.tar.gz
tar -xzf helm.tar.gz && sudo mv linux-amd64/helm /usr/local/bin/

curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
chmod +x kubectl && sudo mv kubectl /usr/local/bin/
```

#### 1.2.2 WSL2 资源配置

```ini
# C:\Users\<用户名>\.wslconfig
[wsl2]
memory=24GB
processors=12
swap=0
localhostForwarding=true
```

**待确认：**
- [ ] WSL2 Ubuntu 版本
- [ ] Docker Desktop for Windows 还是 WSL2 内置 Docker
- [ ] 是否需要安装 Go/Node 在 WSL2 中

### 1.3 双机协作流程

```bash
# 方案 A：Mac 开发 → Git Push → 铭凡 Pull 测试
git push origin main
# 铭凡机器：
git pull origin main
kind delete cluster && kind create cluster
kubectl apply -f deploy/k8s/

# 方案 B：Mac 开发 → SSH 到铭凡直接部署
ssh mingfan-test "cd /path/to/project && git pull && kind delete cluster && kind create cluster"

# 方案 C：GitHub Actions 自动部署（推荐）
# Mac Push → GitHub Actions → 自动部署到铭凡 Kind
```

**推荐：方案 C**（GitHub Actions 自动部署，符合 GitOps 理念）

---

## 2. 项目初始化

### 2.1 仓库策略决策

> **关键决策：Monorepo 起步还是 Multi-repo 起步？**

| 方案 | 优点 | 缺点 | 推荐 |
|------|------|------|------|
| **Monorepo 起步** | 开发简单，一次 PR 改所有服务 | 仓库大，协议治理弱 | ✅ Phase 0 推荐 |
| **Multi-repo 起步** | 协议独立，符合企业架构 | 开发复杂，依赖管理麻烦 | Phase 1 拆分 |

**推荐方案：Phase 0 用 Monorepo，Phase 1 拆分 Multi-repo**

```
# Phase 0: Monorepo 结构
github.com/mirai-zen/forge
├── backend/
│   ├── user-logic/
│   ├── gateway-logic/
│   └── platform-logic/
├── frontend/
│   └── forge-web/
├── deploy/
│   ├── charts/
│   ├── argocd/
│   └── kind-config.yaml
├── .github/workflows/
├── buf.yaml
├── buf.gen.yaml
└── proto/
    └── user/user.proto

# Phase 1: 拆分为 Multi-repo
github.com/mirai-zen/forge              # 主仓库（前端 + 部署）
github.com/mirai-zen/forge-gateway      # Gateway 服务
github.com/mirai-zen/forge-user         # User 服务
github.com/mirai-zen/forge-platform     # Platform 服务
github.com/mirai-zen/forge-proto          # 协议仓库
```

### 2.2 项目初始化脚本

```bash
#!/bin/bash
# init-forge.sh - 项目初始化脚本

set -e

# 创建仓库结构
mkdir -p forge/{backend/{user-service,gateway-service,platform-service},frontend,deploy/{charts,argocd},.github/workflows,proto/user}

# 初始化 Go Modules
cd forge/backend/user-service
go mod init github.com/mirai-zen/forge/backend/user-service

cd ../gateway-service
go mod init github.com/mirai-zen/forge/backend/gateway-service

cd ../platform-service
go mod init github.com/mirai-zen/forge/backend/platform-service

# 初始化前端
cd ../../frontend
npm create vue@latest forge-web -- --typescript --vue

# 初始化协议仓库
cd ../..
mkdir forge-proto && cd forge-proto
go mod init github.com/mirai-zen/forge-proto

# 创建 buf 配置
cat > buf.yaml << 'EOF'
version: v2
modules:
  - path: proto
lint:
  use:
    - STANDARD
breaking:
  use:
    - FILE
EOF

# 返回主仓库
cd ..
git init
git add .
git commit -m "init: forge project structure"

# 创建远程仓库（需要 GitHub CLI）
gh repo create mirai-zen/forge --private --clone
gh repo create mirai-zen/forge-proto --public --clone

echo "✅ Forge 项目初始化完成！"
```

### 2.3 Git 配置

```bash
# ~/.gitconfig
[user]
    name = Mirai Zen
    email = mirai@example.com

[core]
    editor = code --wait
    autocrlf = input
    safecrlf = true

[init]
    defaultBranch = main

[push]
    default = simple

[credential]
    helper = osxkeychain  # macOS 密钥链
```

### 2.4 .gitignore 策略

```gitignore
# Go
/bin/
*_test
*.exe
*.exe~
*.dll
*.so
*.dylib
*.test
*.coverprofile
.idea
.vscode/

# Node
node_modules/
dist/
*.local
.env.local
.env.*.local

# IDE
*.swp
*.swo
*~
.DS_Store
.idea/
.vscode/
*.sublime-*

# Docker
*.pid
*.pid.lock

# K8s 本地调试
kubeconfig
kubeconfig-dev

# 临时文件
*.log
*.tmp
*.bak
```

### 2.5 环境变量管理

```bash
# 模板文件
backend/user-logic/etc/config.yaml.example
backend/gateway-logic/etc/config.yaml.example
backend/platform-logic/etc/config.yaml.example

# .gitignore 中排除
backend/*/etc/*.yaml
!backend/*/etc/*.yaml.example
```

**config.yaml.example 内容：**
```yaml
# user-logic/etc/config.yaml.example
Name: user-service
Host: 0.0.0.0
Port: 8888

Etcd:
  Hosts:
    - kind-control-plane:2379
  Key: user-service.rpc

MySQL:
  DataSource: root:password@tcp(mysql:3306)/forge_user?charset=utf8mb4&parseTime=True&loc=Local

Redis:
  Host: redis:6379
  Password: ""
  DB: 0

JWT:
  Secret: change-me-in-production
  Expire: 86400
```

---

## 3. CI/CD 前置准备

### 3.1 GitHub Token 配置

```bash
# 生成 Personal Access Token (Classic)
# GitHub → Settings → Developer settings → Personal access tokens → Tokens (classic)
# 权限：repo (全权限), workflow, write:packages

# 添加到 GitHub Actions 环境变量
# Settings → Secrets and variables → Actions → New repository secret
# GH_TOKEN = ghp_xxxxxxxxxxxx

# 或本地开发时
export GH_TOKEN=ghp_xxxxxxxxxxxx
gh auth login
```

**待确认：**
- [ ] 使用 Personal Access Token 还是 SSH Key
- [ ] Token 权限范围（最小权限原则）

### 3.2 Docker Buildx 多架构构建

```bash
# 安装 buildx
docker buildx create --name builder --driver docker-container --use
docker buildx inspect builder --bootstrap

# 多架构构建（Mac M4 是 arm64，云上 amd64）
docker buildx build \
  --platform linux/amd64,linux/arm64 \
  -t ghcr.io/mirai-zen/forge-user:latest \
  --push \
  ./backend/user-logic/
```

**待确认：**
- [ ] Phase 0 是否需要多架构构建（建议先 amd64 即可）
- [ ] 是否启用 BuildKit（`DOCKER_BUILDKIT=1`）

### 3.3 ArgoCD 初始配置

```bash
# 部署 ArgoCD
kubectl create namespace argocd
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

# 获取初始密码
kubectl get secret argocd-initial-admin-secret -n argocd -o jsonpath="{.data.password}" | base64 -d

# 端口转发
kubectl port-forward svc/argocd-server -n argocd 8080:443 &

# 访问 https://localhost:8080
# 用户名：admin
# 密码：上面获取的
```

**待确认：**
- [ ] ArgoCD 是否需要配置认证（默认无密码，生产必须改）
- [ ] 是否启用 ArgoCD UI（面试演示需要）

### 3.4 GitHub Actions Runner

| 方案 | 优点 | 缺点 | 推荐 |
|------|------|------|------|
| **GitHub 自带 Runner** | 零配置，免费 | macOS Runner 贵（$0.08/min） | ✅ Phase 0 推荐 |
| **自建 Linux Runner** | 便宜，可控 | 需要一台常驻机器 | Phase 1 |
| **铭凡 Mac 做 Runner** | 利用现有硬件 | Mac Runner 官方不支持自托管 | ❌ 不推荐 |

**推荐：Phase 0 用 GitHub 自带的 `ubuntu-latest` Runner**

---

## 4. 网络与端口管理

### 4.1 端口分配表

| 服务 | 端口 | 协议 | 本地访问 | 说明 |
|------|------|------|---------|------|
| MySQL | 3306 | TCP | `localhost:3306` | 数据库 |
| Redis | 6379 | TCP | `localhost:6379` | 缓存 |
| ArgoCD Server | 8080 | HTTPS | `https://localhost:8080` | GitOps |
| ArgoCD API | 8081 | gRPC | - | API 调用 |
| Grafana | 3000 | HTTP | `http://localhost:3000` | 可视化 |
| Prometheus | 9090 | HTTP | `http://localhost:9090` | 指标 |
| Jaeger Query | 16686 | HTTP | `http://localhost:16686` | 链路追踪 |
| Jaeger Collector | 14250 | HTTP/gRPC | - | 数据收集 |
| Loki | 3100 | HTTP | `http://localhost:3100` | 日志 |
| Fluent Bit | 2020 | HTTP | - | 日志采集 |
| etcd | 2379 | HTTP | - | K8s 自带 |
| user-service | 8881 | HTTP | `http://localhost:8881` | 用户服务 |
| gateway-service | 8880 | HTTP | `http://localhost:8880` | 网关 |
| platform-service | 8882 | HTTP | `http://localhost:8882` | 平台服务 |
| Nginx Ingress | 80/443 | HTTP/HTTPS | - | K8s 入口 |

**总计：15+ 个端口，冲突风险高**

### 4.2 端口转发脚本

```bash
#!/bin/bash
# port-forward.sh - 一键端口转发

set -e

echo "🚀 启动端口转发..."

# 后台服务
kubectl port-forward svc/argocd-server -n argocd 8080:443 &
echo "✅ ArgoCD: https://localhost:8080"

kubectl port-forward svc/prometheus-grafana -n monitoring 3000:80 &
echo "✅ Grafana: http://localhost:3000"

kubectl port-forward svc/prometheus-server -n monitoring 9090:80 &
echo "✅ Prometheus: http://localhost:9090"

kubectl port-forward svc/jaeger-query -n monitoring 16686:80 &
echo "✅ Jaeger: http://localhost:16686"

kubectl port-forward svc/loki -n monitoring 3100:3100 &
echo "✅ Loki: http://localhost:3100"

# 本地开发服务（如果不在 K8s 中）
# kubectl port-forward svc/user-service 8881:8881 &
# kubectl port-forward svc/gateway-service 8880:8880 &
# kubectl port-forward svc/platform-service 8882:8882 &

echo ""
echo "✅ 端口转发完成！按 Ctrl+C 停止"
wait
```

### 4.3 Ingress 配置

```yaml
# deploy/charts/ingress/nginx-ingress.yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: forge-ingress
  namespace: forge-dev
  annotations:
    kubernetes.io/ingress.class: nginx
spec:
  rules:
  - host: forge.local
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: gateway-service
            port:
              number: 8880
      - path: /api
        pathType: Prefix
        backend:
          service:
            name: gateway-service
            port:
              number: 8880
```

**待确认：**
- [ ] 本地开发是否需要 Ingress（可以直接 port-forward）
- [ ] 是否需要配置 `/etc/hosts`（`127.0.0.1 forge.local`）

---

## 5. 数据初始化

### 5.1 MySQL 初始化脚本

```sql
-- deploy/k8s/infra/init-db.sql

-- 创建数据库
CREATE DATABASE IF NOT EXISTS forge_user CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
CREATE DATABASE IF NOT EXISTS forge_platform CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;

-- 使用 forge_user
USE forge_user;

-- 用户表
CREATE TABLE IF NOT EXISTS users (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    username VARCHAR(50) NOT NULL UNIQUE,
    password_hash VARCHAR(255) NOT NULL,
    email VARCHAR(100) NOT NULL UNIQUE,
    role ENUM('admin', 'user') NOT NULL DEFAULT 'user',
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    INDEX idx_username (username),
    INDEX idx_email (email)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- 初始管理员用户（密码：admin123，实际应使用 bcrypt 哈希）
INSERT INTO users (username, password_hash, email, role) VALUES
('admin', '$2a$10$xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx', 'admin@forge.dev', 'admin');

-- 使用 forge_platform
USE forge_platform;

-- 服务表
CREATE TABLE IF NOT EXISTS services (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    name VARCHAR(100) NOT NULL UNIQUE,
    description TEXT,
    repository_url VARCHAR(255),
    branch VARCHAR(50) DEFAULT 'main',
    status ENUM('active', 'inactive', 'archived') DEFAULT 'active',
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    INDEX idx_name (name),
    INDEX idx_status (status)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- 部署记录表
CREATE TABLE IF NOT EXISTS deployments (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    service_id BIGINT UNSIGNED NOT NULL,
    version VARCHAR(50) NOT NULL,
    image VARCHAR(255) NOT NULL,
    status ENUM('pending', 'running', 'failed', 'rolled_back') DEFAULT 'pending',
    deployed_by VARCHAR(50),
    deployed_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (service_id) REFERENCES services(id) ON DELETE CASCADE,
    INDEX idx_service (service_id),
    INDEX idx_status (status)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
```

### 5.2 Kubernetes 基础设施部署

```yaml
# deploy/k8s/infra/mysql.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: mysql
  namespace: forge-dev
spec:
  replicas: 1
  selector:
    matchLabels:
      app: mysql
  template:
    metadata:
      labels:
        app: mysql
    spec:
      containers:
      - name: mysql
        image: mysql:8.0
        env:
        - name: MYSQL_ROOT_PASSWORD
          value: "root123"
        - name: MYSQL_DATABASE
          value: "forge_user"
        ports:
        - containerPort: 3306
        volumeMounts:
        - name: init-sql
          mountPath: /docker-entrypoint-initdb.d
        resources:
          requests:
            memory: "1Gi"
            cpu: "500m"
          limits:
            memory: "2Gi"
            cpu: "1000m"
      volumes:
      - name: init-sql
        configMap:
          name: mysql-init

---
apiVersion: v1
kind: ConfigMap
metadata:
  name: mysql-init
  namespace: forge-dev
data:
  init.sql: |
    # 上面 SQL 内容

---
apiVersion: v1
kind: Service
metadata:
  name: mysql
  namespace: forge-dev
spec:
  selector:
    app: mysql
  ports:
  - port: 3306
    targetPort: 3306
```

```yaml
# deploy/k8s/infra/redis.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: redis
  namespace: forge-dev
spec:
  replicas: 1
  selector:
    matchLabels:
      app: redis
  template:
    metadata:
      labels:
        app: redis
    spec:
      containers:
      - name: redis
        image: redis:7-alpine
        ports:
        - containerPort: 6379
        resources:
          requests:
            memory: "128Mi"
            cpu: "100m"
          limits:
            memory: "256Mi"
            cpu: "250m"

---
apiVersion: v1
kind: Service
metadata:
  name: redis
  namespace: forge-dev
spec:
  selector:
    app: redis
  ports:
  - port: 6379
    targetPort: 6379
```

---

## 6. 测试策略

### 6.1 测试环境

```bash
# 使用 testcontainers-go 在 Docker 中启动测试数据库
# go test -v -race -coverprofile=coverage.out ./...

# 示例：user-service 集成测试
package user

import (
    "context"
    "testing"
    "github.com/stretchr/testify/assert"
    "github.com/stretchr/testify/require"
    "github.com/testcontainers/testcontainers-go"
    "github.com/testcontainers/testcontainers-go/modules/mysql"
)

func TestUserService_Register(t *testing.T) {
    ctx := context.Background()
    
    // 启动 MySQL 容器
    mysqlContainer, err := mysql.Run(ctx, "mysql:8.0",
        testcontainers.WithEnv(map[string]string{
            "MYSQL_ROOT_PASSWORD": "test",
            "MYSQL_DATABASE": "test",
        }),
    )
    require.NoError(t, err)
    defer mysqlContainer.Terminate(ctx)
    
    // 获取连接字符串
    host, port, err := mysqlContainer.Connection(ctx)
    require.NoError(t, err)
    
    // 测试逻辑...
}
```

**待确认：**
- [ ] 是否需要写单元测试（面试不看，但代码质量需要）
- [ ] 是否需要 E2E 测试（Playwright，Phase 1 再考虑）
- [ ] Mock 策略（K8s Client 如何 mock）

---

## 7. 文档清单

### 7.1 必需文档

| 文档 | 状态 | 说明 |
|------|------|------|
| `README.md` | 📋 待创建 | 项目介绍、架构图、技术选型、踩坑记录 |
| `docs/forge-architecture.md` | ✅ 已创建 | 技术方案设计 |
| `docs/sprint-plan.md` | ✅ 已创建 | 开发计划 |
| `docs/implementation-checklist.md` | ✅ 已创建 | 落地执行清单（本文档） |
| `CONTRIBUTING.md` | 📋 待创建 | 贡献指南（即使只有自己） |
| `CHANGELOG.md` | 📋 待创建 | 变更记录 |
| `LICENSE` | 📋 待创建 | 开源协议 |

### 7.2 LICENSE 选择

| 协议 | 允许 | 要求 | 推荐 |
|------|------|------|------|
| **MIT** | 商用 | 保留版权声明 | ✅ 最简单 |
| Apache 2.0 | 商用 | 保留声明 + 变更说明 | 企业级 |
| GPL 3.0 | 个人 | 开源衍生作品 | ❌ 太严格 |
| **无 License** | 保留所有权利 | 不得使用 | ❌ 不推荐 |

**推荐：MIT License**（简洁，允许他人使用）

### 7.3 CONTRIBUTING.md 模板

```markdown
# Contributing to Forge

## 开发环境设置

1. 克隆仓库
   ```bash
   git clone mirai-zen:mirai-zen/forge.git
   cd forge
   ```

2. 安装依赖
   ```bash
   # 后端
   cd backend/user-service && go mod download
   
   # 前端
   cd frontend && npm install
   ```

3. 启动本地开发环境
   ```bash
   kind create cluster --name forge
   kubectl apply -f deploy/k8s/infra/
   ```

## 提交规范

- 使用 Conventional Commits：`feat:`, `fix:`, `docs:`, `refactor:`
- PR 标题：`[模块] 简短描述`
- PR 描述：说明变更原因和影响

## 代码风格

- Go：`gofmt`, `golangci-lint`
- TypeScript：`eslint`, `prettier`
```

---

## 8. 面试相关准备

### 8.1 简历项目描述模板

```
Forge - 云原生内部开发者平台（IDP）
GitHub: https://github.com/mirai-zen/forge

技术栈：Go / go-zero / Kubernetes / ArgoCD / OpenTelemetry / etcd / Vue3

- 设计并实现了一套面向微服务的内部开发者平台，支持服务注册发现、
  一键部署、全链路可观测性
- 基于 go-zero + etcd 实现服务注册与配置中心，替代 Nacos，100% Go 栈
- 集成 OpenTelemetry + Jaeger + Loki，实现 Metrics/Trace/Logs 三合一
- 设计 GitOps 流水线（GitHub Actions + ArgoCD），支持一键部署到 K8s
- 前端采用 Vue3 + Ant Design Vue，实现注册中心控制面板和部署流水线可视化
```

### 8.2 技术博客选题

| 选题 | 核心内容 | 预计字数 |
|------|---------|---------|
| 《为什么我选择 etcd 而不是 Nacos》 | 纯 Go 栈、K8s 原生、Raft 共识 | 2000 字 |
| 《go-zero 服务注册到 etcd 的实践》 | etcd Watch + 服务发现 | 1500 字 |
| 《OpenTelemetry 全链路追踪落地指南》 | TraceID 透传、Jaeger 瀑布图 | 3000 字 |
| 《GitOps 实战：GitHub Actions + ArgoCD》 | CI/CD 流水线设计 | 2500 字 |
| 《个人项目如何做到生产级 CI/CD》 | Trivy 扫描、GHCR、Helm | 2000 字 |

### 8.3 Demo 视频脚本（5 分钟）

```
0:00-0:30  架构介绍
   - 展示 draw.io 架构图
   - 口述：3 个微服务 + 可观测性 + GitOps

0:30-1:30  核心功能演示
   - 登录页 → 输入 admin/admin123
   - 服务列表 → 展示已注册服务
   - 一键部署 → 点击部署按钮 → 30 秒看到 Pod Running

1:30-2:30  注册中心控制面板
   - etcd 服务树 → 实时刷新（WebSocket）
   - 健康状态 → 绿色/红色标签

2:30-3:30  可观测性演示
   - Grafana 指标面板 → QPS、延迟
   - 日志查询 → 搜 traceID
   - Jaeger 瀑布图 → 展示跨服务调用链

3:30-4:30  GitOps 演示
   - 修改代码 → git push
   - GitHub Actions 构建 → GHCR
   - ArgoCD 自动同步 → Pod 更新

4:30-5:00  技术栈总结
   - 展示技术选型对比表
   - 口述：踩坑记录 + 后续规划
```

---

## 9. 风险控制与降级方案

### 9.1 风险矩阵

| 风险 | 概率 | 影响 | 降级方案 |
|------|------|------|---------|
| **第 1 周完不成 user-service** | 中 | 高 | 跳过 JWT，先用硬编码用户 |
| **Jaeger 资源占用太高** | 高 | 中 | 降低采样率到 10%，或跳过 Jaeger |
| **前端做不完** | 高 | 中 | 先用 Postman 演示 API，前端用模板加速 |
| **Kind 集群启动失败** | 低 | 高 | 准备 Docker Compose 替代方案 |
| **GitHub Actions 构建超时** | 中 | 低 | 增加 BuildKit 缓存，优化 Dockerfile |
| **Mac M4 兼容性问题** | 中 | 低 | 使用 `GOARCH=amd64` 强制 amd64 构建 |

### 9.2 最小可行产品（MVP）

如果时间不够，保证以下核心链路完整：

```
MVP 核心链路（必须完成）：
├── user-service：注册/登录（硬编码用户也可）
├── gateway-service：JWT 鉴权（可跳过限流）
├── platform-service：服务 CRUD（跳过 K8s 对接）
├── Grafana：指标面板（跳过 Trace/Logs）
└── README：架构图 + 技术选型表
```

**如果只能完成 3 件事：**
1. ✅ user-service 可注册/登录
2. ✅ Grafana 可展示指标
3. ✅ README 有架构图

---

## 10. 下一步行动

### Day 0：环境准备（今天）

- [ ] 确认 MacBook M4 Pro 具体配置
- [ ] 确认铭凡机器配置和网络
- [ ] 安装 Homebrew + 基础工具
- [ ] 配置 SSH 密钥
- [ ] 创建 GitHub 仓库（forge + forge-proto）
- [ ] 初始化项目结构

### Day 1：协议仓库 + user-service

- [ ] 创建 forge-proto 仓库
- [ ] 编写 user.proto
- [ ] 生成 Go/TS 代码
- [ ] 创建 user-service
- [ ] 编写 MySQL 初始化脚本

### Day 2-5：继续 Week 1 计划

- 详见 `docs/sprint-plan.md`

---

*文档版本：v1.0*
*创建日期：2026-06-14*
*最后更新：2026-06-14*
