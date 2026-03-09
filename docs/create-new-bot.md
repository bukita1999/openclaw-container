# Create a New Bot

This repository is designed for multi-instance usage. To add a new bot, create a new directory under `instances/` instead of copying the whole repository.

## 1. Copy the Template

Create a new instance named `bot-mybot`:

```bash
cp -a instances/_template instances/bot-mybot
mv instances/bot-mybot/.env.example instances/bot-mybot/.env
cp instances/bot-mybot/openclaw/openclaw.json.example instances/bot-mybot/openclaw/openclaw.json
```

The root [.env](/home/cao/docker-compose/openclaw-container/.env) remains the shared default for image build/install options such as `INSTALL_CHROMIUM`, `INSTALL_VNC`, `OPENCLAW_VERSION`, and `PYTHON_VERSION`. Build the shared image from the root config first; the instance `.env` should usually only override runtime behavior.

## 2. Edit the Instance `.env`

Update [instances/bot-mybot/.env](/home/cao/docker-compose/openclaw-container/instances/bot-mybot/.env) so every path and identity points to the new instance:

```env
INSTANCE_ENV_FILE=./instances/bot-mybot/.env
CONTAINER_NAME=openclaw-bot-mybot
OPENCLAW_CONTAINER_HOSTNAME=openclaw-bot-mybot
OPENCLAW_CONFIG_DIR=./instances/bot-mybot/openclaw
OPENCLAW_WORKSPACE_DIR=./instances/bot-mybot/workspace
UV_CACHE_DIR_HOST=./instances/bot-mybot/uv-cache
UV_PYTHON_DIR_HOST=./instances/bot-mybot/uv-python
GO_PATH_HOST=./instances/bot-mybot/go
CHROMIUM_PROFILE_DIR_HOST=./instances/bot-mybot/chromium-profile
```

Also set unique host ports if you choose to publish them yourself:

- `NOVNC_PORT`

`VNC_PORT` and `CHROMIUM_REMOTE_DEBUGGING_PORT` are now intended for
container-internal use by default and do not need unique host mappings for
multi-instance setups. noVNC always listens on container port `6080`; `NOVNC_PORT` remains published so you can access the
desktop from outside the container.

Do not copy shared build defaults into the instance `.env` unless this bot truly
needs a different image. In most cases, leave these values in the root
[.env](/home/cao/docker-compose/openclaw-container/.env):

- `BUILD_TARGET`
- `IMAGE_NAME`
- `NODE_MAJOR`
- `OPENCLAW_VERSION`
- `PYTHON_VERSION`
- `INSTALL_CHROMIUM`
- `INSTALL_VNC`
- `INSTALL_GO`
- `GO_VERSION`
- `USE_SJTUG_MIRROR`
- `USER_UID`
- `USER_GID`
- `TZ`

If the bot needs an outbound proxy, set these in the instance `.env` too:

```env
HTTP_PROXY=http://host.docker.internal:7890
HTTPS_PROXY=http://host.docker.internal:7890
ALL_PROXY=http://host.docker.internal:7890
NO_PROXY=127.0.0.1,localhost
NODE_USE_ENV_PROXY=1
```

`NODE_USE_ENV_PROXY=1` makes Node.js runtime requests reuse the proxy
environment variables, which matters for dependencies that use native `fetch`.

At least one channel token must be non-empty:

- `TELEGRAM_BOT_TOKEN`, or
- `DISCORD_BOT_TOKEN`

If both are empty, the container exits during startup.

## 3. Edit `openclaw.json`

Update [instances/bot-mybot/openclaw/openclaw.json](/home/cao/docker-compose/openclaw-container/instances/bot-mybot/openclaw/openclaw.json) with the bot's real channel and provider settings.

If the file contains `${VAR}` placeholders, the matching variables in `.env` must be set.

## 4. Validate and Start

```bash
docker compose --env-file ./instances/bot-mybot/.env -p bot-mybot config
docker compose --env-file ./instances/bot-mybot/.env -p bot-mybot up -d
docker compose --env-file ./instances/bot-mybot/.env -p bot-mybot logs -f
```

Only run `docker compose --env-file ./instances/bot-mybot/.env -p bot-mybot build`
if that bot intentionally overrides shared build variables or you changed files
that are baked into the image, such as `Dockerfile` or scripts under `docker/`.
For normal bot creation, one shared build is enough and `up -d` can reuse it.

Open a shell in the container if needed:

```bash
docker compose --env-file ./instances/bot-mybot/.env -p bot-mybot exec openclaw bash
```

## 5. Common Mistakes

- Reusing another bot's ports or mounted directories.
- Copying build-only settings such as `INSTALL_VNC` into every bot `.env`, which
  makes routine instance creation look like it needs per-bot rebuilds.
- Running a per-bot `docker compose build` even though the shared image already
  has the required capabilities.
- Leaving `INSTANCE_ENV_FILE` pointed at the wrong `.env`.
- Forgetting to copy `openclaw.json.example` to `openclaw.json`.
- Starting with both `TELEGRAM_BOT_TOKEN` and `DISCORD_BOT_TOKEN` empty.
- Setting proxy URLs but forgetting `NODE_USE_ENV_PROXY=1`, so some Node.js
  requests bypass the proxy.
- Using `docker compose up --scale`; this repo needs parameterized instances, not identical replicas.
