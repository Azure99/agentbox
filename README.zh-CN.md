# agentbox

[English](README.md) | [简体中文](README.zh-CN.md)

为 AI Agent 准备的全家桶工作镜像。

预装工具：Python (pipx/uv/uvx)、Node (npm/npx/pnpm)、Go、Rust、Playwright、Chrome、Codex CLI、Claude Code、GitHub CLI、Docker Engine (buildx/Compose)，以及常见构建、调试、网络、数据、媒体、PDF、字体工具。

## 使用

```bash
docker pull azure99/agentbox:latest

# `AB_GEN_CODEX_CONFIG=true` 和 `AB_GEN_CLAUDE_CONFIG=true` 会根据 API 环境变量生成 CLI 配置文件。
docker run --rm -it --platform linux/amd64 \
  -e AB_GEN_CODEX_CONFIG=true \
  -e AB_GEN_CLAUDE_CONFIG=true \
  -e OPENAI_API_KEY="$OPENAI_API_KEY" \
  -e OPENAI_BASE_URL="${OPENAI_BASE_URL:-https://api.openai.com/v1}" \
  -e ANTHROPIC_API_KEY="$ANTHROPIC_API_KEY" \
  -e ANTHROPIC_BASE_URL="${ANTHROPIC_BASE_URL:-https://api.anthropic.com}" \
  -e GITHUB_TOKEN="$GITHUB_TOKEN" \
  azure99/agentbox:latest
```

镜像已安装 Docker Engine，但默认不会启动 `dockerd`。使用以下任一模式：

- 宿主 Docker daemon：添加 `--group-add "$(stat -c '%g' /var/run/docker.sock)"` 和 `-v /var/run/docker.sock:/var/run/docker.sock`。
- 容器内 rootful DinD：添加 `--privileged`、`--cgroupns=private` 和 `-e AB_DIND=true`。

如需持久化 DinD 数据，请显式挂载 `/var/lib/docker`。

默认用户是 `agent`；可以指定 `--user root`。非 DinD 模式下使用任意数字 UID 时，请同时传入 `-e HOME=/home/agentbox`。DinD 模式只支持默认 `agent` 用户和 `--user root`。

## 从源码构建

需要 Docker with buildx、GNU Make。

```bash
make build           # 构建并加载 agentbox:v1
make test            # build + smoke 检查
make dind-smoke      # privileged DinD smoke 检查
make shell           # 交互式容器，./work → /workspace
make dind-shell      # 启动带内部 dockerd 的 privileged 交互式容器
make refresh         # --pull --no-cache 全量重建
make release-build   # 从最新可达 Git tag 快照构建
```

自定义工作区（路径须已存在）：

```bash
WORKSPACE_DIR=/path/to/work make shell
```

通过本地代理构建：

```bash
http_proxy=http://127.0.0.1:7890 https_proxy=http://127.0.0.1:7890 \
  BUILD_NETWORK=host make build
```

## License

MIT. See [LICENSE](LICENSE).
