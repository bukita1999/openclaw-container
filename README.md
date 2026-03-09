# OpenClaw Debian Container

这个仓库把 `OpenClaw`、`uv` 和可选的 `CDP Browser + VNC + noVNC`、`Go` 全部安装在容器内部，宿主机只需要 `Docker Engine + Docker Compose`。

默认模板现在会在容器启动后直接拉起容器内 Chromium，并把 OpenClaw browser tool 绑定到本地 CDP。也就是说，只要按模板启动，`docker compose up -d` 之后就可以直接用浏览器工具，不需要再手工进容器执行 `openclaw browser start`。

仓库现在同时支持两种用法：

- 单实例：沿用根目录 `.env` 和 `data/*`
- 多实例：推荐模式，一个仓库配多个 `instances/<bot-name>/`

如果你是第一次做多个机器人，建议直接用多实例模式，不要复制多个仓库。

## 设计目标

- 基础镜像固定为 `debian:12-slim`
- `OpenClaw` 通过 `npm install -g openclaw@latest` 安装在镜像里
- `uv` 通过官方安装脚本安装，并在镜像构建时预装一个由 `uv` 管理的 Python
- `Go` 按官方 tarball 方式可选安装在镜像里
- 可选浏览器通过 Debian `chromium` 包安装，并默认暴露 CDP
- 代理通过 `.env` 注入，同时作用于构建阶段和运行阶段
- OpenClaw 配置目录、workspace、uv 缓存、uv Python、Go 工作区、Chromium profile 全部映射到宿主机
- 同一份镜像可被多个机器人实例复用，真正变化的是配置和数据目录

## 为什么推荐多实例 Compose

这个项目的差异点主要是：

- `openclaw.json`
- `.env`
- 端口
- 宿主机挂载目录

它并不是“多服务复杂编排”问题，而是“同一镜像的多套配置实例化”问题。所以当前阶段更适合：

- 一个仓库
- 一份 `docker-compose.yml`
- 一次镜像构建
- 多个实例目录

不建议一机器人一个仓库，也不建议第一次就上 `k8s` 或 `k3s`。先把单机多实例跑稳，再考虑更重的编排系统。

## 单实例模式

如果你只跑一个机器人，继续使用根目录 `.env` 和 `data/*` 即可。

默认目录映射：

- `./data/openclaw` -> `/home/openclaw/.openclaw`
- `./data/workspace` -> `/home/openclaw/.openclaw/workspace`
- `./data/uv-cache` -> `/home/openclaw/.cache/uv`
- `./data/uv-python` -> `/opt/uv/python`
- `./data/go` -> `/home/openclaw/go`
- `./data/chromium-profile` -> `/home/openclaw/.config/chromium-profile`

OpenClaw 主配置文件路径：

- 宿主机：`./data/openclaw/openclaw.json`
- 容器内：`/home/openclaw/.openclaw/openclaw.json`

仓库默认跟踪的是示例配置：

- `./data/openclaw/openclaw.json.example`

真实运行配置 `./data/openclaw/openclaw.json` 会包含网关 token、配对状态或运行时变更，不建议提交到 Git；仓库已默认忽略该文件。

### 单实例快速开始

1. 复制根目录环境变量模板。
2. 按需填写 token、provider key 和开关。
3. 复制示例 `openclaw.json`。
4. 构建并启动。

```bash
cp .env.example .env
cp data/openclaw/openclaw.json.example data/openclaw/openclaw.json
docker compose build
docker compose up -d
```

查看日志：

```bash
docker compose logs -f
```

进入容器：

```bash
docker compose exec openclaw bash
```

首次交互式初始化：

```bash
docker compose exec openclaw openclaw onboard
```

## 多实例模式

多实例模式的核心思路是：

- 镜像共用
- 每个机器人一份 `.env`
- 每个机器人一份 `openclaw.json`
- 每个机器人一套独立数据目录

推荐目录结构：

```text
instances/
  bot-example/
    .env
    openclaw/
      openclaw.json
    workspace/
    uv-cache/
    uv-python/
    go/
    chromium-profile/
  bot-example-2/
    .env
    openclaw/
      openclaw.json
    workspace/
    uv-cache/
    uv-python/
    go/
    chromium-profile/
```

仓库提供了一个可复制模板：

- `./instances/_template/.env.example`
- `./instances/_template/openclaw/openclaw.json.example`

仓库同时附带了一份可直接修改的示例实例：

- `./instances/bot-example/.env`
- `./instances/bot-example/openclaw/openclaw.json`

这份 `bot-example` 默认把 Telegram 和 Discord 频道都设为 `enabled: false`，并使用占位 token。这样你第一次试多实例时，不会因为忘记替换 token 就误连真实外部通道。

### 多实例下的镜像构建规则

默认建议所有实例共用同一份镜像，也就是这些构建期变量保持一致：

- `NODE_MAJOR`
- `OPENCLAW_VERSION`
- `PYTHON_VERSION`
- `INSTALL_CHROMIUM`
- `INSTALL_VNC`
- `INSTALL_GO`
- `GO_VERSION`
- `USE_SJTUG_MIRROR`

这样你只需要构建一次：

```bash
docker compose build
```

如果某个实例确实需要不同的镜像内容，例如只给某一个 bot 开启 `INSTALL_VNC=1`，那就不要和其他实例共用同一个 `IMAGE_NAME`。请给它单独设置镜像名，例如：

```env
IMAGE_NAME=openclaw-debian:bot-example-vnc
```

然后再用该实例自己的 `.env` 构建和启动：

```bash
docker compose --env-file ./instances/bot-example/.env -p bot-example build
docker compose --env-file ./instances/bot-example/.env -p bot-example up -d
```

### 第一次创建实例

下面以 `bot-example` 为例。

1. 复制模板目录。

```bash
cp -a instances/_template instances/bot-example
```

2. 把模板文件改成真实运行文件。

```bash
mv instances/bot-example/.env.example instances/bot-example/.env
cp instances/bot-example/openclaw/openclaw.json.example instances/bot-example/openclaw/openclaw.json
```

3. 编辑 `instances/bot-example/.env`。

最重要的是这几类变量：

- `INSTANCE_ENV_FILE=./instances/bot-example/.env`
- `CONTAINER_NAME=openclaw-bot-example`
- `OPENCLAW_CONTAINER_HOSTNAME=openclaw-bot-example`
- `OPENCLAW_CONFIG_DIR=./instances/bot-example/openclaw`
- `OPENCLAW_WORKSPACE_DIR=./instances/bot-example/workspace`
- `UV_CACHE_DIR_HOST=./instances/bot-example/uv-cache`
- `UV_PYTHON_DIR_HOST=./instances/bot-example/uv-python`
- `GO_PATH_HOST=./instances/bot-example/go`
- `CHROMIUM_PROFILE_DIR_HOST=./instances/bot-example/chromium-profile`
- `OPENCLAW_GATEWAY_PORT` / `OPENCLAW_BRIDGE_PORT`
- `VNC_PORT` / `NOVNC_PORT`
- `CHROMIUM_HEADLESS`
- `CHROMIUM_EXTRA_ARGS`
- `CHROMIUM_REMOTE_DEBUGGING_PORT`
- `OPENCLAW_GATEWAY_TOKEN`
- `TELEGRAM_BOT_TOKEN`
- `DISCORD_BOT_TOKEN`
- `BAILIAN_API_KEY`

4. 编辑 `instances/bot-example/openclaw/openclaw.json`。

如果里面使用了 `${VAR}` 这种变量替换，`.env` 对应变量必须非空。否则 OpenClaw 启动时会报配置错误。

这里的 `INSTANCE_ENV_FILE` 也必须指向这个实例自己的 `.env`。compose 会用它把同一份文件重新注入到容器运行时环境里。

### 启动第一个实例

镜像通常只需要构建一次：

```bash
docker compose build
```

启动 `bot-example`：

```bash
docker compose --env-file ./instances/bot-example/.env -p bot-example up -d
```

看日志：

```bash
docker compose --env-file ./instances/bot-example/.env -p bot-example logs -f
```

进入容器：

```bash
docker compose --env-file ./instances/bot-example/.env -p bot-example exec openclaw bash
```

停止实例：

```bash
docker compose --env-file ./instances/bot-example/.env -p bot-example down
```

### 创建第二个实例

不要复制整个仓库，只复制实例目录：

```bash
cp -a instances/bot-example instances/bot-example-2
```

然后修改 `instances/bot-example-2/.env` 里的以下内容：

- `INSTANCE_ENV_FILE=./instances/bot-example-2/.env`
- `CONTAINER_NAME=openclaw-bot-example-2`
- `OPENCLAW_CONTAINER_HOSTNAME=openclaw-bot-example-2`
- 所有挂载目录路径改成 `./instances/bot-example-2/...`
- 所有 token 改成 bot-example-2 自己的值
- 端口改成不冲突的新值

启动：

```bash
docker compose --env-file ./instances/bot-example-2/.env -p bot-example-2 up -d
```

### 多实例模式下，哪些东西必须隔离

必须隔离：

- `openclaw.json`
- `.env`
- `workspace`
- `container_name`
- 宿主机卷目录

通常也要隔离：

- `OPENCLAW_GATEWAY_PORT`
- `OPENCLAW_BRIDGE_PORT`
- `VNC_PORT`
- `NOVNC_PORT`

第一次上手建议连缓存目录也全部隔离。先保证不串数据、不互相污染，等跑稳以后再考虑是否共享 `uv-python` 或 `chromium-profile`。

### 为什么这里不推荐 `docker compose up --scale`

`--scale` 适合同一个服务的多个同配置副本。

你的机器人实例至少有这些差异：

- `.env` 不同
- `openclaw.json` 不同
- token 不同
- 端口可能不同
- workspace 不同

所以这里需要的是“参数化多实例”，不是“同配置副本扩容”。

## 可选组件开关

在 `.env` 或实例级 `.env` 里修改后重新 `docker compose build`：

```env
INSTALL_GO=1
INSTALL_CHROMIUM=1
INSTALL_VNC=1
```

默认模板已经会在容器启动后直接拉起 Chromium，并让 OpenClaw browser tool 连接到：

```env
START_CHROMIUM=1
CHROMIUM_REMOTE_DEBUGGING_PORT=9222
```

如果你还要额外打开 VNC/noVNC 观察桌面，再打开：

```env
ENABLE_VNC=1
CHROMIUM_HEADLESS=0
```

然后重新启动对应实例：

```bash
docker compose up -d
```

或者在多实例模式下：

```bash
docker compose --env-file ./instances/bot-example/.env -p bot-example up -d
```

访问：

- OpenClaw Gateway: `http://127.0.0.1:18789`
- noVNC: `http://127.0.0.1:6080/vnc.html`
- VNC: `127.0.0.1:5900`
- OpenClaw browser tool: 默认连接 `http://127.0.0.1:9222`
- Chromium CDP: `http://127.0.0.1:9222/json/version`

多实例时请务必给每个实例分配不冲突的主机端口。

## 代理说明

在 `.env` 或实例级 `.env` 里设置：

```env
HTTP_PROXY=http://host.docker.internal:7890
HTTPS_PROXY=http://host.docker.internal:7890
ALL_PROXY=http://host.docker.internal:7890
NO_PROXY=127.0.0.1,localhost
```

如果你希望构建阶段优先使用交大镜像，可额外设置：

```env
USE_SJTUG_MIRROR=1
```

这些变量会：

- 作为 `docker compose build` 的 build args 传入 Dockerfile
- 作为容器运行时环境变量注入
- 在容器入口脚本里同步到 `git` 和 `npm` 用户级配置

注意：

- `.env` 能控制容器内的构建和运行时网络访问
- Docker 守护进程自己拉取 `debian:12-slim`、安装阶段访问远程 registry 时，如果宿主机 Docker daemon 本身也需要代理，仍然要单独配置宿主机 Docker 的代理
- `USE_SJTUG_MIRROR=1` 目前会在构建阶段把 Debian 软件源切到 SJTUG，并让 `npm install` 使用 `https://mirrors.sjtug.sjtu.edu.cn/npm-registry`
- 因为 SJTUG 的 `apt` 源走 HTTPS，Dockerfile 里会先安装 `ca-certificates` 再切换镜像，避免证书缺失导致 `apt-get update` 失败
- Debian security 源也会一起切到 SJTUG；如果你更看重安全更新时效，可以保持 `USE_SJTUG_MIRROR=0`

## 迁移方案

迁移的最小单位不是整个仓库，而是单个实例目录。

例如迁移 `bot-example` 时，真正关键的是：

- `instances/bot-example/.env`
- `instances/bot-example/openclaw/`
- `instances/bot-example/workspace/`

其余如 `uv-cache`、`uv-python`、`chromium-profile` 可以一起迁，也可以在新机器重建。

### 推荐迁移步骤

1. 在旧机器停止实例，保证状态一致。
2. 打包实例目录。
3. 在新机器准备同一份仓库代码。
4. 解压实例目录到相同位置。
5. 在新机器构建镜像。
6. 启动实例并看日志确认恢复。

旧机器：

```bash
docker compose --env-file ./instances/bot-example/.env -p bot-example down
tar czf bot-example-backup.tar.gz ./instances/bot-example
```

新机器：

```bash
tar xzf bot-example-backup.tar.gz
docker compose build
docker compose --env-file ./instances/bot-example/.env -p bot-example up -d
docker compose --env-file ./instances/bot-example/.env -p bot-example logs -f
```

如果新机器目录路径变了，请同步调整 `instances/bot-example/.env` 里的主机挂载路径和端口。

## 备份方案

建议做两层备份。

### 第一层：最小可恢复备份

这是必须备份的核心状态：

- `instances/<bot>/.env`
- `instances/<bot>/openclaw/`
- `instances/<bot>/workspace/`

### 第二层：整实例目录备份

更省心的做法是直接备份整个实例目录：

- `instances/<bot>/`

这样恢复时最简单，也最不容易漏文件。

### 推荐策略

- 每天备份 `openclaw/` 和 `workspace/`
- 每周打包一次整个 `instances/`
- 升级 OpenClaw 或改镜像前，先手工备份将要升级的实例

### 备份时机

第一次实践时，建议先停容器再备份：

```bash
docker compose --env-file ./instances/bot-example/.env -p bot-example down
tar czf bot-example-backup-$(date +%F).tar.gz ./instances/bot-example
```

这样最稳，也最容易确认恢复结果。

## 升级建议

镜像升级时，不要一次升级所有实例。建议这样做：

1. 先备份一个实例。
2. `docker compose build` 重建镜像。
3. 先启动一个试点实例。
4. 确认日志、通道和行为正常。
5. 再逐个升级其他实例。

这比同时升级全部实例更容易回滚。

## 常用命令

单实例模式：

```bash
docker compose logs -f
docker compose exec openclaw openclaw --version
docker compose exec openclaw uv --version
docker compose exec openclaw python --version
docker compose exec openclaw go version
docker compose exec openclaw openclaw dashboard --no-open
```

多实例模式：

```bash
docker compose --env-file ./instances/bot-example/.env -p bot-example logs -f
docker compose --env-file ./instances/bot-example/.env -p bot-example exec openclaw openclaw --version
docker compose --env-file ./instances/bot-example/.env -p bot-example exec openclaw openclaw dashboard --no-open
```

## 参考依据

- OpenClaw README: https://github.com/openclaw/openclaw
- OpenClaw Docker 文档: https://docs.openclaw.ai/install/docker
- OpenClaw 官方 Dockerfile: https://github.com/openclaw/openclaw/blob/main/Dockerfile
- OpenClaw 官方 browser sandbox: https://github.com/openclaw/openclaw/blob/main/Dockerfile.sandbox-browser
- uv 安装文档: https://docs.astral.sh/uv/getting-started/installation/
- uv Docker 集成文档: https://docs.astral.sh/uv/guides/integration/docker/
- Go 安装文档: https://go.dev/doc/install
- Docker 代理文档: https://docs.docker.com/engine/cli/proxy/

## 当前上游版本（调研日期：2026-03-08）

- `openclaw` npm 最新版本：`2026.3.7`
- `Go` 最新版本：`1.26.1`
- `OpenClaw` 官方要求运行时：`Node >= 22`
- `./data/chromium-profile` -> `/home/openclaw/.config/chromium-profile`
