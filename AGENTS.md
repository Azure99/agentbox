# Repository Guidelines

## Project Structure & Module Organization

This repository builds the `agentbox` Docker image. The main runtime definition is in `Dockerfile`. Automation lives in `Makefile`, with helper scripts under `scripts/`:

- `scripts/agentbox-entrypoint.sh` generates optional CLI config and starts an internal `dockerd` when requested.
- `scripts/smoke.sh` runs lightweight runtime checks inside the image.
- `scripts/smoke-host.sh` runs host-side DinD smoke test orchestration.
- `scripts/release-build.sh` creates release-oriented image tags.

Documentation is in `README.md` and `README.zh-CN.md`. There is no application source tree or asset pipeline; most changes should be scoped to the Dockerfile, scripts, or docs.

## Build, Test, and Development Commands

- `make build IMAGE=agentbox TAG=v1` builds and loads the image for `linux/amd64`, reusing Docker cache where possible.
- `make refresh IMAGE=agentbox TAG=v1` rebuilds with `--no-cache` for upstream refreshes.
- `make smoke IMAGE=agentbox TAG=v1` runs `scripts/smoke.sh` in a temporary mounted workspace.
- `make test IMAGE=agentbox TAG=v1` builds, then runs smoke checks.
- `make shell IMAGE=agentbox TAG=v1` opens an interactive container with `./work` mounted at `/workspace`.
- `make dind-shell IMAGE=agentbox TAG=v1` opens a privileged interactive container with an internal `dockerd`.
- `make dind-smoke IMAGE=agentbox TAG=v1` runs the DinD-only smoke checks and requires privileged containers.
- `make release-build IMAGE=azure99/agentbox` builds a release-style tag from the latest reachable Git tag snapshot.

Use `BUILD_NETWORK=host` and proxy variables such as `http_proxy=http://127.0.0.1:7890` when external downloads are slow.
DinD mode runs a rootful daemon and supports only the default `agent` user and `--user root`; arbitrary numeric UIDs are non-DinD only.

## Coding Style & Naming Conventions

Shell scripts use Bash with `set -euo pipefail`, lowercase function names, and clear environment-variable names such as `AB_GEN_CODEX_CONFIG`. Preserve each file's existing indentation and do not reformat unrelated code. Keep scripts small and direct; prefer existing Makefile patterns over new tooling. Validate script changes with:

```bash
bash -n scripts/*.sh
shellcheck scripts/*.sh
shfmt -d scripts/agentbox-entrypoint.sh scripts/smoke-host.sh
```

## Testing Guidelines

The primary test gate is the image smoke test: `make smoke IMAGE=<name> TAG=<tag>`. For DinD changes, also run `make dind-smoke`. For entrypoint config-generation changes, run focused `docker run` checks that verify generated config files, non-overwrite behavior, and expected CLI startup. Keep tests behavior-oriented and avoid locking in incidental formatting.

## Commit & Pull Request Guidelines

Recent commits use Conventional Commit style, for example `feat(config): generate cli configs from env` and `chore(release): initial release`. Use concise, imperative messages with a clear scope when useful.

Pull requests should describe the image behavior changed, list validation commands run, and note any external service or proxy assumptions. Include screenshots only when documentation rendering changes materially.

## Security & Configuration Tips

Do not hardcode API keys or tokens in committed files. Runtime credentials should be passed through environment variables such as `OPENAI_API_KEY`, `ANTHROPIC_API_KEY`, and `GITHUB_TOKEN`. Generated container config should remain opt-in through explicit `AB_GEN_*` switches.
