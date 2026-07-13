# agentbox

[English](README.md) | [简体中文](README.zh-CN.md)

为 AI Agent 准备的全家桶工作镜像。

预装工具：Python (pipx/uv/uvx)、Node (npm/npx/pnpm)、Go、Rust、Playwright、Chrome、Codex CLI、Claude Code、GitHub CLI、Docker Engine (buildx/Compose)，以及常见构建、调试、网络、数据、媒体、PDF、字体工具。

## 使用

拉起容器，并为 Codex CLI 和 Claude Code 生成好配置：

```bash
docker pull azure99/agentbox:latest

docker run --rm -it --platform linux/amd64 \
  -e AB_GEN_CLAUDE_CONFIG=true \
  -e ANTHROPIC_API_KEY="$ANTHROPIC_API_KEY" \
  -e ANTHROPIC_BASE_URL="${ANTHROPIC_BASE_URL:-https://api.anthropic.com}" \
  azure99/agentbox:latest
```

### 环境变量

| 变量 | 说明 |
| --- | --- |
| `AB_GEN_CODEX_CONFIG` | 设为 `true` 时，根据 `OPENAI_*` 变量生成 Codex CLI 配置文件 |
| `OPENAI_API_KEY` | Codex CLI 使用的 API 密钥 |
| `OPENAI_BASE_URL` | 可选，自定义 API 端点 |
| `AB_GEN_CLAUDE_CONFIG` | 设为 `true` 时，根据 `ANTHROPIC_*` 变量生成 Claude Code 配置文件 |
| `ANTHROPIC_API_KEY` | Claude Code 使用的 API 密钥 |
| `ANTHROPIC_BASE_URL` | 可选，自定义 API 端点 |
| `GITHUB_TOKEN` | 可选，GitHub CLI（`gh`）认证用 |
| `AB_DIND` | 设为 `true` 时启用容器内 dockerd，需配合 `--privileged`，见下节 |

### 容器内使用 Docker

镜像已安装 Docker Engine，但默认不会启动 `dockerd`。使用以下任一模式：

- 宿主 Docker daemon：添加 `--group-add "$(stat -c '%g' /var/run/docker.sock)"` 和 `-v /var/run/docker.sock:/var/run/docker.sock`。
- 容器内 rootful DinD：添加 `--privileged`、`--cgroupns=private` 和 `-e AB_DIND=true`。

如需持久化 DinD 数据，请显式挂载 `/var/lib/docker`。

### 运行用户

默认用户是 `agent`，也可以指定 `--user root`；DinD 模式只支持这两种。非 DinD 模式下使用任意数字 UID 时，请同时传入 `-e HOME=/home/agentbox`。

## 从源码构建

需要 Docker with buildx、GNU Make。

```bash
make build   # 构建并加载 agentbox:v1
make test    # build + smoke 检查
make shell   # 交互式容器，./work → /workspace
```

其余见 [Makefile](Makefile)。

进阶用法：

```bash
# 自定义工作区（路径须已存在）
WORKSPACE_DIR=/path/to/work make shell

# 通过本地代理构建
http_proxy=http://127.0.0.1:7890 https_proxy=http://127.0.0.1:7890 \
  BUILD_NETWORK=host make build
```

## License

MIT. See [LICENSE](LICENSE).