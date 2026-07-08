# Repository Guidelines

## Project Structure & Module Organization

This repository builds the `agentbox` Docker image. The main runtime definition is in `Dockerfile`. Automation lives in `Makefile`, with helper scripts under `scripts/`:

- `scripts/agentbox-entrypoint.sh` generates optional CLI config at container startup.
- `scripts/smoke.sh` runs lightweight runtime checks inside the image.
- `scripts/release-build.sh` creates release-oriented image tags.

Documentation is in `README.md` and `README.zh-CN.md`. There is no application source tree or asset pipeline; most changes should be scoped to the Dockerfile, scripts, or docs.

## Build, Test, and Development Commands

- `make build IMAGE=agentbox TAG=v1` builds and loads the image for `linux/amd64`, reusing Docker cache where possible.
- `make refresh IMAGE=agentbox TAG=v1` rebuilds with `--no-cache` for upstream refreshes.
- `make smoke IMAGE=agentbox TAG=v1` runs `scripts/smoke.sh` in a temporary mounted workspace.
- `make test IMAGE=agentbox TAG=v1` builds, then runs smoke checks.
- `make shell IMAGE=agentbox TAG=v1` opens an interactive container with `./work` mounted at `/workspace`.
- `make release-build IMAGE=azure99/agentbox` builds a release-style tag from the current Git state.

Use `BUILD_NETWORK=host` and proxy variables such as `http_proxy=http://127.0.0.1:7890` when external downloads are slow.

## Coding Style & Naming Conventions

Shell scripts use Bash with `set -euo pipefail`, tabs for indentation in function bodies, lowercase function names, and clear environment-variable names such as `AB_GEN_CODEX_CONFIG`. Keep scripts small and direct; prefer existing Makefile patterns over new tooling. Validate script changes with:

```bash
bash -n scripts/agentbox-entrypoint.sh
shellcheck scripts/agentbox-entrypoint.sh
shfmt -d scripts/agentbox-entrypoint.sh
```

## Testing Guidelines

The primary test gate is the image smoke test: `make smoke IMAGE=<name> TAG=<tag>`. For entrypoint changes, also run focused `docker run` checks that verify generated config files, non-overwrite behavior, and expected CLI startup. Keep tests behavior-oriented and avoid locking in incidental formatting.

## Commit & Pull Request Guidelines

Recent commits use Conventional Commit style, for example `feat(config): generate cli configs from env` and `chore(release): initial release`. Use concise, imperative messages with a clear scope when useful.

Pull requests should describe the image behavior changed, list validation commands run, and note any external service or proxy assumptions. Include screenshots only when documentation rendering changes materially.

## Security & Configuration Tips

Do not hardcode API keys or tokens in committed files. Runtime credentials should be passed through environment variables such as `OPENAI_API_KEY`, `ANTHROPIC_API_KEY`, and `GITHUB_TOKEN`. Generated container config should remain opt-in through explicit `AB_GEN_*` switches.
