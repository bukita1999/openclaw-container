# OpenClaw Ubuntu Container

这个仓库把 `OpenClaw`、`uv` 和可选的 `Chromium + VNC + noVNC`、`Go` 全部安装在容器内部，宿主机只需要 `Docker Engine + Docker Compose`。

## 设计目标

- 基础镜像固定为 `ubuntu:24.04`
- `OpenClaw` 通过 `npm install -g openclaw@latest` 安装在镜像里
- `uv` 通过官方安装脚本安装，并在镜像构建时预装一个由 `uv` 管理的 Python
- `Go` 按官方 tarball 方式可选安装在镜像里
- `Chromium + Xvfb + x11vnc + noVNC` 可选安装在镜像里
- 代理通过 `.env` 注入，同时作用于构建阶段和运行阶段
- OpenClaw 配置目录、workspace、uv 缓存、uv Python、Go 工作区、Playwright 浏览器缓存全部映射到宿主机

## 目录映射

- `./data/openclaw` -> `/home/openclaw/.openclaw`
- `./data/workspace` -> `/home/openclaw/.openclaw/workspace`
- `./data/uv-cache` -> `/home/openclaw/.cache/uv`
- `./data/uv-python` -> `/opt/uv/python`
- `./data/go` -> `/home/openclaw/go`
- `./data/playwright` -> `/opt/ms-playwright`

OpenClaw 主配置文件路径：

- 宿主机：`./data/openclaw/openclaw.json`
- 容器内：`/home/openclaw/.openclaw/openclaw.json`

仓库默认已经提供正式配置文件：

- `./data/openclaw/openclaw.json`

仓库同时保留一个示例副本：

- `./data/openclaw/openclaw.json.example`

当前正式版 `openclaw.json` 已经采用 `.env` 注入方式，所以只需要在 `.env` 里填写：

```env
TELEGRAM_BOT_TOKEN=
DISCORD_BOT_TOKEN=
BAILIAN_API_KEY=
```

注意：OpenClaw 的 `${VAR}` 配置替换要求变量非空；如果 `openclaw.json` 里使用了 `${TELEGRAM_BOT_TOKEN}` 这类写法，而 `.env` 里仍是空值，配置加载会报错。

## 快速开始

1. 先按需编辑 `.env`
2. 构建镜像
3. 启动容器

```bash
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

如果只想直接启动网关，`docker compose up -d` 已经会自动执行：

```bash
openclaw gateway --bind lan --port 18789 --allow-unconfigured
```

## 可选组件开关

在 `.env` 里修改后重新 `docker compose build`：

```env
INSTALL_GO=1
INSTALL_CHROMIUM=1
INSTALL_VNC=1
```

运行期如果要启动 VNC/noVNC 与可视 Chromium，再打开：

```env
ENABLE_VNC=1
START_CHROMIUM=1
```

然后重新启动容器：

```bash
docker compose up -d
```

访问：

- OpenClaw Gateway: `http://127.0.0.1:18789`
- noVNC: `http://127.0.0.1:6080/vnc.html`
- VNC: `127.0.0.1:5900`

## 代理说明

在 `.env` 里设置：

```env
HTTP_PROXY=http://host.docker.internal:7890
HTTPS_PROXY=http://host.docker.internal:7890
ALL_PROXY=http://host.docker.internal:7890
NO_PROXY=127.0.0.1,localhost
```

这些变量会：

- 作为 `docker compose build` 的 build args 传入 Dockerfile
- 作为容器运行时环境变量注入
- 在容器入口脚本里同步到 `git` 和 `npm` 用户级配置

注意：

- `.env` 能控制容器内的构建和运行时网络访问
- 但 Docker 守护进程自己拉取 `ubuntu:24.04`、安装阶段访问远程 registry 时，如果宿主机 Docker daemon 本身也需要代理，仍然要单独配置宿主机 Docker 的代理

## 常用命令

检查版本：

```bash
docker compose exec openclaw openclaw --version
docker compose exec openclaw uv --version
docker compose exec openclaw python --version
docker compose exec openclaw go version
```

OpenClaw dashboard 链接：

```bash
docker compose exec openclaw openclaw dashboard --no-open
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
