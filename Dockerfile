FROM ubuntu:24.04

SHELL ["/bin/bash", "-o", "pipefail", "-c"]

ARG DEBIAN_FRONTEND=noninteractive
ARG NODE_MAJOR=22
ARG OPENCLAW_VERSION=latest
ARG PYTHON_VERSION=3.12
ARG INSTALL_CHROMIUM=0
ARG INSTALL_VNC=0
ARG INSTALL_GO=0
ARG GO_VERSION=1.26.1
ARG USER_UID=1000
ARG USER_GID=1000
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
    PLAYWRIGHT_BROWSERS_PATH=/opt/ms-playwright \
    GOPATH=/home/openclaw/go \
    PATH=/usr/local/go/bin:/home/openclaw/go/bin:/home/openclaw/.local/bin:/usr/local/bin:/usr/local/sbin:/usr/sbin:/usr/bin:/sbin:/bin

RUN set -eux; \
    mkdir -p /etc/apt/apt.conf.d; \
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
      ca-certificates \
      curl \
      gnupg; \
    if [[ "${USE_SJTUG_MIRROR}" == "1" ]]; then \
      if [[ -f /etc/apt/sources.list.d/ubuntu.sources ]]; then \
        sed -i \
          -e 's|http://archive.ubuntu.com/ubuntu/|https://mirror.sjtu.edu.cn/ubuntu/|g' \
          -e 's|http://cn.archive.ubuntu.com/ubuntu/|https://mirror.sjtu.edu.cn/ubuntu/|g' \
          -e 's|http://ports.ubuntu.com/ubuntu-ports|https://mirror.sjtu.edu.cn/ubuntu-ports|g' \
          /etc/apt/sources.list.d/ubuntu.sources; \
      elif [[ -f /etc/apt/sources.list ]]; then \
        sed -i \
          -e 's|http://archive.ubuntu.com/ubuntu/|https://mirror.sjtu.edu.cn/ubuntu/|g' \
          -e 's|http://cn.archive.ubuntu.com/ubuntu/|https://mirror.sjtu.edu.cn/ubuntu/|g' \
          -e 's|http://ports.ubuntu.com/ubuntu-ports|https://mirror.sjtu.edu.cn/ubuntu-ports|g' \
          /etc/apt/sources.list; \
      fi; \
      apt-get update; \
    fi; \
    apt-get install -y --no-install-recommends \
      bash-completion \
      git \
      jq \
      locales \
      procps \
      python3 \
      tzdata \
      unzip \
      xz-utils; \
    locale-gen en_US.UTF-8; \
    rm -rf /var/lib/apt/lists/*

RUN set -eux; \
    export HTTP_PROXY="${HTTP_PROXY:-}" HTTPS_PROXY="${HTTPS_PROXY:-}" ALL_PROXY="${ALL_PROXY:-}" NO_PROXY="${NO_PROXY:-}"; \
    export http_proxy="${HTTP_PROXY:-}" https_proxy="${HTTPS_PROXY:-}" all_proxy="${ALL_PROXY:-}" no_proxy="${NO_PROXY:-}"; \
    npm_registry_args=(); \
    if [[ "${USE_SJTUG_MIRROR}" == "1" ]]; then \
      npm_registry_args+=(--registry=https://mirrors.sjtug.sjtu.edu.cn/npm-registry); \
    fi; \
    install -m 0755 -d /etc/apt/keyrings; \
    curl -fsSL https://deb.nodesource.com/gpgkey/nodesource-repo.gpg.key | gpg --dearmor -o /etc/apt/keyrings/nodesource.gpg; \
    echo "deb [signed-by=/etc/apt/keyrings/nodesource.gpg] https://deb.nodesource.com/node_${NODE_MAJOR}.x nodistro main" > /etc/apt/sources.list.d/nodesource.list; \
    apt-get update; \
    apt-get install -y --no-install-recommends nodejs tini; \
    corepack enable; \
    if ! npm install -g "${npm_registry_args[@]}" "openclaw@${OPENCLAW_VERSION}"; then \
      apt-get update; \
      apt-get install -y --no-install-recommends build-essential cmake; \
      npm install -g "${npm_registry_args[@]}" "openclaw@${OPENCLAW_VERSION}"; \
    fi; \
    npm cache clean --force; \
    rm -rf /var/lib/apt/lists/*

RUN set -eux; \
    export HTTP_PROXY="${HTTP_PROXY:-}" HTTPS_PROXY="${HTTPS_PROXY:-}" ALL_PROXY="${ALL_PROXY:-}" NO_PROXY="${NO_PROXY:-}"; \
    export http_proxy="${HTTP_PROXY:-}" https_proxy="${HTTPS_PROXY:-}" all_proxy="${ALL_PROXY:-}" no_proxy="${NO_PROXY:-}"; \
    curl -LsSf https://astral.sh/uv/install.sh | env UV_UNMANAGED_INSTALL=/usr/local/bin sh; \
    mkdir -p "${UV_PYTHON_INSTALL_DIR}" "${PLAYWRIGHT_BROWSERS_PATH}" /opt/uv; \
    UV_CACHE_DIR=/tmp/uv-cache UV_PYTHON_INSTALL_DIR="${UV_PYTHON_INSTALL_DIR}" uv python install "${PYTHON_VERSION}"; \
    python_path="$(UV_PYTHON_INSTALL_DIR="${UV_PYTHON_INSTALL_DIR}" uv python find "${PYTHON_VERSION}")"; \
    python_bin_dir="$(dirname "${python_path}")"; \
    ln -sf "${python_path}" /usr/local/bin/python; \
    ln -sf "${python_path}" /usr/local/bin/python3; \
    if [[ -x "${python_bin_dir}/pip" ]]; then ln -sf "${python_bin_dir}/pip" /usr/local/bin/pip; fi; \
    if [[ -x "${python_bin_dir}/pip3" ]]; then ln -sf "${python_bin_dir}/pip3" /usr/local/bin/pip3; fi; \
    rm -rf /tmp/uv-cache

RUN set -eux; \
    if [[ "${INSTALL_GO}" == "1" ]]; then \
      export HTTP_PROXY="${HTTP_PROXY:-}" HTTPS_PROXY="${HTTPS_PROXY:-}" ALL_PROXY="${ALL_PROXY:-}" NO_PROXY="${NO_PROXY:-}"; \
      export http_proxy="${HTTP_PROXY:-}" https_proxy="${HTTPS_PROXY:-}" all_proxy="${ALL_PROXY:-}" no_proxy="${NO_PROXY:-}"; \
      case "$(dpkg --print-architecture)" in \
        amd64) go_arch="amd64" ;; \
        arm64) go_arch="arm64" ;; \
        *) echo "Unsupported architecture for Go" >&2; exit 1 ;; \
      esac; \
      curl -fsSL "https://go.dev/dl/go${GO_VERSION}.linux-${go_arch}.tar.gz" -o /tmp/go.tar.gz; \
      rm -rf /usr/local/go; \
      tar -C /usr/local -xzf /tmp/go.tar.gz; \
      rm -f /tmp/go.tar.gz; \
    fi

RUN set -eux; \
    if [[ "${INSTALL_CHROMIUM}" == "1" || "${INSTALL_VNC}" == "1" ]]; then \
      export HTTP_PROXY="${HTTP_PROXY:-}" HTTPS_PROXY="${HTTPS_PROXY:-}" ALL_PROXY="${ALL_PROXY:-}" NO_PROXY="${NO_PROXY:-}"; \
      export http_proxy="${HTTP_PROXY:-}" https_proxy="${HTTPS_PROXY:-}" all_proxy="${ALL_PROXY:-}" no_proxy="${NO_PROXY:-}"; \
      apt-get update; \
      apt-get install -y --no-install-recommends \
        fonts-liberation \
        fonts-noto-color-emoji \
        novnc \
        openbox \
        websockify \
        x11vnc \
        xvfb; \
      OPENCLAW_NODE_ROOT="$(npm root -g)/openclaw/node_modules"; \
      PLAYWRIGHT_BROWSERS_PATH="${PLAYWRIGHT_BROWSERS_PATH}" \
      node "${OPENCLAW_NODE_ROOT}/playwright-core/cli.js" install --with-deps chromium; \
      rm -rf /var/lib/apt/lists/*; \
    fi

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
      /home/openclaw/go \
      /opt/ms-playwright \
      /opt/uv/python; \
    chown -R openclaw:"${group_name}" \
      /workspace \
      /home/openclaw \
      /opt/ms-playwright \
      /opt/uv

COPY docker/entrypoint.sh /usr/local/bin/container-entrypoint.sh
COPY docker/start-browser-stack.sh /usr/local/bin/start-browser-stack.sh
COPY docker/profile.sh /etc/profile.d/openclaw-profile.sh

RUN chmod 0755 \
      /usr/local/bin/container-entrypoint.sh \
      /usr/local/bin/start-browser-stack.sh \
      /etc/profile.d/openclaw-profile.sh

USER openclaw
WORKDIR /home/openclaw

EXPOSE 18789 18790 5900 6080

ENTRYPOINT ["/usr/bin/tini", "--", "/usr/local/bin/container-entrypoint.sh"]
