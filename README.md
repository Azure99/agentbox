# agentbox

[English](README.md) | [简体中文](README.zh-CN.md)

An all-in-one work image for AI agents.

Preinstalled tools: Python (pipx/uv/uvx), Node (npm/npx/pnpm), Go, Rust, Playwright, Chrome, Codex CLI, Claude Code, GitHub CLI, Docker Engine (buildx/Compose), plus common build, debugging, networking, data, media, PDF, and font tools.

## Usage

Start a container with Codex CLI and Claude Code configured:

```bash
docker pull azure99/agentbox:latest

docker run --rm -it --platform linux/amd64 \
  -e AB_GEN_CLAUDE_CONFIG=true \
  -e ANTHROPIC_API_KEY="$ANTHROPIC_API_KEY" \
  -e ANTHROPIC_BASE_URL="${ANTHROPIC_BASE_URL:-https://api.anthropic.com}" \
  azure99/agentbox:latest
```

### Environment Variables

| Variable | Description |
| --- | --- |
| `AB_GEN_CODEX_CONFIG` | Set to `true` to generate a Codex CLI config file from `OPENAI_*` variables |
| `OPENAI_API_KEY` | API key used by Codex CLI |
| `OPENAI_BASE_URL` | Optional custom API endpoint |
| `AB_GEN_CLAUDE_CONFIG` | Set to `true` to generate a Claude Code config file from `ANTHROPIC_*` variables |
| `ANTHROPIC_API_KEY` | API key used by Claude Code |
| `ANTHROPIC_BASE_URL` | Optional custom API endpoint |
| `GITHUB_TOKEN` | Optional token for GitHub CLI (`gh`) authentication |
| `AB_DIND` | Set to `true` to enable the internal `dockerd`; requires `--privileged`, as described below |

### Using Docker in the Container

Docker Engine is installed, but `dockerd` does not start by default. Choose one mode:

- Host Docker daemon: add `--group-add "$(stat -c '%g' /var/run/docker.sock)"` and `-v /var/run/docker.sock:/var/run/docker.sock`.
- Internal rootful DinD: add `--privileged`, `--cgroupns=private`, and `-e AB_DIND=true`.

Mount `/var/lib/docker` explicitly to persist DinD data.

### Runtime User

The default user is `agent`; you may also set `--user root`. DinD mode supports only these two options. For arbitrary numeric UIDs in non-DinD mode, pass `-e HOME=/home/agentbox`.

## Build from Source

Requires Docker with buildx and GNU Make.

```bash
make build   # Build and load agentbox:v1
make test    # build + smoke checks
make shell   # Interactive container, ./work -> /workspace
```

See [Makefile](Makefile) for other targets.

Advanced usage:

```bash
# Custom workspace (the path must already exist)
WORKSPACE_DIR=/path/to/work make shell

# Build through a local proxy
http_proxy=http://127.0.0.1:7890 https_proxy=http://127.0.0.1:7890 \
  BUILD_NETWORK=host make build
```

## License

MIT. See [LICENSE](LICENSE).
