# Create a New Bot

This repository is designed for multi-instance usage. To add a new bot, create a new directory under `instances/` instead of copying the whole repository.

## 1. Copy the Template

Create a new instance named `bot-mybot`:

```bash
cp -a instances/_template instances/bot-mybot
mv instances/bot-mybot/.env.example instances/bot-mybot/.env
cp instances/bot-mybot/openclaw/openclaw.json.example instances/bot-mybot/openclaw/openclaw.json
```

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

Also set unique host ports:

- `OPENCLAW_GATEWAY_PORT`
- `OPENCLAW_BRIDGE_PORT`
- `VNC_PORT`
- `NOVNC_PORT`
- `CHROMIUM_REMOTE_DEBUGGING_PORT`

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
docker compose build
docker compose --env-file ./instances/bot-mybot/.env -p bot-mybot up -d
docker compose --env-file ./instances/bot-mybot/.env -p bot-mybot logs -f
```

Open a shell in the container if needed:

```bash
docker compose --env-file ./instances/bot-mybot/.env -p bot-mybot exec openclaw bash
```

## 5. Common Mistakes

- Reusing another bot's ports or mounted directories.
- Leaving `INSTANCE_ENV_FILE` pointed at the wrong `.env`.
- Forgetting to copy `openclaw.json.example` to `openclaw.json`.
- Starting with both `TELEGRAM_BOT_TOKEN` and `DISCORD_BOT_TOKEN` empty.
- Using `docker compose up --scale`; this repo needs parameterized instances, not identical replicas.
