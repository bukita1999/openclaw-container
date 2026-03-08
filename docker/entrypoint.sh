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

start_optional_browser_stack() {
  if [[ "${ENABLE_VNC:-0}" == "1" || "${START_CHROMIUM:-0}" == "1" ]]; then
    /usr/local/bin/start-browser-stack.sh &
  fi
}

default_cmd() {
  exec openclaw gateway \
    --bind "${OPENCLAW_GATEWAY_BIND:-lan}" \
    --port "${OPENCLAW_GATEWAY_PORT:-18789}" \
    --allow-unconfigured
}

sync_proxy_env
configure_user_tools
mkdir -p \
  "${HOME}/.openclaw/workspace" \
  "${HOME}/.cache/uv" \
  "${HOME}/go" \
  "${PLAYWRIGHT_BROWSERS_PATH:-/opt/ms-playwright}" \
  "${UV_PYTHON_INSTALL_DIR:-/opt/uv/python}"
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
