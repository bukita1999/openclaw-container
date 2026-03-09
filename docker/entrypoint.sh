#!/usr/bin/env bash
set -euo pipefail

sync_proxy_env() {
  export HTTP_PROXY="${HTTP_PROXY:-${http_proxy:-}}"
  export HTTPS_PROXY="${HTTPS_PROXY:-${https_proxy:-}}"
  export ALL_PROXY="${ALL_PROXY:-${all_proxy:-}}"
  export NO_PROXY="${NO_PROXY:-${no_proxy:-}}"
  export http_proxy="${HTTP_PROXY:-}"
  export https_proxy="${HTTPS_PROXY:-}"
  export all_proxy="${ALL_PROXY:-}"
  export no_proxy="${NO_PROXY:-}"
}

configure_user_tools() {
  if [[ -n "${HTTP_PROXY:-}" ]]; then
    git config --global http.proxy "${HTTP_PROXY}" || true
    npm config set proxy "${HTTP_PROXY}" --location=user >/dev/null 2>&1 || true
  else
    git config --global --unset-all http.proxy >/dev/null 2>&1 || true
    npm config delete proxy --location=user >/dev/null 2>&1 || true
  fi

  if [[ -n "${HTTPS_PROXY:-}" ]]; then
    git config --global https.proxy "${HTTPS_PROXY}" || true
    npm config set https-proxy "${HTTPS_PROXY}" --location=user >/dev/null 2>&1 || true
  else
    git config --global --unset-all https.proxy >/dev/null 2>&1 || true
    npm config delete https-proxy --location=user >/dev/null 2>&1 || true
  fi
}

has_nonempty_value() {
  local value="${1:-}"
  value="${value#"${value%%[![:space:]]*}"}"
  value="${value%"${value##*[![:space:]]}"}"
  [[ -n "${value}" ]]
}

configure_channel_tokens() {
  local config_path="${HOME}/.openclaw/openclaw.json"
  local telegram_enabled=false
  local discord_enabled=false
  local tmp_file

  if has_nonempty_value "${TELEGRAM_BOT_TOKEN:-}"; then
    telegram_enabled=true
  fi

  if has_nonempty_value "${DISCORD_BOT_TOKEN:-}"; then
    discord_enabled=true
  fi

  if [[ "${telegram_enabled}" != "true" && "${discord_enabled}" != "true" ]]; then
    echo "Both TELEGRAM_BOT_TOKEN and DISCORD_BOT_TOKEN are empty; at least one channel must be configured." >&2
    exit 1
  fi

  [[ -f "${config_path}" ]] || return 0

  if [[ "${telegram_enabled}" != "true" ]]; then
    echo "TELEGRAM_BOT_TOKEN is empty; disabling Telegram channel." >&2
  fi

  if [[ "${discord_enabled}" != "true" ]]; then
    echo "DISCORD_BOT_TOKEN is empty; disabling Discord channel." >&2
  fi

  tmp_file="$(mktemp)"
  jq \
    --argjson telegram_enabled "${telegram_enabled}" \
    --argjson discord_enabled "${discord_enabled}" \
    '
    if .channels.telegram? then
      .channels.telegram.enabled = $telegram_enabled
      | .channels.telegram.botToken = (if $telegram_enabled then .channels.telegram.botToken else "" end)
    else
      .
    end
    | if .channels.discord? then
        .channels.discord.enabled = $discord_enabled
        | .channels.discord.token = (if $discord_enabled then .channels.discord.token else "" end)
      else
        .
      end
    ' "${config_path}" > "${tmp_file}"
  mv "${tmp_file}" "${config_path}"
}

start_optional_browser_stack() {
  if [[ "${ENABLE_VNC:-0}" == "1" || "${START_CHROMIUM:-0}" == "1" ]]; then
    /usr/local/bin/start-browser-stack.sh &
  fi
}

default_cmd() {
  exec openclaw gateway \
    --bind "${OPENCLAW_GATEWAY_BIND:-loopback}" \
    --port "${OPENCLAW_GATEWAY_PORT:-18789}" \
    --allow-unconfigured
}

sync_proxy_env
configure_user_tools
mkdir -p \
  "${HOME}/.openclaw/workspace" \
  "${HOME}/.cache/uv" \
  "${HOME}/go" \
  "${CHROMIUM_PROFILE_DIR:-${HOME}/.config/chromium-profile}" \
  "${UV_PYTHON_INSTALL_DIR:-/opt/uv/python}"
configure_channel_tokens
start_optional_browser_stack

if [[ $# -eq 0 ]]; then
  default_cmd
fi

case "${1:-}" in
  gateway|onboard|dashboard|doctor|agent|message|devices|config|channels)
    set -- openclaw "$@"
    ;;
esac

exec "$@"
