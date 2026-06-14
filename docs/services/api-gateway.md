# Gateway Service

> API 网关：JWT 鉴权 + 路由转发。

## 核心职责

```
客户端请求
    │
    ▼
Gateway
    ├── 1. JWT 鉴权（从 Header 提取 token）
    ├── 2. 路由转发（根据 path 转发到对应服务）
    └── 3. 响应返回
```

## 接口设计

| 接口 | 方法 | 路径 | 说明 |
|------|------|------|------|
| 用户服务代理 | * | /api/user/* | 转发到 user-service |
| 平台服务代理 | * | /api/platform/* | 转发到 platform-service |

## 技术要点

- go-zero rest 中间件做 JWT 校验
- 不需要额外引入 API Gateway 组件（Kong/APISIX）
- 通过 etcd 发现下游服务地址
- 统一返回格式（code + message + data）

## 待讨论

- [ ] 是否需要限流？
- [ ] 是否需要请求日志记录？
- [ ] 是否需要 CORS 配置？
- [ ] 错误码规范？
