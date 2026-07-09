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

check_missing_command_behavior() {
  local missing_command=agentbox-smoke-command-that-does-not-exist
  local status

  set +e
  env "${missing_command}" >/tmp/agentbox-smoke-missing-command.out 2>/tmp/agentbox-smoke-missing-command.err
  status=$?
  set -e
  require_equal "missing command exit status" "${status}" "127"
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
    bindfs
    fusermount3
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
    sudo
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

check_user_tool_environment() {
  local smoke_command
  local smoke_git

  require_equal "npm global prefix" "$(npm config get prefix)" "/home/agent/.local"
  require_equal "npm cache" "$(npm config get cache)" "/home/agent/.cache/npm"
  require_equal "pnpm global bin" "$(pnpm bin -g)" "/home/agent/.local/share/pnpm/bin"

  require_dir /home/agentbox
  require_writable /home/agentbox
  require_executable /home/agentbox

  smoke_command=/home/agent/.local/bin/agentbox-smoke-user-bin
  printf '%s\n' '#!/usr/bin/env bash' 'printf "%s\n" user-bin-ok' >"${smoke_command}"
  chmod +x "${smoke_command}"
  require_equal "user bin PATH command" "$(agentbox-smoke-user-bin)" "user-bin-ok"

  smoke_git=/home/agent/.local/bin/git
  printf '%s\n' '#!/usr/bin/env bash' 'printf "%s\n" shadowed-git' >"${smoke_git}"
  chmod +x "${smoke_git}"
  if [ "$(command -v git)" = "${smoke_git}" ]; then
    fail "user PATH entries must not shadow system git"
  fi
  if [ "$(bash -lc 'command -v git')" = "${smoke_git}" ]; then
    fail "login shell user PATH entries must not shadow system git"
  fi
  rm -f "${smoke_command}" "${smoke_git}"
}

check_passwordless_sudo() {
  require_equal "sudo root uid" "$(sudo -n id -u)" "0"
  require_equal "sudo root gid" "$(sudo -n -u root -g root id -g)" "0"
}

check_fuse_surface() {
  if ! grep -qxF user_allow_other /etc/fuse.conf; then
    fail "/etc/fuse.conf must enable user_allow_other for bindfs"
  fi
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

check_playwright_chrome() {
  require_command google-chrome
  require_executable /opt/google/chrome/chrome

  google-chrome --version >/dev/null

  node <<'NODE'
const { chromium } = require("/opt/playwright/node_modules/playwright");

(async () => {
  let browser;
  try {
    browser = await chromium.launch({ channel: "chrome", headless: true });
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
check_passwordless_sudo
check_fuse_surface
check_docker_client_surface
check_python_surface
check_missing_command_behavior
check_user_tool_environment
check_local_tool_behaviors
check_playwright_chrome
