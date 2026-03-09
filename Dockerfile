# syntax=docker/dockerfile:1.7-labs
FROM debian:12-slim

SHELL ["/bin/bash", "-o", "pipefail", "-c"]

ARG DEBIAN_FRONTEND=noninteractive
ARG USE_SJTUG_MIRROR=0
ARG HTTP_PROXY
ARG HTTPS_PROXY
ARG ALL_PROXY
ARG NO_PROXY

ENV TZ=Etc/UTC \
    LANG=en_US.UTF-8 \
    LC_ALL=en_US.UTF-8 \
    HOME=/home/openclaw \
    UV_PYTHON_INSTALL_DIR=/opt/uv/python \
    UV_CACHE_DIR=/home/openclaw/.cache/uv \
    CHROMIUM_PROFILE_DIR=/home/openclaw/.config/chromium-profile \
    CHROMIUM_BIN=/usr/bin/chromium \
    GOPATH=/home/openclaw/go \
    PATH=/usr/local/go/bin:/home/openclaw/go/bin:/home/openclaw/.local/bin:/usr/local/bin:/usr/local/sbin:/usr/sbin:/usr/bin:/sbin:/bin

RUN --mount=type=cache,target=/var/cache/apt,sharing=locked \
    --mount=type=cache,target=/var/lib/apt/lists,sharing=locked \
    set -eux; \
    mkdir -p /etc/apt/apt.conf.d; \
    rm -f /etc/apt/apt.conf.d/docker-clean; \
    printf '%s\n' \
      'Acquire::Retries "5";' \
      'Acquire::Languages "none";' \
      'APT::Install-Recommends "0";' \
      'APT::Install-Suggests "0";' \
      'Binary::apt::APT::Keep-Downloaded-Packages "true";' \
      > /etc/apt/apt.conf.d/80buildkit-cache; \
    : > /etc/apt/apt.conf.d/99proxy; \
    if [[ -n "${HTTP_PROXY:-}" ]]; then \
      echo "Acquire::http::Proxy \"${HTTP_PROXY}\";" >> /etc/apt/apt.conf.d/99proxy; \
    fi; \
    if [[ -n "${HTTPS_PROXY:-}" ]]; then \
      echo "Acquire::https::Proxy \"${HTTPS_PROXY}\";" >> /etc/apt/apt.conf.d/99proxy; \
    fi; \
    export HTTP_PROXY="${HTTP_PROXY:-}" HTTPS_PROXY="${HTTPS_PROXY:-}" ALL_PROXY="${ALL_PROXY:-}" NO_PROXY="${NO_PROXY:-}"; \
    export http_proxy="${HTTP_PROXY:-}" https_proxy="${HTTPS_PROXY:-}" all_proxy="${ALL_PROXY:-}" no_proxy="${NO_PROXY:-}"; \
    apt-get update; \
    apt-get install -y --no-install-recommends \
      aria2 \
      ca-certificates \
      curl \
      gnupg; \
    if [[ "${USE_SJTUG_MIRROR}" == "1" ]]; then \
      for sources_file in /etc/apt/sources.list.d/debian.sources /etc/apt/sources.list; do \
        if [[ -f "${sources_file}" ]]; then \
          sed -i \
            -e 's|http://deb.debian.org/debian|https://mirror.sjtu.edu.cn/debian|g' \
            -e 's|https://deb.debian.org/debian|https://mirror.sjtu.edu.cn/debian|g' \
            -e 's|http://security.debian.org/debian-security|https://mirror.sjtu.edu.cn/debian-security|g' \
            -e 's|https://security.debian.org/debian-security|https://mirror.sjtu.edu.cn/debian-security|g' \
            -e 's|http://deb.debian.org/debian-security|https://mirror.sjtu.edu.cn/debian-security|g' \
            -e 's|https://deb.debian.org/debian-security|https://mirror.sjtu.edu.cn/debian-security|g' \
            "${sources_file}"; \
        fi; \
      done; \
      apt-get update; \
    fi; \
    curl -fsSL https://raw.githubusercontent.com/ilikenwf/apt-fast/master/apt-fast -o /usr/local/sbin/apt-fast; \
    chmod 0755 /usr/local/sbin/apt-fast; \
    curl -fsSL https://raw.githubusercontent.com/ilikenwf/apt-fast/master/apt-fast.conf -o /etc/apt-fast.conf; \
    if [[ "${USE_SJTUG_MIRROR}" == "1" ]]; then \
      apt_fast_mirrors=( \
        "https://mirror.sjtu.edu.cn/debian" \
        "https://mirror.sjtu.edu.cn/debian-security" \
      ); \
    else \
      apt_fast_mirrors=( \
        "http://deb.debian.org/debian" \
        "http://deb.debian.org/debian-security" \
      ); \
    fi; \
    { \
      echo; \
      echo "_APTMGR=apt-get"; \
      echo "DOWNLOADBEFORE=true"; \
      echo "_MAXNUM=8"; \
      echo "_MAXCONPERSRV=8"; \
      echo "_SPLITCON=8"; \
      echo "_MINSPLITSZ=1M"; \
      echo "DLDIR='/var/cache/apt/apt-fast'"; \
      printf "MIRRORS=("; \
      for mirror in "${apt_fast_mirrors[@]}"; do \
        printf " '%s'" "${mirror}"; \
      done; \
      printf " )\n"; \
    } >> /etc/apt-fast.conf; \
    apt-fast update; \
    apt-fast install -y --no-install-recommends \
      bash-completion \
      git \
      jq \
      locales \
      procps \
      python3 \
      tzdata \
      unzip \
      xz-utils; \
    locale-gen en_US.UTF-8

ARG NODE_MAJOR=22

RUN --mount=type=cache,target=/var/cache/apt,sharing=locked \
    --mount=type=cache,target=/var/lib/apt/lists,sharing=locked \
    set -eux; \
    export HTTP_PROXY="${HTTP_PROXY:-}" HTTPS_PROXY="${HTTPS_PROXY:-}" ALL_PROXY="${ALL_PROXY:-}" NO_PROXY="${NO_PROXY:-}"; \
    export http_proxy="${HTTP_PROXY:-}" https_proxy="${HTTPS_PROXY:-}" all_proxy="${ALL_PROXY:-}" no_proxy="${NO_PROXY:-}"; \
    install -m 0755 -d /etc/apt/keyrings; \
    curl -fsSL https://deb.nodesource.com/gpgkey/nodesource-repo.gpg.key | gpg --dearmor -o /etc/apt/keyrings/nodesource.gpg; \
    echo "deb [signed-by=/etc/apt/keyrings/nodesource.gpg] https://deb.nodesource.com/node_${NODE_MAJOR}.x nodistro main" > /etc/apt/sources.list.d/nodesource.list; \
    apt-fast update; \
    apt-fast install -y --no-install-recommends nodejs tini; \
    corepack enable

ARG OPENCLAW_VERSION=latest

RUN --mount=type=cache,target=/root/.npm,sharing=locked \
    --mount=type=cache,target=/var/cache/apt,sharing=locked \
    --mount=type=cache,target=/var/lib/apt/lists,sharing=locked \
    set -eux; \
    export HTTP_PROXY="${HTTP_PROXY:-}" HTTPS_PROXY="${HTTPS_PROXY:-}" ALL_PROXY="${ALL_PROXY:-}" NO_PROXY="${NO_PROXY:-}"; \
    export http_proxy="${HTTP_PROXY:-}" https_proxy="${HTTPS_PROXY:-}" all_proxy="${ALL_PROXY:-}" no_proxy="${NO_PROXY:-}"; \
    npm_install_args=( --prefer-offline --no-audit --no-fund ); \
    if [[ "${USE_SJTUG_MIRROR}" == "1" ]]; then \
      npm_install_args+=( --registry=https://mirrors.sjtug.sjtu.edu.cn/npm-registry ); \
    fi; \
    if ! npm install -g "${npm_install_args[@]}" "openclaw@${OPENCLAW_VERSION}"; then \
      apt-fast update; \
      apt-fast install -y --no-install-recommends build-essential cmake; \
      npm install -g "${npm_install_args[@]}" "openclaw@${OPENCLAW_VERSION}"; \
    fi

RUN set -eux; \
    export HTTP_PROXY="${HTTP_PROXY:-}" HTTPS_PROXY="${HTTPS_PROXY:-}" ALL_PROXY="${ALL_PROXY:-}" NO_PROXY="${NO_PROXY:-}"; \
    export http_proxy="${HTTP_PROXY:-}" https_proxy="${HTTPS_PROXY:-}" all_proxy="${ALL_PROXY:-}" no_proxy="${NO_PROXY:-}"; \
    curl -LsSf https://astral.sh/uv/install.sh | env UV_UNMANAGED_INSTALL=/usr/local/bin sh

ARG PYTHON_VERSION=3.12

RUN --mount=type=cache,target=/root/.cache/uv,sharing=locked \
    set -eux; \
    export HTTP_PROXY="${HTTP_PROXY:-}" HTTPS_PROXY="${HTTPS_PROXY:-}" ALL_PROXY="${ALL_PROXY:-}" NO_PROXY="${NO_PROXY:-}"; \
    export http_proxy="${HTTP_PROXY:-}" https_proxy="${HTTPS_PROXY:-}" all_proxy="${ALL_PROXY:-}" no_proxy="${NO_PROXY:-}"; \
    mkdir -p "${UV_PYTHON_INSTALL_DIR}" /opt/uv; \
    UV_CACHE_DIR=/root/.cache/uv UV_PYTHON_INSTALL_DIR="${UV_PYTHON_INSTALL_DIR}" uv python install "${PYTHON_VERSION}"; \
    python_path="$(UV_PYTHON_INSTALL_DIR="${UV_PYTHON_INSTALL_DIR}" uv python find "${PYTHON_VERSION}")"; \
    python_bin_dir="$(dirname "${python_path}")"; \
    ln -sf "${python_path}" /usr/local/bin/python; \
    ln -sf "${python_path}" /usr/local/bin/python3; \
    if [[ -x "${python_bin_dir}/pip" ]]; then ln -sf "${python_bin_dir}/pip" /usr/local/bin/pip; fi; \
    if [[ -x "${python_bin_dir}/pip3" ]]; then ln -sf "${python_bin_dir}/pip3" /usr/local/bin/pip3; fi

ARG INSTALL_GO=0
ARG GO_VERSION=1.26.1

RUN --mount=type=cache,target=/tmp/downloads,sharing=locked \
    set -eux; \
    if [[ "${INSTALL_GO}" == "1" ]]; then \
      export HTTP_PROXY="${HTTP_PROXY:-}" HTTPS_PROXY="${HTTPS_PROXY:-}" ALL_PROXY="${ALL_PROXY:-}" NO_PROXY="${NO_PROXY:-}"; \
      export http_proxy="${HTTP_PROXY:-}" https_proxy="${HTTPS_PROXY:-}" all_proxy="${ALL_PROXY:-}" no_proxy="${NO_PROXY:-}"; \
      case "$(dpkg --print-architecture)" in \
        amd64) go_arch="amd64" ;; \
        arm64) go_arch="arm64" ;; \
        *) echo "Unsupported architecture for Go" >&2; exit 1 ;; \
      esac; \
      go_tarball="/tmp/downloads/go${GO_VERSION}.linux-${go_arch}.tar.gz"; \
      if [[ ! -f "${go_tarball}" ]]; then \
        curl -fsSL "https://go.dev/dl/go${GO_VERSION}.linux-${go_arch}.tar.gz" -o "${go_tarball}"; \
      fi; \
      rm -rf /usr/local/go; \
      tar -C /usr/local -xzf "${go_tarball}"; \
    fi

ARG INSTALL_CHROMIUM=1
ARG INSTALL_VNC=1

RUN --mount=type=cache,target=/var/cache/apt,sharing=locked \
    --mount=type=cache,target=/var/lib/apt/lists,sharing=locked \
    set -eux; \
    if [[ "${INSTALL_CHROMIUM}" == "1" || "${INSTALL_VNC}" == "1" ]]; then \
      export HTTP_PROXY="${HTTP_PROXY:-}" HTTPS_PROXY="${HTTPS_PROXY:-}" ALL_PROXY="${ALL_PROXY:-}" NO_PROXY="${NO_PROXY:-}"; \
      export http_proxy="${HTTP_PROXY:-}" https_proxy="${HTTPS_PROXY:-}" all_proxy="${ALL_PROXY:-}" no_proxy="${NO_PROXY:-}"; \
      apt-fast update; \
      apt-fast install -y --no-install-recommends openbox xvfb; \
    fi

RUN --mount=type=cache,target=/var/cache/apt,sharing=locked \
    --mount=type=cache,target=/var/lib/apt/lists,sharing=locked \
    set -eux; \
    if [[ "${INSTALL_CHROMIUM}" == "1" ]]; then \
      export HTTP_PROXY="${HTTP_PROXY:-}" HTTPS_PROXY="${HTTPS_PROXY:-}" ALL_PROXY="${ALL_PROXY:-}" NO_PROXY="${NO_PROXY:-}"; \
      export http_proxy="${HTTP_PROXY:-}" https_proxy="${HTTPS_PROXY:-}" all_proxy="${ALL_PROXY:-}" no_proxy="${NO_PROXY:-}"; \
      apt-fast update; \
      apt-fast install -y --no-install-recommends chromium fonts-liberation fonts-noto-color-emoji; \
      ln -sf /usr/bin/chromium /usr/local/bin/google-chrome-stable; \
      ln -sf /usr/bin/chromium /usr/local/bin/google-chrome; \
    fi

RUN --mount=type=cache,target=/var/cache/apt,sharing=locked \
    --mount=type=cache,target=/var/lib/apt/lists,sharing=locked \
    set -eux; \
    if [[ "${INSTALL_VNC}" == "1" ]]; then \
      export HTTP_PROXY="${HTTP_PROXY:-}" HTTPS_PROXY="${HTTPS_PROXY:-}" ALL_PROXY="${ALL_PROXY:-}" NO_PROXY="${NO_PROXY:-}"; \
      export http_proxy="${HTTP_PROXY:-}" https_proxy="${HTTPS_PROXY:-}" all_proxy="${ALL_PROXY:-}" no_proxy="${NO_PROXY:-}"; \
      apt-fast update; \
      apt-fast install -y --no-install-recommends novnc websockify x11vnc; \
    fi

ARG USER_UID=1000
ARG USER_GID=1000

RUN set -eux; \
    if getent group "${USER_GID}" >/dev/null; then \
      group_name="$(getent group "${USER_GID}" | cut -d: -f1)"; \
    elif getent group openclaw >/dev/null; then \
      groupmod --gid "${USER_GID}" openclaw; \
      group_name="openclaw"; \
    else \
      groupadd --gid "${USER_GID}" openclaw; \
      group_name="openclaw"; \
    fi; \
    if id -u openclaw >/dev/null 2>&1; then \
      usermod --uid "${USER_UID}" --gid "${USER_GID}" --home /home/openclaw --shell /bin/bash openclaw; \
    elif getent passwd "${USER_UID}" >/dev/null; then \
      existing_user="$(getent passwd "${USER_UID}" | cut -d: -f1)"; \
      usermod --login openclaw --home /home/openclaw --shell /bin/bash --gid "${USER_GID}" "${existing_user}"; \
    else \
      useradd --uid "${USER_UID}" --gid "${USER_GID}" --create-home --shell /bin/bash openclaw; \
    fi; \
    mkdir -p \
      /workspace \
      /home/openclaw/.openclaw/workspace \
      /home/openclaw/.cache/uv \
      /home/openclaw/.config \
      /home/openclaw/.config/chromium-profile \
      /home/openclaw/go \
      /opt/uv/python; \
    chown -R openclaw:"${group_name}" \
      /workspace \
      /home/openclaw \
      /opt/uv

COPY --link --chmod=0755 docker/entrypoint.sh /usr/local/bin/container-entrypoint.sh
COPY --link --chmod=0755 docker/start-browser-stack.sh /usr/local/bin/start-browser-stack.sh
COPY --link --chmod=0755 docker/profile.sh /etc/profile.d/openclaw-profile.sh

USER openclaw
WORKDIR /home/openclaw

EXPOSE 18789 18790 5900 6080 9222

ENTRYPOINT ["/usr/bin/tini", "--", "/usr/local/bin/container-entrypoint.sh"]
