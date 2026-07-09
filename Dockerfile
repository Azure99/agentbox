# syntax=docker/dockerfile:1

# Image identity and global runtime environment.
FROM ubuntu:24.04

LABEL org.opencontainers.image.title="agentbox" \
      org.opencontainers.image.description="Ubuntu 24.04 linux/amd64 personal agent box with language runtimes, agent CLIs, Chrome, and distro build/debug/data/media/PDF/font tools"

ENV DEBIAN_FRONTEND=noninteractive
ENV LANG=C.UTF-8
ENV LC_ALL=C.UTF-8
ENV TZ=Etc/UTC
ENV RUSTUP_HOME=/opt/rust/rustup
ENV PATH=/opt/npm-global/bin:/usr/local/go/bin:/opt/rust/cargo/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:/home/agent/.local/bin:/home/agent/.local/share/pnpm/bin:/home/agent/go/bin:/home/agent/.cargo/bin:/root/.local/bin:/root/.local/share/pnpm/bin:/root/go/bin:/root/.cargo/bin:/home/agentbox/.local/bin:/home/agentbox/.local/share/pnpm/bin:/home/agentbox/go/bin:/home/agentbox/.cargo/bin

# Base apt carrying surface.
RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        build-essential \
        bindfs \
        cmake \
        ninja-build \
        pkg-config \
        ca-certificates \
        bash \
        curl \
        wget \
        git \
        git-lfs \
        pre-commit \
        openssh-client \
        iproute2 \
        iputils-ping \
        dnsutils \
        jq \
        shellcheck \
        shfmt \
        ripgrep \
        fd-find \
        fuse3 \
        fzf \
        less \
        rsync \
        tmux \
        tree \
        bat \
        git-delta \
        netcat-openbsd \
        socat \
        sudo \
        httpie \
        tzdata \
        unzip \
        zip \
        xz-utils \
        zstd \
        sqlite3 \
        procps \
        psmisc \
        file \
        lsof \
        strace \
        python3 \
        python-is-python3 \
        python3-venv \
        pipx \
        ffmpeg \
        imagemagick \
        poppler-utils \
        fontconfig \
        fonts-liberation \
        fonts-noto-cjk \
        fonts-noto-color-emoji \
        libasound2t64 \
        libcairo2 \
        libdbus-1-3 \
        libdrm2 \
        libgbm1 \
        libglib2.0-0t64 \
        libnspr4 \
        libnss3 \
        libpango-1.0-0 \
        libx11-6 \
        libx11-xcb1 \
        libxcb1 \
        libxext6 \
        libxfixes3 \
        libxkbcommon0 \
        libxrandr2 \
        libxrender1 \
        libxshmfence1 \
    && ln -s /usr/bin/fdfind /usr/local/bin/fd \
    && test -x /usr/bin/batcat \
    && ln -sf /usr/bin/batcat /usr/local/bin/bat \
    && sed -i 's/^#user_allow_other/user_allow_other/' /etc/fuse.conf \
    && grep -qxF user_allow_other /etc/fuse.conf \
    && rm -rf /var/lib/apt/lists/*

SHELL ["/bin/bash", "-o", "pipefail", "-c"]

# Google Chrome.
RUN set -eux; \
    install -m 0755 -d /etc/apt/keyrings; \
    curl --fail --show-error --location --retry 5 --retry-delay 2 --retry-connrefused --output /etc/apt/keyrings/google-chrome.asc https://dl.google.com/linux/linux_signing_key.pub; \
    chmod a+r /etc/apt/keyrings/google-chrome.asc; \
    printf '%s\n' 'deb [arch=amd64 signed-by=/etc/apt/keyrings/google-chrome.asc] https://dl.google.com/linux/chrome/deb/ stable main' >/etc/apt/sources.list.d/google-chrome.list; \
    apt-get update; \
    apt-get install -y --no-install-recommends google-chrome-stable; \
    google-chrome --version; \
    test -x /opt/google/chrome/chrome; \
    rm -rf /var/lib/apt/lists/*

# Node/npm/npx from upstream latest LTS.
RUN set -eux; \
    build_home="$(mktemp -d)"; \
    trap 'rm -rf "${build_home}"' EXIT; \
    export HOME="${build_home}"; \
    export XDG_CACHE_HOME="${build_home}/.cache"; \
    export NPM_CONFIG_CACHE="${build_home}/.cache/npm"; \
    export NPM_CONFIG_USERCONFIG="${build_home}/.npmrc"; \
    mkdir -p "${build_home}/.cache/npm"; \
    node_version="$(curl --fail --show-error --location --retry 5 --retry-delay 2 --retry-connrefused https://nodejs.org/dist/index.json | jq -er '[.[] | select(.lts != false)][0].version')"; \
    curl --fail --show-error --location --retry 5 --retry-delay 2 --retry-connrefused --output "${build_home}/node.tar.xz" "https://nodejs.org/dist/${node_version}/node-${node_version}-linux-x64.tar.xz"; \
    rm -rf /opt/node; \
    tar -xJf "${build_home}/node.tar.xz" -C /opt; \
    mv "/opt/node-${node_version}-linux-x64" /opt/node; \
    ln -sf /opt/node/bin/node /usr/local/bin/node; \
    ln -sf /opt/node/bin/npm /usr/local/bin/npm; \
    ln -sf /opt/node/bin/npx /usr/local/bin/npx; \
    rm -f /opt/node/bin/corepack; \
    rm -rf /opt/node/lib/node_modules/corepack; \
    mkdir -p /opt/node/etc; \
    printf '%s\n' 'prefix=${HOME}/.local' 'cache=${HOME}/.cache/npm' >/opt/node/etc/npmrc; \
    node --version; \
    npm --version; \
    npx --version; \
    chown -R root:root /opt/node; \
    chmod -R go-w /opt/node

# uv, yq, Go, and Rust stable.
RUN set -eux; \
    build_home="$(mktemp -d)"; \
    trap 'rm -rf "${build_home}" /root/.cargo /root/.rustup' EXIT; \
    export HOME="${build_home}"; \
    export XDG_CACHE_HOME="${build_home}/.cache"; \
    export UV_CACHE_DIR="${build_home}/.cache/uv"; \
    mkdir -p "${build_home}/.cache/uv"; \
    curl --fail --show-error --location --retry 5 --retry-delay 2 --retry-connrefused --output "${build_home}/uv.tar.gz" https://github.com/astral-sh/uv/releases/latest/download/uv-x86_64-unknown-linux-gnu.tar.gz; \
    tar -xzf "${build_home}/uv.tar.gz" -C "${build_home}"; \
    install -m 0755 "${build_home}/uv-x86_64-unknown-linux-gnu/uv" /usr/local/bin/uv; \
    install -m 0755 "${build_home}/uv-x86_64-unknown-linux-gnu/uvx" /usr/local/bin/uvx; \
    yq_version=v4.53.3; \
    curl --fail --show-error --location --retry 5 --retry-delay 2 --retry-connrefused --output "${build_home}/yq" "https://github.com/mikefarah/yq/releases/download/${yq_version}/yq_linux_amd64"; \
    install -m 0755 "${build_home}/yq" /usr/local/bin/yq; \
    go_file="$(curl --fail --show-error --location --retry 5 --retry-delay 2 --retry-connrefused https://go.dev/dl/?mode=json | jq -er '[.[] | select(.stable == true)][0].files | map(select(.filename | test("^go[0-9][^/]*[.]linux-amd64[.]tar[.]gz$"))) | .[0].filename')"; \
    curl --fail --show-error --location --retry 5 --retry-delay 2 --retry-connrefused --output "${build_home}/go.tar.gz" "https://go.dev/dl/${go_file}"; \
    rm -rf /usr/local/go; \
    tar -xzf "${build_home}/go.tar.gz" -C /usr/local; \
    curl --fail --show-error --location --retry 5 --retry-delay 2 --retry-connrefused --output "${build_home}/rustup-init" https://static.rust-lang.org/rustup/dist/x86_64-unknown-linux-gnu/rustup-init; \
    chmod +x "${build_home}/rustup-init"; \
    rm -rf /opt/rust; \
    mkdir -p /opt/rust/rustup /opt/rust/cargo; \
    RUSTUP_HOME=/opt/rust/rustup CARGO_HOME=/opt/rust/cargo "${build_home}/rustup-init" -y --no-modify-path --profile minimal --default-host x86_64-unknown-linux-gnu --default-toolchain stable --component rustfmt --component clippy; \
    uv --version; \
    uvx --version; \
    yq_actual="$(yq --version)"; \
    echo "${yq_actual}"; \
    [[ "${yq_actual}" == *" version ${yq_version}" ]]; \
    go version; \
    RUSTUP_HOME=/opt/rust/rustup CARGO_HOME=/opt/rust/cargo /opt/rust/cargo/bin/rustup --version; \
    RUSTUP_HOME=/opt/rust/rustup CARGO_HOME=/opt/rust/cargo /opt/rust/cargo/bin/rustc --version; \
    RUSTUP_HOME=/opt/rust/rustup CARGO_HOME=/opt/rust/cargo /opt/rust/cargo/bin/cargo --version; \
    chown -R root:root /usr/local/go /opt/rust; \
    chmod -R go-w /usr/local/go /opt/rust

# npm-based tools: pnpm, Playwright, Codex CLI, and Claude Code.
RUN set -eux; \
    build_home="$(mktemp -d)"; \
    trap 'rm -rf "${build_home}" /root/.npm' EXIT; \
    export HOME="${build_home}"; \
    export XDG_CACHE_HOME="${build_home}/.cache"; \
    export NPM_CONFIG_CACHE="${build_home}/.cache/npm"; \
    export NPM_CONFIG_USERCONFIG="${build_home}/.npmrc"; \
    mkdir -p "${build_home}/.cache/npm" /opt/npm-global /opt/playwright /opt/agent-cli; \
    NPM_CONFIG_PREFIX=/opt/npm-global npm install -g pnpm@latest --no-audit --no-fund --loglevel=error; \
    test -x /opt/npm-global/bin/pnpm; \
    /opt/npm-global/bin/pnpm --version; \
    PLAYWRIGHT_SKIP_BROWSER_DOWNLOAD=1 npm install --prefix /opt/playwright @playwright/test@latest --no-audit --no-fund --loglevel=error; \
    ln -sf /opt/playwright/node_modules/.bin/playwright /usr/local/bin/playwright; \
    node -e 'const { chromium }=require("/opt/playwright/node_modules/playwright"); (async () => { let browser; try { browser=await chromium.launch({ channel: "chrome", headless: true }); const page=await browser.newPage(); await page.goto("data:text/html,<title>pw-smoke</title><body>ok</body>"); const title=await page.title(); if (title !== "pw-smoke") throw new Error(`unexpected title: ${title}`); } finally { if (browser) await browser.close(); } })().catch(error => { console.error(error); process.exit(1); });'; \
    npm install --prefix /opt/agent-cli @openai/codex@latest @anthropic-ai/claude-code@latest --no-audit --no-fund --loglevel=error; \
    test -x /opt/agent-cli/node_modules/.bin/codex; \
    test -x /opt/agent-cli/node_modules/.bin/claude; \
    ln -sf /opt/agent-cli/node_modules/.bin/codex /usr/local/bin/codex; \
    ln -sf /opt/agent-cli/node_modules/.bin/claude /usr/local/bin/claude; \
    codex --version; \
    claude --version; \
    chown -R root:root /opt/npm-global /opt/playwright /opt/agent-cli; \
    chmod -R go-w /opt/npm-global /opt/playwright /opt/agent-cli

# GitHub CLI from the official apt repository.
RUN set -eux; \
    mkdir -p /usr/share/keyrings; \
    curl --fail --show-error --location --retry 5 --retry-delay 2 --retry-connrefused --output /usr/share/keyrings/githubcli-archive-keyring.gpg https://cli.github.com/packages/githubcli-archive-keyring.gpg; \
    chmod go+r /usr/share/keyrings/githubcli-archive-keyring.gpg; \
    echo 'deb [arch=amd64 signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main' >/etc/apt/sources.list.d/github-cli.list; \
    apt-get update; \
    apt-get install -y --no-install-recommends gh; \
    GH_TELEMETRY=false GH_NO_UPDATE_NOTIFIER=1 GH_NO_EXTENSION_UPDATE_NOTIFIER=1 gh --version; \
    rm -rf /var/lib/apt/lists/*

# Docker CLI and CLI plugins from the official apt repository; daemon intentionally omitted.
RUN set -eux; \
    install -m 0755 -d /etc/apt/keyrings; \
    curl --fail --show-error --location --retry 5 --retry-delay 2 --retry-connrefused --output /etc/apt/keyrings/docker.asc https://download.docker.com/linux/ubuntu/gpg; \
    chmod a+r /etc/apt/keyrings/docker.asc; \
    . /etc/os-release; \
    docker_arch="$(dpkg --print-architecture)"; \
    docker_codename="${UBUNTU_CODENAME:-${VERSION_CODENAME}}"; \
    printf '%s\n' \
        'Types: deb' \
        'URIs: https://download.docker.com/linux/ubuntu' \
        "Suites: ${docker_codename}" \
        'Components: stable' \
        "Architectures: ${docker_arch}" \
        'Signed-By: /etc/apt/keyrings/docker.asc' \
        >/etc/apt/sources.list.d/docker.sources; \
    apt-get update; \
    apt-get install -y --no-install-recommends \
        docker-ce-cli \
        docker-buildx-plugin \
        docker-compose-plugin; \
    docker --version; \
    docker buildx version; \
    docker compose version; \
    if command -v dockerd >/dev/null 2>&1; then \
        echo "dockerd must not be installed; this image is Docker client only" >&2; \
        exit 1; \
    fi; \
    for package_name in docker-ce containerd.io docker-ce-rootless-extras docker.io docker-compose docker-compose-v2; do \
        if dpkg-query -W -f='${db:Status-Abbrev}' "${package_name}" 2>/dev/null | grep -q '^i'; then \
            echo "unexpected Docker daemon/runtime package: ${package_name}" >&2; \
            exit 1; \
        fi; \
    done; \
    rm -rf /var/lib/apt/lists/*

# Runtime user and permission boundary.
RUN if getent passwd 1000 >/dev/null; then userdel --remove "$(getent passwd 1000 | cut -d: -f1)"; fi \
    && if getent group 1000 >/dev/null; then groupdel "$(getent group 1000 | cut -d: -f1)"; fi \
    && groupadd --gid 1000 agent \
    && rm -rf /home/agent \
    && useradd --uid 1000 --gid 1000 --create-home --shell /bin/bash agent \
    && install -d -m 0755 /etc/sudoers.d \
    && printf '%s\n' 'agent ALL=(ALL:ALL) NOPASSWD:ALL' >/etc/sudoers.d/agent \
    && chmod 0440 /etc/sudoers.d/agent \
    && visudo -cf /etc/sudoers.d/agent \
    && rm -rf \
        /home/agent/.cache/npm \
        /home/agent/.local/state/gh \
        /home/agent/.npm \
        /home/agent/.config/gh \
    && mkdir -p \
        /workspace \
        /home/agent/.config \
        /home/agent/.local/state \
        /home/agent/.local/bin \
        /home/agent/.local/share \
        /home/agent/.local/share/pipx \
        /home/agent/.local/share/pnpm \
        /home/agent/.cache \
        /home/agent/.cache/pip \
        /home/agent/.cache/uv \
        /home/agent/.cache/npm \
        /home/agent/.cache/go-build \
        /home/agent/.ssh \
        /home/agent/.cargo \
        /home/agent/.cargo/bin \
        /home/agent/go \
        /home/agent/go/bin \
        /home/agentbox \
    && chown -R agent:agent /workspace /home/agent \
    && sed -i '/^# set PATH so it includes/,/^fi$/d' /home/agent/.profile \
    && chmod 0711 /root /home/agent \
    && chmod 1777 /workspace /home/agentbox \
    && chmod 0700 /home/agent/.ssh

COPY --chmod=0755 scripts/agentbox-entrypoint.sh /usr/local/bin/agentbox-entrypoint

USER agent
WORKDIR /workspace
ENTRYPOINT ["/usr/local/bin/agentbox-entrypoint"]
CMD ["/bin/bash"]
