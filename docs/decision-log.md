# Forge - 项目演变历程

> 记录从构思到落地的完整讨论过程、技术选型决策和架构演变。
> 这不仅是一份历史记录，更是面试时可以回顾的"决策日志"。

---

## 时间线总览

| 阶段 | 主题 | 关键决策 |
|------|------|---------|
| **构思期** | 日志系统 + 可观测性 | 自研 IDP 而非用 Backstage |
| **架构期** | 微服务 + CI/CD | go-zero + etcd + GitHub Actions |
| **评审期** | 架构师评审 | 砍掉 60% 功能，聚焦核心链路 |
| **落地期** | 命名 + 环境配置 | Forge + mirai-zen + 双机开发 |

---

## 一、构思期：从日志到全链路可观测性

### 1.1 起点：日志在哪里？

**原始问题**：用户想知道日志存储在哪里。

**讨论过程**：
```
用户：那我还没搞懂日志是记录在哪里的
AI：日志经过 Fluent Bit → Loki 存储
用户：那后端的日志组件用什么呢
AI：推荐 Uber Zap（高性能结构化日志）
```

**关键决策**：
- ✅ 后端日志组件：**Uber Zap**
- ✅ 日志采集：**Fluent Bit**（极致轻量）
- ✅ 日志存储：**Loki**（Grafana 生态）

### 1.2 扩展：全链路可观测性

**用户需求**：想看到整个调用链的瀑布图。

**讨论过程**：
```
用户：我还是想能看到整个调用链路的瀑布图
AI：这是 Jaeger 的功能
```

**关键决策**：
- ✅ 链路追踪：**Jaeger**（瀑布图 + 拓扑图）
- ✅ 指标采集：**Prometheus**
- ✅ 可视化门户：**Grafana**（Metrics + Trace + Logs 三合一）

### 1.3 扩展：运维 Agent

**用户需求**：后期想加入运维 Agent，日志系统要支持。

**关键决策**：
- ✅ Agent 专用日志接口设计（K8s Logs API + Loki Query API + Jaeger Query API）
- ✅ 所有服务输出 JSON 格式结构化日志
- ✅ 必须包含 traceID、spanID、service 字段

---

## 二、架构期：CI/CD 与技术选型

### 2.1 CI/CD 成为重点

**用户需求**：ci/cd 是重点。

**讨论过程**：
```
AI： propose GitHub Actions + ArgoCD + Harbor pipeline
用户：我觉得有些东西还是要对标生产级项目的
AI：upgrade plan with Kyverno, Cosign, SLSA, Argo Rollouts
```

**关键决策**：
- ✅ CI 引擎：**GitHub Actions**
- ✅ GitOps 引擎：**ArgoCD**
- ✅ 镜像仓库：**GHCR**（Phase 0）→ **Harbor**（Phase 2）
- ✅ 部署模板：**Helm Chart**
- ✅ 渐进交付：**Argo Rollouts**（Phase 2）

### 2.2 协议与代码分离

**用户需求**：协议和代码要分开，防止源码泄露。

**讨论过程**：
```
用户：协议和代码也需要分开吧，不然其他人引用代码还会把你的源码给拉取
AI：multi-repo strategy with forge-proto
```

**关键决策**：
- ✅ 协议仓库：**forge-proto**（公开）
- ✅ 业务仓库：**forge**（私有）
- ✅ 前部仓库：**forge-web**（私有）
- ✅ 协议治理：**buf**（代码生成、规范检查、向后兼容）
- ✅ 每个 proto 独立 go.mod（微服务独立演进原则）
- ✅ 禁止跨 proto import，共享 message 走 common 模块
- ✅ 不强制 v1 目录（个人项目简洁优先，不需十年兼容）

### 2.3 微服务框架选型

**候选框架**：
| 框架 | 推荐理由 | 最终决策 |
|------|---------|---------|
| Kratos | B站出品，文档优秀 | ❌ 企业采用率不如 go-zero |
| go-zero | 腾讯/华为/美团在用，goctl 工具链完整 | ✅ **最终选择** |
| Gin | 简单但缺少内置治理 | ❌ 不适合微服务 |

**关键决策**：
- ✅ 微服务框架：**go-zero**
- ✅ 理由：企业采用率最高，内置工具链完整，goctl 代码生成器

### 2.4 注册中心选型

**候选方案**：
| 方案 | 语言 | 一致性 | 推荐指数 |
|------|------|--------|---------|
| Nacos | Java | Raft (AP/CP) | ⭐⭐⭐⭐ |
| etcd | Go | Raft (CP) | ⭐⭐⭐⭐⭐ |
| Consul | Go | Raft (CP) | ⭐⭐⭐ |

**讨论过程**：
```
用户：我们是不是可以考虑用 etcd 做注册中心呢，这样的话技术深度有了吗
AI：etcd 是 K8s 控制面数据库，理解 etcd 等于理解 K8s 的心脏
```

**关键决策**：
- ✅ 注册中心：**etcd**（纯 Go 编写，Kind 自带）
- ✅ 理由：100% Go 栈，Raft 共识算法，MVCC + Watch 机制
- ✅ 面试加分：Raft 关键知识点（Leader 选举、Quorum、Term 递增）

### 2.5 ORM 与日志组件

**关键决策**：
- ✅ ORM：**GORM v2**（Go 生态标准）
- ✅ 日志：**Uber Zap**（高性能结构化日志）
- ✅ 数据库迁移：**golang-migrate**（纯 SQL）

---

## 三、评审期：架构师评审与精简

### 3.1 Senior Architect 评审

**用户贴了一段评审意见**：
```
"这套方案过于复杂，6 个微服务 + qiankun + Nacos + 完整安全链，
对于一个 1 人开发的项目来说严重过设计。"
```

**评审核心观点**：
1. ❌ 6 个微服务太多（1 人开发运维成本远超收益）
2. ❌ qiankun 微前端解决的是多团队协作问题，不是技术问题
3. ❌ Cosign/SBOM/SLSA/Kyverno 在没有外部攻击面时是摆设
4. ❌ Harbor 需要 2.5GB 内存，个人项目用 GHCR 就够了

### 3.2 精简决策

**讨论过程**：
```
用户：可以（同意评审意见）
用户：在企业角度来说微服务是必须的，我可以减少微服务数量，
      但是不要直接做成单体项目
用户：改吧（切换到 3 个微服务）
```

**精简结果**：

| 组件 | 原方案 | 实际决策 | 原因 |
|------|--------|---------|------|
| **微服务数量** | 6 个 | **3 个** | 1 人开发，运维成本远超收益 |
| **qiankun 微前端** | Phase 0 引入 | **Phase 1 引入** | 10 页后台不需要 |
| **Cosign 签名** | Phase 0 CI 集成 | **Phase 2 规划** | 没有外部攻击面 |
| **SBOM 生成** | Phase 0 CI 集成 | **Phase 2 规划** | 无合规审计需求 |
| **SLSA 溯源** | Phase 0 CI 集成 | **Phase 3 规划** | 个人项目无供应链攻击风险 |
| **Kyverno** | Phase 0 部署 | **Phase 3 规划** | 准入控制在没有多租户时是摆设 |
| **Vault** | Phase 0 部署 | **Phase 3 规划** | K8s Secret + Sealed Secrets 够用 |
| **Harbor** | Phase 0 自建 | **Phase 2 自建** | Phase 0 用 GHCR，零运维 |

**面试话术**：
> "这份设计是理想化的企业级全景图。实际开发中，我已明确标注了哪些组件是规划、哪些已砍掉。Phase 0 演示版本只实现核心的认证、部署、可观测性三条链路。"

---

## 四、落地期：命名与环境配置

### 4.1 项目名称确定

**讨论过程**：
```
用户：还有其他推荐吗
AI：推荐工业/锻造主题（Forge/Anvil/Hammer）、构建/基石主题（Keystone/Cornerstone）、
    引擎/驱动主题（Engine/Core/Nexus）、中文命名（天工/鲁班/铸剑/磐石）
用户：那就使用 forge 吧
```

**最终命名**：
- ✅ 项目名称：**Forge**
- ✅ GitHub 组织：**mirai-zen**
- ✅ 仓库名：`forge-gateway`, `forge-user`, `forge-platform`, `forge-web` 等

### 4.2 命名体系确立

**讨论过程**：
```
用户：你觉得还有其他细节没讨论吗
AI：项目名称、各服务之间怎么命名等等
用户：对的
```

**命名体系**：

| 层级 | 命名规则 | 示例 |
|------|----------|------|
| GitHub 组织 | `mirai-zen` | github.com/mirai-zen |
| 仓库名 | `forge-{service}` | `forge-gateway`, `forge-user` |
| 协议仓库 | `forge-proto` | github.com/mirai-zen/forge-proto |
| K8s Namespace | `forge-{env}` | `forge-dev`, `forge-prod` |
| Service (K8s) | `forge-{service}` | `forge-gateway`, `forge-user` |
| Docker Image | `ghcr.io/{org}/{service}` | `ghcr.io/mirai-zen/forge-gateway` |
| etcd Key | `/forge/{service}/{instance}` | `/forge/user/192.168.1.10:8080` |
| Helm Chart | `forge-{service}` | `forge-gateway`, `forge-user` |
| Log Service | `forge.{service}` | `forge.gateway`, `forge.user` |
| Prometheus Job | `job="forge-{service}"` | `job="forge-gateway"` |
| Jaeger Service | `forge-{service}` | `jaeger service: forge-gateway` |

### 4.3 开发环境确认

**硬件配置**：
| 机器 | 规格 | 用途 |
|------|------|------|
| MacBook M4 Pro | 待确认 | 主要开发机 |
| 铭凡 UM890 Pro | 8 核 16 线程 / 64GB / 1TB SSD | 测试/部署验证 |

**网络配置**：
```ssh
# ~/.ssh/config
Host mirai-zen
    HostName github.com
    User git
```

**待确认**：
- [ ] MacBook M4 Pro 具体配置（内存、macOS 版本）
- [ ] 铭凡机器的操作系统（Ubuntu？Debian？）
- [ ] 两台机器是否在同一个局域网
- [ ] 铭凡机器的 IP 地址

### 4.4 仓库策略最终决策

**讨论过程**：
```
用户：协议和代码也需要分开吧，不然其他人引用代码还会把你的源码给拉取
AI：multi-repo strategy with forge-proto
```

**最终决策**：
- ✅ Phase 0：**Monorepo 起步**（开发简单）
- ✅ Phase 1：**拆分 Multi-repo**（协议独立）

```
# Phase 0: Monorepo
github.com/mirai-zen/forge
├── backend/
│   ├── user-logic/
│   ├── gateway-logic/
│   └── platform-logic/
├── frontend/
├── deploy/
├── .github/workflows/
└── proto/

# Phase 1: Multi-repo
github.com/mirai-zen/forge              # 主仓库（前端 + 部署）
github.com/mirai-zen/forge-gateway      # Gateway 服务
github.com/mirai-zen/forge-user         # User 服务
github.com/mirai-zen/forge-platform     # Platform 服务
github.com/mirai-zen/forge-proto          # 协议仓库
```

---

## 五、关键技术决策记录

### 5.1 为什么选 go-zero 而不是 Kratos？

| 维度 | go-zero | Kratos |
|------|---------|--------|
| 企业采用率 | 腾讯/华为/美团 | B站/携程/京东 |
| 内置工具链 | goctl（API + RPC + Model） | protoc（仅代码生成） |
| 社区活跃度 | 持续上升 | 稳定 |
| 面试认可度 | 极高 | 高 |

**决策理由**：go-zero 在企业中的真实采用率更高，内置工具链更完整，goctl 能少写 50% 手工代码。

### 5.2 为什么选 etcd 而不是 Nacos？

| 维度 | etcd | Nacos |
|------|------|-------|
| 语言 | Go | Java |
| 内存占用 | ~128 MB | 1 GB+ |
| K8s 集成 | 原生（K8s 控制面数据库） | 需额外部署 |
| 共识算法 | Raft | Raft |
| 面试深度 | Raft + MVCC + Watch | 服务发现 + 配置中心 |

**决策理由**：
1. 100% Go 栈，不再需要 JVM
2. K8s 控制面核心——理解 etcd 等于理解 K8s 的心脏
3. Raft 共识算法是面试加分项

**面试话术**：
> "我选择 etcd 而不是 Nacos，主要考虑三点——100% Go 栈、K8s 原生集成、Raft 共识协议。我在前端还做了一个注册中心控制面板，实时展示服务健康状态。"

### 5.3 为什么 Phase 0 用 GHCR 而不是 Harbor？

| 维度 | GHCR | Harbor |
|------|------|--------|
| 成本 | 免费（500MB） | 自建 2.5GB 内存 |
| 运维 | 零运维 | 需维护 |
| 漏洞扫描 | Trivy（CI 侧） | 内置 Trivy |
| 适用场景 | 个人 Demo | 企业级镜像管理 |

**决策理由**：个人项目不需要镜像复制的复杂度。GHCR 和 GitHub Actions 无缝集成，Trivy 在 CI 侧完成漏洞扫描，效果一样但运维成本降到零。

### 5.4 为什么精简到 3 个微服务？

| 维度 | 6 个服务 | 3 个服务 |
|------|---------|---------|
| 开发成本 | 高（6 个独立仓库/部署） | 低（3 个核心服务） |
| 运维成本 | 高（6 个 Pod + 依赖） | 低（3 个 Pod + 依赖） |
| 演示效果 | 复杂，30 分钟讲不完 | 清晰，30 分钟讲完核心链路 |
| 面试价值 | 低（过度工程） | 高（架构思维） |

**决策理由**：1 人开发，3 个核心服务足够展示架构思维。等团队规模扩大再按康威定律垂直拆成 6 个。

**面试话术**：
> "Phase 0 用 3 个微服务演示核心架构模式——gateway 展示网关层，user 展示认证服务，platform 聚合业务能力。等团队规模扩大再按康威定律垂直拆成 6 个。"

---

## 六、踩坑记录（持续更新）

### 坑 1：Monorepo 还是 Multi-repo 起步？

**问题**：文档说 Multi-repo，但 Day 1 又在一个 repo 里操作。

**解决**：Phase 0 用 Monorepo 起步，Phase 1 拆分 Multi-repo。

**经验教训**：个人项目先跑通，再考虑企业级拆分。

### 坑 2：etcd 没有原生 UI

**问题**：etcd 只有命令行，无法直观查看服务列表。

**解决**：自研注册中心控制面板（Vue3 + WebSocket 监听 etcd Watch 事件）。

**经验教训**：工具链不完整时，需要自行补齐。

### 坑 3：Jaeger 资源占用高

**问题**：Jaeger 默认 100% 采样，内存占用 1.5GB+。

**解决**：Phase 0 先用 100% 采样（演示需要），Phase 2 降到 10%。

**经验教训**：开发环境和生产环境的配置不同，不要盲目追求最优。

---

## 七、后续规划

### 短期（Phase 0，第 1~4 周）

- [ ] 完成 3 个核心微服务
- [ ] 完成可观测性全套（Prometheus + Jaeger + Loki）
- [ ] 完成 GitOps 流水线（GitHub Actions + ArgoCD）
- [ ] 完成注册中心控制面板
- [ ] 投简历

### 中期（Phase 1，第 5~8 周）

- [ ] 3→6 微服务拆分
- [ ] 引入 qiankun 微前端
- [ ] 部署 Harbor
- [ ] 引入 MinIO + RabbitMQ

### 长期（Phase 2~3，第 9~24 周）

- [ ] Argo Rollouts Canary 灰度发布
- [ ] 安全加固（SBOM/签名/灰度/告警）
- [ ] SLSA Level 3 构建溯源
- [ ] Kyverno 准入控制
- [ ] 运维 Agent

---

## 八、面试准备清单

### 必答题（6 道）

| 问题 | 核心要点 |
|------|---------|
| 1. 为什么选 go-zero 不是 Kratos？ | 企业采用率、goctl 工具链、社区活跃度 |
| 2. 为什么 etcd 不是 Nacos？ | 100% Go 栈、K8s 原生、Raft 共识 |
| 3. 服务容错怎么做的？ | 熔断/重试/超时/兜底 |
| 4. traceID 怎么透传的？ | 中间件 → metadata → context |
| 5. GitOps 流程是什么？ | Push → GHCR → ArgoCD → K8s |
| 6. 这个项目最大的挑战是什么？ | 选一个踩坑记录展开 |
| 7. proto 为什么每个服务独立 go.mod？ | 微服务独立演进原则，互不影响 |
| 8. 跨 proto 依赖怎么管理的？ | 禁止直接 import，共享 message 走 common 模块 |
| 9. 为什么不用 v1 目录？ | 个人项目不需要十年兼容，简洁优先 |

### 加分项

- [ ] 画架构图（draw.io）
- [ ] 演示 Jaeger 瀑布图
- [ ] 讲解 Raft 共识算法
- [ ] 展示踩坑记录
- [ ] 说明 Phase 1~3 规划

---

*文档版本：v1.0*
*创建日期：2026-06-14*
*最后更新：2026-06-14*
