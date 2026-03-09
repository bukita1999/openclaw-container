#!/usr/bin/env bash
set -euo pipefail

export DISPLAY="${DISPLAY:-:99}"
export XDG_RUNTIME_DIR="${XDG_RUNTIME_DIR:-${HOME}/.xdg-runtime}"
chromium_profile_dir="${CHROMIUM_PROFILE_DIR:-${HOME}/.config/chromium-profile}"

mkdir -p "${XDG_RUNTIME_DIR}" "${HOME}/.vnc" "${chromium_profile_dir}"
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
  chromium_path="${CHROMIUM_BIN:-}"
  if [[ -z "${chromium_path}" ]]; then
    chromium_path="$(command -v chromium || command -v google-chrome-stable || command -v google-chrome || command -v chromium-browser || true)"
  fi
  if [[ -x "${chromium_path}" ]]; then
    chromium_args=(
      --no-sandbox
      --disable-dev-shm-usage
      --disable-background-networking
      --disable-sync
      --password-store=basic
      --no-first-run
      --no-default-browser-check
      --enable-automation
      --remote-debugging-address=0.0.0.0
      --remote-debugging-port="${CHROMIUM_REMOTE_DEBUGGING_PORT:-9222}"
      --user-data-dir="${chromium_profile_dir}"
    )
    if [[ "${CHROMIUM_HEADLESS:-0}" == "1" ]]; then
      chromium_args+=(--headless=new)
    fi
    if [[ -n "${CHROMIUM_EXTRA_ARGS:-}" ]]; then
      read -r -a chromium_extra_args <<< "${CHROMIUM_EXTRA_ARGS}"
      chromium_args+=("${chromium_extra_args[@]}")
    fi
    "${chromium_path}" \
      "${chromium_args[@]}" \
      "${CHROMIUM_URL:-about:blank}" >/tmp/chromium.log 2>&1 &
  else
    echo "Browser executable not found. Rebuild with INSTALL_CHROMIUM=1." >&2
  fi
fi

wait -n || true
