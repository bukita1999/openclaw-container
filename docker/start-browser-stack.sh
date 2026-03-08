#!/usr/bin/env bash
set -euo pipefail

export DISPLAY="${DISPLAY:-:99}"
export XDG_RUNTIME_DIR="${XDG_RUNTIME_DIR:-${HOME}/.xdg-runtime}"
export PLAYWRIGHT_BROWSERS_PATH="${PLAYWRIGHT_BROWSERS_PATH:-/opt/ms-playwright}"

mkdir -p "${XDG_RUNTIME_DIR}" "${HOME}/.vnc" "${HOME}/.config/chromium-profile"
chmod 700 "${XDG_RUNTIME_DIR}"

if ! pgrep -f "Xvfb ${DISPLAY}" >/dev/null 2>&1; then
  Xvfb "${DISPLAY}" -screen 0 "${VNC_RESOLUTION:-1440x900x24}" -ac +extension RANDR >/tmp/xvfb.log 2>&1 &
  sleep 1
fi

if command -v openbox >/dev/null 2>&1 && ! pgrep -x openbox >/dev/null 2>&1; then
  openbox >/tmp/openbox.log 2>&1 &
fi

if [[ "${ENABLE_VNC:-0}" == "1" ]]; then
  x11vnc -storepasswd "${VNC_PASSWORD:-openclaw}" "${HOME}/.vnc/passwd" >/dev/null 2>&1
  x11vnc \
    -display "${DISPLAY}" \
    -rfbport "${VNC_PORT:-5900}" \
    -rfbauth "${HOME}/.vnc/passwd" \
    -forever \
    -shared \
    -bg \
    -o /tmp/x11vnc.log
  websockify --web=/usr/share/novnc/ "${NOVNC_PORT:-6080}" "127.0.0.1:${VNC_PORT:-5900}" >/tmp/novnc.log 2>&1 &
fi

if [[ "${START_CHROMIUM:-0}" == "1" ]]; then
  chromium_path="$(
    node -e "const root=require('child_process').execSync('npm root -g',{encoding:'utf8'}).trim(); const { chromium } = require(root + '/openclaw/node_modules/playwright-core'); console.log(chromium.executablePath());"
  )"
  if [[ -x "${chromium_path}" ]]; then
    "${chromium_path}" \
      --no-sandbox \
      --disable-dev-shm-usage \
      --remote-debugging-address=0.0.0.0 \
      --remote-debugging-port="${CHROMIUM_REMOTE_DEBUGGING_PORT:-9222}" \
      --user-data-dir="${HOME}/.config/chromium-profile" \
      "${CHROMIUM_URL:-https://openclaw.ai/}" >/tmp/chromium.log 2>&1 &
  else
    echo "Chromium executable not found. Rebuild with INSTALL_CHROMIUM=1." >&2
  fi
fi

wait -n || true
