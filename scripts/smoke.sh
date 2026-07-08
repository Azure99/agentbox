#!/usr/bin/env bash
set -euo pipefail

fail() {
  printf '%s\n' "$*" >&2
  return 1
}

require_command() {
  local name="$1"

  if ! command -v "${name}" >/dev/null 2>&1; then
    fail "missing required command: ${name}"
  fi
}

require_equal() {
  local label="$1"
  local actual="$2"
  local expected="$3"

  if [ "${actual}" != "${expected}" ]; then
    fail "${label} is ${actual}; expected ${expected}"
  fi
}

require_dir() {
  local path="$1"

  if [ ! -d "${path}" ]; then
    fail "${path} must exist and be a directory"
  fi
}

require_writable() {
  local path="$1"

  if [ ! -w "${path}" ]; then
    fail "${path} must be writable"
  fi
}

require_executable() {
  local path="$1"

  if [ ! -x "${path}" ]; then
    fail "${path} must be executable"
  fi
}

check_runtime_identity() {
  require_equal "runtime user" "$(id -un)" "agent"
  require_equal "runtime uid" "$(id -u)" "1000"
  require_equal "runtime gid" "$(id -g)" "1000"
  require_equal "HOME" "${HOME:-}" "/home/agent"
  require_equal "PWD" "${PWD:-}" "/workspace"
  require_dir /workspace
  require_writable /workspace
  require_executable /workspace

  if ! printf '%s\n' "workspace-ok" >/workspace/.agentbox-smoke-write-ok; then
    fail "failed to write smoke marker in /workspace"
  fi
  if [ ! -s /workspace/.agentbox-smoke-write-ok ]; then
    fail "smoke marker in /workspace is missing or empty"
  fi

  require_dir /home/agent
  require_writable /home/agent
}

check_command_surface() {
  local command_name
  local commands=(
    git
    ssh
    curl
    jq
    rg
    fd
    fzf
    python
    python3
    pipx
    uv
    uvx
    cmake
    ctest
    cpack
    ninja
    pkg-config
    lsof
    strace
    sqlite3
    zstd
    socat
    wget
    ffmpeg
    ffprobe
    pre-commit
    convert
    identify
    pdfinfo
    pdftotext
    fc-match
    fc-list
    node
    npm
    npx
    pnpm
    go
    rustup
    rustc
    cargo
    playwright
    codex
    claude
    gh
    docker
  )

  for command_name in "${commands[@]}"; do
    require_command "${command_name}"
  done
}

check_docker_client_surface() {
  local package_name

  docker --version >/dev/null
  docker buildx version >/dev/null
  docker compose version >/dev/null

  if command -v dockerd >/dev/null 2>&1; then
    fail "dockerd must not be installed; this image is Docker client only"
  fi

  for package_name in docker-ce containerd.io docker-ce-rootless-extras docker.io docker-compose docker-compose-v2; do
    if dpkg-query -W -f='${db:Status-Abbrev}' "${package_name}" 2>/dev/null | grep -q '^i'; then
      fail "${package_name} must not be installed; this image is Docker client only"
    fi
  done
}

check_python_surface() {
  if ! python3 -m venv --help >/dev/null; then
    fail "python3 -m venv is not available"
  fi

  require_equal "python major version" "$(python -c 'import sys; print(sys.version_info[0])')" "3"
}

check_local_tool_behaviors() {
  local font_match
  local zstd_round_trip

  require_equal "sqlite memory query" "$(sqlite3 ':memory:' 'select 1;')" "1"

  zstd_round_trip="$(printf '%s' "ok" | zstd -q -c | zstd -q -d -c)"
  require_equal "zstd round trip" "${zstd_round_trip}" "ok"

  if ! convert -size 1x1 xc:white png:- >/dev/null; then
    fail "ImageMagick failed to generate a 1x1 PNG"
  fi

  font_match="$({ fc-match 'Noto Sans CJK SC'; fc-match ':lang=zh-cn'; } 2>/dev/null || true)"
  case "${font_match}" in
    *NotoSansCJK*|*Noto\ Sans\ CJK*|*Noto\ Serif\ CJK*) ;;
    *) fail "fontconfig did not find a Noto CJK font; got: ${font_match}" ;;
  esac
}

check_playwright_chromium() {
  PLAYWRIGHT_BROWSERS_PATH="${PLAYWRIGHT_BROWSERS_PATH:-/ms-playwright}" node <<'NODE'
const { chromium } = require("/opt/playwright/node_modules/playwright");

(async () => {
  let browser;
  try {
    browser = await chromium.launch({ headless: true });
    const page = await browser.newPage();
    await page.goto("data:text/html,<title>pw-smoke</title><body>ok</body>");
    const title = await page.title();
    if (title !== "pw-smoke") {
      throw new Error(`unexpected page title: ${title}`);
    }
  } finally {
    if (browser) {
      await browser.close();
    }
  }
})().catch((error) => {
  console.error(error);
  process.exit(1);
});
NODE
}

check_runtime_identity
check_command_surface
check_docker_client_surface
check_python_surface
check_local_tool_behaviors
check_playwright_chromium
