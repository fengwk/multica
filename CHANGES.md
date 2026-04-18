# 变更记录

## 2026-04-19

### 自部署 SSO 的代理认证桥接

- 新增后端桥接接口 `GET /auth/proxy-login`，用于对接反向代理或统一认证系统。
- 只要设置了 `MULTICA_PROXY_AUTH_EMAIL_HEADER`，就视为开启代理认证。
- 后端会读取配置指定的邮箱请求头，查找或创建对应的 Multica 用户，下发 `multica_auth` 与 `multica_csrf` Cookie，并重定向到目标页面。
- 自动创建用户时，默认使用邮箱 `@` 前面的部分作为显示名称。

### 配置模型简化

- 移除了单独的开关变量 `MULTICA_PROXY_AUTH_ENABLED`。
- 移除了可选的代理认证共享密钥逻辑。
- 移除了可选的用户名请求头逻辑。
- 当前最小后端配置为：

```env
MULTICA_PROXY_AUTH_EMAIL_HEADER=X-Auth-Request-Email
```

- 当 `MULTICA_PROXY_AUTH_EMAIL_HEADER` 为空或未设置时，代理认证保持关闭。

### Web 登录自动跳转

- 当构建时设置了 `NEXT_PUBLIC_PROXY_AUTH_EMAIL_HEADER`，Web 登录页会自动将 `/login` 跳转到 `/auth/proxy-login`。
- 通过 `proxy_auth_done=1` 保留 CLI 登录续接流程，避免重定向死循环。
- 在 `docker-compose.selfhost.yml` 中，前端构建参数 `NEXT_PUBLIC_PROXY_AUTH_EMAIL_HEADER` 会自动继承 `MULTICA_PROXY_AUTH_EMAIL_HEADER`。

### 接入说明

- 对于放在已认证反向代理后的最小化自部署场景，只需要转发当前登录用户邮箱：

```http
X-Auth-Request-Email: user@example.com
```

- 不再需要额外的代理认证密钥，也不需要额外的用户名请求头。

### 验证

- 已通过以下 Go Handler 定向测试验证：

```bash
env -u GOROOT go test ./internal/handler -run 'TestProxyLogin|TestSendCode|TestVerifyCode'
```

### GitHub Actions 调整

- 移除了原有的 `CI` 与 `Release` 工作流。
- 新增 `docker-publish.yml`，在 `docker` 分支收到 push 时自动构建并推送 Docker Hub 镜像。
- 发布方式改为单镜像 `fengwk/multica`，镜像内同时包含 Web 与 Backend 运行时。
- 需要在 GitHub 仓库中配置：
  - `DOCKERHUB_USERNAME`（secret）
  - `DOCKERHUB_TOKEN`（secret）
  - `DOCKERHUB_NAMESPACE`（variable，可选；未设置时回退到 `DOCKERHUB_USERNAME`）
- 单镜像构建时会读取以下仓库变量作为 build args：
  - `NEXT_PUBLIC_GOOGLE_CLIENT_ID`
  - `NEXT_PUBLIC_WS_URL`
  - `MULTICA_PROXY_AUTH_EMAIL_HEADER`

### Docker 单镜像模式

- 新增 `Dockerfile.multica`，在同一个镜像中构建并打包：
  - Go backend / migrate / CLI 二进制
  - Next.js standalone Web 产物
- 新增 `docker/entrypoint.multica.sh`，容器启动时会：
  1. 先执行数据库迁移
  2. 在容器内启动 backend（默认 `127.0.0.1:8080` 对应的内部访问目标）
  3. 启动 web（对外提供 `3000` 端口）
- Web 在构建时固定转发到 `http://127.0.0.1:8080`，不再依赖部署环境中的容器别名或服务名。
