# agentbox

[English](README.md) | [简体中文](README.zh-CN.md)

An all-in-one work image for AI agents.

Preinstalled tools: Python (pipx/uv/uvx), Node (npm/npx/pnpm), Go, Rust, Playwright, Chrome, Codex CLI, Claude Code, GitHub CLI, Docker CLI (buildx/Compose), plus common build, debugging, networking, data, media, PDF, and font tools.

## Usage

```bash
docker pull azure99/agentbox:latest

# `AB_GEN_CODEX_CONFIG=true` and `AB_GEN_CLAUDE_CONFIG=true` generate CLI config files from API env vars.
docker run --rm -it --platform linux/amd64 \
  -e AB_GEN_CODEX_CONFIG=true \
  -e AB_GEN_CLAUDE_CONFIG=true \
  -e OPENAI_API_KEY="$OPENAI_API_KEY" \
  -e OPENAI_BASE_URL="${OPENAI_BASE_URL:-https://api.openai.com/v1}" \
  -e ANTHROPIC_API_KEY="$ANTHROPIC_API_KEY" \
  -e ANTHROPIC_BASE_URL="${ANTHROPIC_BASE_URL:-https://api.anthropic.com}" \
  -e GITHUB_TOKEN="$GITHUB_TOKEN" \
  -v "$PWD/work:/workspace" -w /workspace \
  azure99/agentbox:latest
```

Add `--group-add "$(stat -c '%g' /var/run/docker.sock)"` and `-v /var/run/docker.sock:/var/run/docker.sock` if you need the host Docker socket. The image includes only the Docker client.

The default user is `agent`; you may set `--user root`. For arbitrary numeric UIDs, pass `-e HOME=/home/agentbox`.

## Build from Source

Requires Docker with buildx and GNU Make.

```bash
make build           # Build and load agentbox:v1
make test            # build + smoke checks
make shell           # Interactive container, ./work -> /workspace
make refresh         # Full rebuild with --pull --no-cache
make release-build   # Build a version tag from the latest git tag
```

Custom workspace (the path must already exist):

```bash
WORKSPACE_DIR=/path/to/work make shell
```

Build through a local proxy:

```bash
http_proxy=http://127.0.0.1:7890 https_proxy=http://127.0.0.1:7890 \
  BUILD_NETWORK=host make build
```

## License

MIT. See [LICENSE](LICENSE).
