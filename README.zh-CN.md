# agentbox

[English](README.md) | [简体中文](README.zh-CN.md)

为 AI Agent 准备的全家桶工作镜像。

预装工具：Python (pipx/uv/uvx)、Node (npm/npx/pnpm)、Go、Rust、Playwright Chromium、Codex CLI、Claude Code、GitHub CLI、Docker CLI (buildx/Compose)，以及常见构建、调试、网络、数据、媒体、PDF、字体工具。

## 使用

```bash
docker pull azure99/agentbox:latest

docker run --rm -it --platform linux/amd64 \
  -e OPENAI_API_KEY="$OPENAI_API_KEY" \
  -e ANTHROPIC_API_KEY="$ANTHROPIC_API_KEY" \
  -e GITHUB_TOKEN="$GITHUB_TOKEN" \
  # --group-add "$(stat -c '%g' /var/run/docker.sock)" \
  # -v /var/run/docker.sock:/var/run/docker.sock \
  -v "$PWD/work:/workspace" -w /workspace \
  azure99/agentbox:latest
```

环境变量和宿主 Docker socket 按需取消注释，镜像仅含 Docker client。

## 从源码构建

需要 Docker with buildx、GNU Make。

```bash
make build           # 构建并加载 agentbox:v1
make test            # build + smoke 检查
make shell           # 交互式容器，./work → /workspace
make refresh         # --pull --no-cache 全量重建
make release-build   # 用最新 git tag 打版本标签
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