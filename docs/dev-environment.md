# Forge - 环境配置指南

> 记录开发环境、测试环境、网络配置的完整指南。

---

## 1. 硬件环境

### 1.1 开发机（MacBook M4 Pro）

| 项目 | 规格 | 用途 |
|------|------|------|
| 主机 | MacBook M4 Pro | 主要开发机 |
| OS | macOS Sonoma/Sequoia | 开发环境 |
| 网络 | WiFi / 有线 | 日常开发 |

**待确认：**
- [ ] macOS 具体版本
- [ ] 内存大小
- [ ] 磁盘剩余空间

### 1.2 测试机（铭凡 UM890 Pro）

| 项目 | 规格 | 用途 |
|------|------|------|
| 主机 | 铭凡 UM890 Pro | 测试/部署验证 |
| CPU | 8 核 16 线程 | 运行 Kind 集群 |
| 内存 | 64 GB | 承载全套组件 |
| 磁盘 | 1 TB SSD | 存储 |
| OS | Windows 11 + WSL2 (Ubuntu) | 开发环境 |
| K8s | Kind 集群（1 Control + 2 Worker） | 本地 K8s |

**待确认：**
- [ ] WSL2 Ubuntu 版本
- [ ] Docker Desktop 版本
- [ ] 铭凡机器的局域网 IP
- [ ] 铭凡机器的用户名

### 1.3 环境分工

```
MacBook M4 Pro（开发机）
    │
    │ 编写代码、本地调试、Git 推送
    │ VS Code / GoLand / Terminal
    │
    │ SSH / Git / Tailscale
    │
铭凡 UM890 Pro（测试/运行机）
    │
    │ Kind Cluster（3 Nodes）
    │   ├── 3 个 go-zero 微服务
    │   ├── MySQL + Redis + etcd
    │   ├── ArgoCD + Prometheus + Grafana
    │   ├── Jaeger + Loki + Fluent Bit
    │   └── Nginx Ingress
    │
    │ 所有服务运行在这里
    │ Mac 只做代码编辑
```

---

## 1.4 K8s Namespace 规划

| Namespace | 用途 | 说明 |
|-----------|------|------|
| `infra` | 共享基础设施 | ArgoCD / MySQL / Redis / monitoring（Grafana/Prometheus/Jaeger/Loki） |
| `forge-dev` | 开发环境 | platform / gateway / user 等服务的 dev 部署 |
| `forge-staging` | 测试环境 | 同上，staging 部署 |
| `forge-prod` | 正式环境 | 同上，prod 部署 |

### 为什么这样分

```
infra       → 所有工具和中间件放一起，Phase 0 不拆
forge-*     → 业务按环境隔离，每个环境一个 namespace
```

> Phase 0 单实例 MySQL/Redis，放 `infra` 够用。Phase 1 再考虑每环境独立数据库或拆分 monitoring。

---

## 1.5 仓库本地路径

| 仓库 | 本地路径 | 说明 |
|------|---------|------|
| **forge-proto** | `/Users/mirai/Code/go/forge-proto/` | 协议仓库（proto + buf + 生成代码） |
| **forge** | `/Users/mirai/Code/go/forge/` | 后端 Monorepo（platform/gateway/user） |
| **forge-web** | `/Users/mirai/Code/web/forge-web/` | 前端（Vue3 + Ant Design） |
| **forge-design** | `/Users/mirai/CodeBuddy/forge-design/` | 设计文档仓库 |

> ⚠️ `forge-design` 是纯文档仓库，不要往里放代码。proto 放 `forge-proto`，Go 代码放 `forge`，前端放 `forge-web`。

---

## 2. Tailscale 配置

### 2.1 安装 Tailscale

**MacBook M4 Pro：**

```bash
# 1. 安装
brew install tailscale

# 2. 启动并扫码登录
sudo tailscale up

# 3. 验证
tailscale status
# 应该看到：
# root@mirai-mac:
#   Tailnet IP: 100.x.x.x
#   root@mingfan: 100.x.x.x (online)

# 4. 设置开机自启
sudo launchctl load /Library/LaunchDaemons/com.tailscale.ipn.plist
```

**铭凡 WSL2（Ubuntu）：**

```bash
# 1. 安装
curl -fsSL https://tailscale.com/install.sh | sh

# 2. 启动并扫码登录（同一个 Tailscale 账号）
sudo tailscale up

# 3. 设置开机自启
sudo systemctl enable tailscale
sudo systemctl start tailscale
```

### 2.2 启用 MagicDNS

**第一步：在 Tailscale 后台启用 MagicDNS**

```
1. 访问 https://login.tailscale.com/admin/dns
2. 点击 "MagicDNS" 菜单
3. 点击 "Enable MagicDNS" 按钮
4. 确认启用（免费计划支持）
```

**第二步：本地重新配置**

```bash
# 两台机器都执行：
sudo tailscale down
sudo tailscale up --accept-dns=true --hostname=你的主机名
```

**第三步：配置系统 DNS（Mac 必须）**

```bash
# Mac 上设置 DNS 服务器为 Tailscale：
sudo networksetup -setdnsservers Wi-Fi 100.100.100.100
sudo networksetup -setsearchdomains Wi-Fi tail6ddf30.ts.net

# 刷新 DNS 缓存：
sudo dscacheutil -flushcache
sudo killall -HUP mDNSResponder
```

**验证 MagicDNS：**

```bash
# 1. 检查 MagicDNS 状态：
tailscale status --json | jq '.Self.MagicDNSEnabled'
# 应该返回 true

# 2. 查看自己的域名：
tailscale status --json | jq '.Self.DNSName'
# 应该返回类似 "mirai-mac.tail6ddf30.ts.net"

# 3. 测试解析：
ping mirai-wsl.tail6ddf30.ts.net
# 应该返回铭凡的 Tailscale IP（100.x.x.x）

# 4. 查看连接状态：
tailscale status
# 应该看到：
# mirai-wsl.tail6ddf30.ts.net  100.x.x.x  active; direct 192.168.92.x:41641
```

### 2.3 SSH 配置

**Mac 上 `~/.ssh/config`：**

```
# 铭凡测试机（通过 MagicDNS）
Host forge-local
    HostName mirai-wsl.tail6ddf30.ts.net
    User mirai
    IdentityFile ~/.ssh/id_ed25519
    ServerAliveInterval 60
    ServerAliveCountMax 3

# GitHub
Host mirai-zen
    HostName github.com
    User git
    IdentityFile ~/.ssh/id_ed25519
```

**WSL2 上 `~/.ssh/config`：**

```
# 铭凡测试机（通过 MagicDNS）
Host forge-local
    HostName mirai-wsl.tail6ddf30.ts.net
    User mirai
    IdentityFile ~/.ssh/id_ed25519
```

**测试连接：**

```bash
ssh forge-local    # 而不是 ssh root@100.x.x.x
```

### 2.4 kubectl 配置

```bash
# 1. 查看铭凡的 Tailscale IP
ssh forge-local "tailscale ip -4"

# 2. 配置 kubectl（Mac 和 WSL2 上都执行）
kubectl config set-cluster forge-dev \
    --server=https://<铭凡 Tailscale IP>:6443 \
    --insecure-skip-tls-verify=true

# 3. 复制 kubeconfig
ssh forge-local "cat ~/.kube/config" > ~/.kube/config-forge

# 4. 使用远程集群
KUBECONFIG=~/.kube/config-forge kubectl get nodes
```

### 2.5 网络特点

| 场景 | 流量路径 | 延迟 | 加密 | 消耗流量 |
|------|---------|------|------|---------|
| 纯 LAN（理想） | 局域网交换机 | <1ms | ✅ | ❌ 不消耗 |
| IPv6 P2P 直连 | 运营商 IPv6 | 8-25ms | ✅ | ✅ 消耗 |
| 不同网络 | Tailscale 隧道 | 50-200ms | ✅ | ✅ 消耗 |
| DERP 中继（最差） | Tailscale 服务器 | 100-500ms | ✅ | ✅ 消耗 |

**当前实际配置：**
- Mac → 铭凡：IPv6 P2P 直连（`direct`），延迟 8-25ms
- 手机热点启用了 AP 隔离，无法实现纯 LAN 通信
- Tailscale 标记为 `direct` 表示不走公网中继服务器

**关键优势：**
- ✅ 零配置，不需要脚本
- ✅ 热点重启无影响
- ✅ 跨网络无缝切换
- ✅ 不走 Tailscale 公网中继服务器
- ✅ WireGuard 全程加密

**如需纯 LAN（不消耗流量）：**
- 方案 1：铭凡开 WiFi 热点给 Mac（零成本）
- 方案 2：便携路由器（50-80 元）
- 方案 3：网线直连（需转接头）

---

## 3. Mac 开发环境

### 3.1 基础工具安装

```bash
# Homebrew（如果未安装）
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

# 核心开发工具
brew install git
brew install go@1.22          # Go 1.22.x
brew install node@20          # Node.js 20 LTS
brew install kubelet kubectl  # K8s CLI
brew install helm
brew install bufbuild/buf/buf

# 可选：版本管理
brew install asdf             # 多版本管理
# 或
brew install nvm              # Node 版本管理
brew install goenv            # Go 版本管理
```

**待确认：**
- [ ] Docker Desktop vs Colima（Mac）
- [ ] Go 版本锁定（1.22 / 1.23）
- [ ] Node.js 版本锁定（20 LTS / 22）

### 3.2 IDE 配置

**VS Code 扩展推荐：**

| 扩展 | 用途 |
|------|------|
| Go (golang.go) | Go 语言支持 |
| TypeScript + JavaScript (Microsoft) | TS 支持 |
| Vue - Official | Vue3 语法高亮 |
| Error Lens | 行内错误提示 |
| GitLens | Git 增强 |
| Draw.io Integration | 架构图绘制 |
| YAML / JSON / Dockerfile | 格式支持 |

**待确认：**
- [ ] VS Code 还是 GoLand（GoLand 收费，VS Code 免费）

### 3.3 Git 配置

**`~/.gitconfig`：**

```ini
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

---

## 4. 铭凡测试环境

### 4.1 WSL2 基础工具

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

### 4.2 WSL2 资源配置

```ini
# C:\Users\<用户名>\.wslconfig
[wsl2]
memory=24GB
processors=12
swap=0
localhostForwarding=true
```

### 4.3 开发环境资源消耗

| 组件 | 内存 | 说明 |
|------|------|------|
| WSL2 + Docker | 3 GB | `.wslconfig` 限制 24 GB |
| Kind 3 Node | 2.5 GB | 1 Control + 2 Worker |
| etcd（Kind 自带） | 128 MB | 复用 K8s 控制面 etcd |
| MySQL | 2 GB | 单副本，1 GB InnoDB Buffer |
| Redis | 256 MB | 单副本 |
| ArgoCD | 1 GB | 单实例 |
| Jaeger | 1.5 GB | 100% 采样 |
| Prometheus | 2 GB | 15 天保留 |
| Loki + Fluent Bit | 0.5 GB | 7 天保留 |
| Grafana | 0.3 GB | 单实例 |
| 3 个 go-zero 微服务 | 1.5 GB | gateway + user + platform |
| **日常实际** | **~22 GB** | 大部分组件 idle 状态 |
| **满载峰值** | **~26 GB** | CI 构建 + Jaeger 写入同时发生 |
| **剩余** | **~38 GB** | 绰绰有余 |

---

## 5. 网络拓扑

```
MacBook M4 Pro (开发)
    │
    │ Tailscale MagicDNS
    │ mirai-zen.forge.local
    │ SSH / Git / kubectl
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

### 5.1 MagicDNS 域名解析

| 设备 | 域名 | 说明 |
|------|------|------|
| Mac | `mirai-mac.forge.local` | 开发机 |
| 铭凡 | `mirai-zen.forge.local` | 测试机 |
| 任意 | `*.forge.local` | Tailscale 自动解析 |

### 5.2 端口分配表

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

### 5.1 端口分配表

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

---

## 6. 开发工作流

### 6.1 推荐流程：GitHub Actions 自动部署

```bash
# Mac 上：
vim backend/user-logic/main.go    # 编辑代码
git add .
git commit -m "feat: user login"
git push origin main

# GitHub Actions 自动：
# Build → Push GHCR → ArgoCD Sync → 铭凡 Kind 集群自动更新
```

### 6.2 备选流程：SSH 手动部署

```bash
# Mac 上：
ssh mingfan                           # SSH 到铭凡
cd /path/to/project
git pull origin main
go build ./backend/user-logic/
kubectl rollout restart deployment/user-service
exit
```

### 6.3 端口转发脚本

**`port-forward.sh`：**

```bash
#!/bin/bash
# 一键端口转发

set -e

echo "🚀 启动端口转发..."

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

echo ""
echo "✅ 端口转发完成！按 Ctrl+C 停止"
wait
```

### 6.4 CI/CD 工作流

#### 每服务独立 Workflow

```
forge/.github/workflows/
├── user-ci.yml      # 监听 user/** 变更
├── gateway-ci.yml   # 监听 gateway/** 变更
└── platform-ci.yml  # 监听 platform/** 变更
```

#### 触发规则

| 事件 | user-ci | gateway-ci | platform-ci |
|------|:---:|:---:|:---:|
| 改 `user/**` | ✅ | ❌ | ❌ |
| 改 `gateway/**` | ❌ | ✅ | ❌ |
| 改 `platform/**` | ❌ | ❌ | ✅ |
| 改 `README.md` | ❌ | ❌ | ❌ |

#### 每个 Workflow 内部

```yaml
# 两个 Job：
# 1. build（PR 和 main push 都触发）
#    - go vet ./...
#    - go test -race ./...
#    - go build -o bin/{service} ./cmd/
#
# 2. docker（仅 main push 触发）
#    - 构建镜像 ghcr.io/mirai-zen/forge-{service}
#    - docker/metadata-action 自动打 tag
```

#### Docker 镜像命名

| 服务 | 镜像 |
|------|------|
| user | `ghcr.io/mirai-zen/forge-user:latest` |
| gateway | `ghcr.io/mirai-zen/forge-gateway:latest` |
| platform | `ghcr.io/mirai-zen/forge-platform:latest` |

> Docker context 为各服务目录自身，每个 Dockerfile 只看到自己的 go.mod 和代码。

---

## 7. 环境变量管理

### 7.1 模板文件

```bash
# forge/user/internal/config/config.example.yaml.example
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

### 7.2 .gitignore 策略

```gitignore
# Go
/bin/
*_test
*.exe
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

# K8s 本地调试
kubeconfig
kubeconfig-dev

# 临时文件
*.log
*.tmp
*.bak
```

排除：
```gitignore
backend/*/etc/*.yaml
!backend/*/etc/*.yaml.example
```

---

## 8. 故障排查

### 8.1 Tailscale 连接问题

```bash
# 检查 Tailscale 状态：
tailscale status

# 查看 MagicDNS 是否启用：
tailscale status --json | jq '.Self.DNSName'

# 重启 Tailscale：
sudo tailscale down
sudo tailscale up

# 检查网络：
ping 8.8.8.8
```

### 8.2 MagicDNS 解析失败

```bash
# 1. 检查 MagicDNS 是否启用：
tailscale status --json | jq '.Self.MagicDNSEnabled'
# 应该返回 true

# 2. 查看域名：
tailscale status --json | jq '.Self.DNSName'
# 应该返回类似 "mirai-mac.tail6ddf30.ts.net"

# 3. 重新启用：
sudo tailscale down
sudo tailscale up --accept-dns=true --hostname=你的主机名

# 4. Mac 必须配置系统 DNS：
sudo networksetup -setdnsservers Wi-Fi 100.100.100.100
sudo networksetup -setsearchdomains Wi-Fi tail6ddf30.ts.net

# 5. 刷新 DNS 缓存：
sudo dscacheutil -flushcache
sudo killall -HUP mDNSResponder

# 6. 测试解析：
ping mirai-wsl.tail6ddf30.ts.net

# 7. 验证解析：
nslookup mirai-wsl.tail6ddf30.ts.net 100.100.100.100
```

### 8.3 SSH 连接超时

```bash
# 检查 Tailscale 是否正常运行：
sudo systemctl status tailscaled  # Linux
sudo launchctl list | grep tailscale  # macOS

# 检查防火墙：
sudo iptables -L -n | grep tailscale
# 应该看到允许 41641/udp 的规则
```

### 8.4 连接延迟高（走 DERP 中继）

```bash
# 检查连接状态：
tailscale status

# 如果看到 "relay" 而不是 "direct"：
# 1. 检查两台设备的网络：
tailscale status --json | jq '.Peers[] | {DNSName, LastSeen, Endpoint}'

# 2. 可能的原因：
#    - 手机热点启用了 AP 隔离（客户端隔离）
#    - 两台设备不在同一局域网
#    - NAT 类型限制导致 P2P 穿透失败

# 3. 解决方案：
#    方案 1：铭凡开 WiFi 热点给 Mac（纯 LAN，零成本）
#    方案 2：便携路由器（50-80 元）
#    方案 3：网线直连（需转接头）

# 4. 当前 IPv6 P2P 直连状态（正常）：
#    如果看到 "direct 192.168.92.x:41641" 表示走局域网
#    如果看到 "direct [IPv6]:41641" 表示走 IPv6 P2P
#    这两种情况都不走 Tailscale 公网服务器
```

### 8.5 Kind 集群问题

```bash
# 检查集群状态：
kind get clusters
kubectl get nodes

# 删除并重建集群：
kind delete cluster --name idp
kind create cluster --name idp --config kind-config.yaml
```

---

## 9. 下一步行动

### Day 0：环境准备（今天）

- [x] 确认 MacBook M4 Pro 具体配置
- [x] 确认铭凡机器配置和网络
- [x] 安装 Tailscale（Mac + WSL2）
- [x] 启用 MagicDNS（后台 + 本地配置）
- [x] 配置 Mac 系统 DNS（`sudo networksetup -setdnsservers Wi-Fi 100.100.100.100`）
- [x] 配置 SSH 密钥
- [x] 配置 SSH config 使用 MagicDNS 域名
- [ ] 创建 GitHub 仓库（forge-proto + forge + forge-web）
- [ ] 初始化项目结构

### Day 1：协议仓库 + user-service

- [ ] 创建 forge-proto 仓库
- [ ] 创建 forge 仓库
- [ ] 编写 user/user.proto
- [ ] 生成 Go/TS 代码
- [ ] 创建 user-service
- [ ] 编写 MySQL 初始化脚本

---

*文档版本：v1.1*
*创建日期：2026-06-14*
*最后更新：2026-06-14*
