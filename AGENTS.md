# Repository Guidelines

## Project Structure & Module Organization

This repository packages an OpenClaw runtime image and instance templates rather than application source code. Keep changes scoped to the layer they affect:

- `Dockerfile`: multi-stage image definition (`openclaw-base`, `openclaw-core`, `openclaw-runtime`), package installation, and optional components such as Chromium, VNC, and Go.
- `docker-compose.yml`: the single service definition, mounts, ports, build args, and `build.target` controlled by `BUILD_TARGET`.
- `docker/`: Bash entrypoints and startup helpers used inside the container.
- `data/`: default single-instance runtime directories; commit only tracked examples such as `data/openclaw/openclaw.json.example`.
- `instances/_template/`: starter files for multi-instance setups. Copy this directory when adding a new bot instance.

## Build, Test, and Development Commands

Use Docker Compose as the main workflow:

- `cp .env.example .env`: create the default local config.
- `docker compose config`: validate Compose interpolation before starting anything.
- `docker compose build`: rebuild the image after changing `Dockerfile`, build args, or startup scripts (defaults to `BUILD_TARGET=openclaw-runtime`).
- `BUILD_TARGET=openclaw-base docker compose build`: quickly validate Debian base setup, apt sources, apt-fast, and Node.js install.
- `BUILD_TARGET=openclaw-core docker compose build`: validate OpenClaw, uv, and Python install on top of `openclaw-base`.
- `BUILD_TARGET=openclaw-runtime docker compose build`: run the full runtime build including optional Go/Chromium/VNC layers.
- `docker compose up -d`: start the default single-instance container.
- `docker compose logs -f`: follow startup logs.
- `docker compose exec openclaw bash`: open a shell in the running container.
- `docker compose --env-file ./instances/<name>/.env -p <name> up -d`: start a named multi-instance bot.

## Coding Style & Naming Conventions

Shell scripts use `bash`, `set -euo pipefail`, 2-space-to-4-space aligned indentation, and lowercase snake_case function names such as `configure_channel_tokens`. Prefer explicit environment variable names in uppercase. Keep Compose and `.env.example` keys aligned; when adding an instance path, mirror the existing `instances/<name>/...` naming pattern.

## Testing Guidelines

There is no dedicated automated test suite in this repository today. For every change, run `docker compose config`; for image or entrypoint changes, run at least one staged build and then a full build:

- `BUILD_TARGET=openclaw-base docker compose build` for fast early validation.
- `BUILD_TARGET=openclaw-core docker compose build` when debugging OpenClaw/uv/Python installation issues.
- `BUILD_TARGET=openclaw-runtime docker compose build` before release or shared usage.

After full build, confirm the container starts cleanly with `docker compose up -d` and `docker compose logs -f`. If you modify multi-instance behavior, validate with `--env-file ./instances/<name>/.env -p <name>`.

## Commit & Pull Request Guidelines

Recent history favors short, imperative commit subjects, sometimes in Chinese, for example `Optimize Docker build and refresh example config`. Keep subjects concise and action-first. Pull requests should describe the operational impact, list changed env vars or mounted paths, link any related issue, and include relevant log snippets or screenshots when browser/VNC behavior changes.

## Security & Configuration Tips

Do not commit real `.env` files, runtime `openclaw.json`, tokens, or populated `data/` and `instances/*/` directories. Keep `OPENCLAW_GATEWAY_BIND=loopback` unless external exposure is intentional, and document any new port or proxy requirement in both `README.md` and the corresponding example config.
