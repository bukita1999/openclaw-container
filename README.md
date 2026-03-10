# 🦞 OpenClaw Debian Container

这个仓库把 `OpenClaw`、`uv` 和可选的 `CDP Browser + VNC + noVNC`、`Go` 全部安装在容器内部，宿主机只需要 `Docker Engine + Docker Compose`。

默认模板现在会在容器启动后直接拉起容器内 Chromium，并把 OpenClaw browser tool 绑定到本地 CDP。也就是说，只要按模板启动，`docker compose up -d` 之后就可以直接用浏览器工具，不需要再手工进容器执行 `openclaw browser start`。

仓库现在同时支持两种用法：

- 🧍 单实例：沿用根目录 `.env` 和 `data/*`（未经人类测试）
- 🤖 多实例：推荐模式，一个仓库配多个 `instances/<bot-name>/`

如果你是第一次做多个机器人，建议直接用多实例模式，不要复制多个仓库。

## 🚀 QUICKSTART（经验版）

- ✨ **这是一个 vibe coding 项目，主要为了个人使用便捷而维护。**
- 🧪 **文档和代码组织并不追求“企业级规范”，如果你觉得顺手可以试用。**
- 🧠 **强烈建议你对 OpenClaw 已有一定折腾基础。**
- 🧭 这个项目的核心尝试是：在一个仓库里管理多个 bot（也支持只跑一个 bot）。

### 1️⃣ 先准备根目录 `.env`

```bash
cp .env.example .env
```

先确保本机有 `docker compose`。  
**强烈建议中国大陆网络环境配置代理**，把代理相关变量写到根目录 `.env`：

```env
HTTP_PROXY=http://host.docker.internal:7890
HTTPS_PROXY=http://host.docker.internal:7890
ALL_PROXY=http://host.docker.internal:7890
NO_PROXY=127.0.0.1,localhost
NODE_USE_ENV_PROXY=1
```

### 2️⃣ 选择构建组件（建议值）

个人建议：除了 Go 之外都装。Go 是历史残留能力，之前踩过坑，为了兼容场景先保留开关，但默认建议关闭。

```env
INSTALL_CHROMIUM=1
INSTALL_VNC=1
INSTALL_GO=0
USE_SJTUG_MIRROR=1
```

- **`USE_SJTUG_MIRROR=1` 推荐开启，用交大源加速构建。**
- **如果构建过程出现镜像相关问题，请改回 `USE_SJTUG_MIRROR=0` 再试。**

### 3️⃣ 构建镜像

```bash
docker compose build --no-cache
```

### 4️⃣ 新建一个机器人实例

最省事方式：让 agent 直接阅读 [docs/create-new-bot.md](./docs/create-new-bot.md) 并按文档执行。

也可以手动创建（示例 `bot-example`）：

```bash
cp -a instances/_template instances/bot-example
mv instances/bot-example/.env.example instances/bot-example/.env
cp instances/bot-example/openclaw/openclaw.json.example instances/bot-example/openclaw/openclaw.json
```

### 5️⃣ 配置实例 `.env` 与 `openclaw.json`

`instances/bot-example/.env` 里重点配置：

- 代理（**没有代理时，Docker 拉取和 Discord 相关网络请求常见失败**）
- Telegram 或 Discord token（至少一个非空）
- 你的 provider API key（当前示例默认偏向阿里百炼 Coding Plan）

`instances/bot-example/openclaw/openclaw.json` 是每个 bot 的具体行为配置。详细字段以 OpenClaw 官方文档为准。  
后续如果有更多用户场景，可以把 provider 配置模板继续泛化（`TODO`）。

### 6️⃣ 运行与排错建议

- 单实例启动命令：
```bash
docker compose up -d
```

- 多实例启动命令（把 `bot-example` 替换成你的实例名）：

```bash
docker compose --env-file ./instances/bot-example/.env -p bot-example up -d
```

- **更推荐使用非 root 用户运行容器，能减少一些奇怪权限问题。**
- 如果启动失败，优先检查 `UID/GID` 是否匹配，并结合日志定位问题。
- **非常推荐使用 Claude Code / Codex / OpenCode 等 AI 工具辅助分析日志、解释源码和调整配置。**

## 🎯 设计目标

- 基础镜像固定为 `debian:12-slim`。
- 镜像内预装 `OpenClaw + uv + Python`，可选安装 `Chromium/VNC/Go`。
- 代理变量通过 `.env` 同时作用于构建和运行时。
- 关键状态目录映射到宿主机，便于持久化和迁移。
- 同一份镜像复用到多实例，实例差异由 `.env`、`openclaw.json`、挂载目录和端口决定。

## 🧭 运行模式

- 单实例：使用根目录 `.env` + `data/*`。
- 多实例（推荐）：使用 `instances/<bot>/`，一个实例一套配置和数据。

创建新 bot 时，优先按 [docs/create-new-bot.md](./docs/create-new-bot.md) 操作。

### 单实例最小步骤

```bash
cp .env.example .env
cp data/openclaw/openclaw.json.example data/openclaw/openclaw.json
docker compose build
docker compose up -d
docker compose logs -f
```

### 多实例最小步骤

```bash
cp -a instances/_template instances/bot-mybot
mv instances/bot-mybot/.env.example instances/bot-mybot/.env
cp instances/bot-mybot/openclaw/openclaw.json.example instances/bot-mybot/openclaw/openclaw.json

# 编辑 .env 与 openclaw.json 后执行
docker compose --env-file ./instances/bot-mybot/.env -p bot-mybot config
docker compose --env-file ./instances/bot-mybot/.env -p bot-mybot up -d
docker compose --env-file ./instances/bot-mybot/.env -p bot-mybot logs -f
```

不推荐 `docker compose up --scale`，这里需要的是“不同参数的多实例”，不是“同配置副本扩容”。

## 🏗️ 构建规则（精简版）

- 根目录 `.env` 是共享构建默认值（`OPENCLAW_VERSION`、`PYTHON_VERSION`、`INSTALL_*` 等）。
- 实例 `.env` 主要放运行时覆盖（token、挂载目录、实例端口）。
- 只要构建期变量不变，多个实例共享一份镜像即可。

分阶段验证可用：

```bash
BUILD_TARGET=openclaw-base docker compose build
BUILD_TARGET=openclaw-core docker compose build
BUILD_TARGET=openclaw-runtime docker compose build
```

如果某实例必须使用不同构建开关，请给它单独 `IMAGE_NAME`，再用该实例 `.env` 执行 `build/up`。

## 🧩 可选组件与端口

需要重建镜像的开关（改完要 `docker compose build`）：

- `INSTALL_CHROMIUM`
- `INSTALL_VNC`
- `INSTALL_GO`

常用运行时开关（通常改完重启实例即可）：

- `START_CHROMIUM`
- `ENABLE_VNC`
- `CHROMIUM_HEADLESS`
- `CHROMIUM_EXTRA_ARGS`

端口约定：

- noVNC 固定在容器内 `6080`，通过宿主机 `NOVNC_PORT` 发布。
- `VNC_PORT`、`CHROMIUM_REMOTE_DEBUGGING_PORT` 默认容器内使用。
- 多实例务必保证宿主机端口不冲突（至少 `NOVNC_PORT`、网关端口要唯一）。

## 🌐 代理

在 `.env`（或实例 `.env`）设置：

```env
HTTP_PROXY=http://host.docker.internal:7890
HTTPS_PROXY=http://host.docker.internal:7890
ALL_PROXY=http://host.docker.internal:7890
NO_PROXY=127.0.0.1,localhost
NODE_USE_ENV_PROXY=1
```

- `NODE_USE_ENV_PROXY=1` 可让 Node.js 运行时请求复用代理环境变量。
- `USE_SJTUG_MIRROR=1` 可加速构建；如果镜像源异常，切回 `0`。
- 若宿主机 Docker daemon 也需要代理，需另外配置 Docker daemon 代理。

## 🚚 运维（迁移 / 备份 / 升级）

最小可恢复备份：

- `instances/<bot>/.env`
- `instances/<bot>/openclaw/`
- `instances/<bot>/workspace/`

整实例备份（推荐）：

```bash
docker compose --env-file ./instances/bot-example/.env -p bot-example down
tar czf bot-example-backup-$(date +%F).tar.gz ./instances/bot-example
```

迁移到新机器：

```bash
tar xzf bot-example-backup-YYYY-MM-DD.tar.gz
docker compose build
docker compose --env-file ./instances/bot-example/.env -p bot-example up -d
docker compose --env-file ./instances/bot-example/.env -p bot-example logs -f
```

升级建议：先备份一个实例，先升级并验证一个试点实例，再逐个滚动到其他实例。

## 🛠️ 常用命令

```bash
# 单实例
docker compose logs -f
docker compose exec openclaw openclaw --version
docker compose exec openclaw openclaw dashboard --no-open

# 多实例
# 把 bot-example 替换成你的实例名
docker compose --env-file ./instances/bot-example/.env -p bot-example logs -f
docker compose --env-file ./instances/bot-example/.env -p bot-example exec openclaw openclaw --version
docker compose --env-file ./instances/bot-example/.env -p bot-example down
```

## 📚 参考依据

- OpenClaw README: https://github.com/openclaw/openclaw
- OpenClaw Docker 文档: https://docs.openclaw.ai/install/docker
- OpenClaw 官方 Dockerfile: https://github.com/openclaw/openclaw/blob/main/Dockerfile
- uv 安装文档: https://docs.astral.sh/uv/getting-started/installation/
- uv Docker 集成文档: https://docs.astral.sh/uv/guides/integration/docker/
- Docker 代理文档: https://docs.docker.com/engine/cli/proxy/
