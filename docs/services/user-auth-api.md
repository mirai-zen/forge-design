# User Service

> 用户认证与身份管理服务。

## 接口设计

| 接口 | 方法 | 路径 | 说明 |
|------|------|------|------|
| 注册 | POST | /api/user/register | 用户名 + 密码 + 邮箱 |
| 登录 | POST | /api/user/login | 返回 JWT Token |
| 获取当前用户 | GET | /api/user/me | 需 JWT 认证 |

## 数据模型

```
users
├── id          BIGINT PK
├── username    VARCHAR(64) UNIQUE
├── password    VARCHAR(256)  (bcrypt hash)
├── email       VARCHAR(128)
├── created_at  TIMESTAMP
└── updated_at  TIMESTAMP
```

## 技术要点

- JWT 签发与验证（go-zero jwt 中间件）
- 密码 bcrypt 加密
- 用户注册不允许重名
- 服务注册到 etcd（`/forge/user/...`）

## 待讨论

- [ ] 是否需要修改密码功能？
- [ ] 是否需要角色/权限（RBAC）？
- [ ] 是否需要邮箱验证？
- [ ] 是否需要刷新 token？
