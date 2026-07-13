#!/bin/bash
set -euo pipefail

if [ "${AB_DIND:-}" = "true" ] && [ "$$" -eq 1 ]; then
	exec /usr/local/bin/docker-init -g -- "$0" "$@"
fi

toml_string() {
	local value="$1"
	case "${value}" in
	*$'\n'* | *$'\r'*)
		printf '%s\n' "agentbox: TOML strings cannot contain newlines" >&2
		exit 1
		;;
	esac
	value="${value//\\/\\\\}"
	value="${value//\"/\\\"}"
	printf '"%s"' "${value}"
}

key_suffix() {
	local value="$1"
	if [ "${#value}" -gt 20 ]; then
		printf '%s' "${value: -20}"
	else
		printf '%s' "${value}"
	fi
}

check_docker_mounts() {
	if mountpoint -q /var/run/docker.sock || mountpoint -q /var/run; then
		printf '%s\n' "agentbox: mounting host Docker runtime paths is not supported" >&2
		exit 1
	fi
}

check_docker_cgroupns() {
	if grep -qv ':/$' /proc/self/cgroup; then
		printf '%s\n' "agentbox: DinD requires a private cgroup namespace (--cgroupns=private)" >&2
		exit 1
	fi
}

start_dockerd() {
	local socket_group
	socket_group="$(id -g)"

	if [ "$(id -u)" -eq 0 ]; then
		TINI_SUBREAPER=1 setsid /usr/local/bin/dockerd-entrypoint.sh dockerd \
			--host=unix:///var/run/docker.sock \
			--group="${socket_group}" &
	else
		TINI_SUBREAPER=1 setsid sudo -n -E /usr/local/bin/dockerd-entrypoint.sh dockerd \
			--host=unix:///var/run/docker.sock \
			--group="${socket_group}" &
	fi
	dockerd_pid="$!"

	for _ in {1..60}; do
		if docker info >/dev/null 2>&1; then
			printf '%s\n' "agentbox: dockerd is ready" >&2
			return
		fi
		if ! kill -0 "${dockerd_pid}" >/dev/null 2>&1; then
			printf '%s\n' "agentbox: dockerd exited before becoming ready" >&2
			exit 1
		fi
		sleep 1
	done

	printf '%s\n' "agentbox: timed out waiting for dockerd" >&2
	exit 1
}

generate_codex_config() {
	if [ "${AB_GEN_CODEX_CONFIG:-}" != "true" ]; then
		return
	fi
	if [ -z "${OPENAI_BASE_URL:-}" ]; then
		return
	fi

	local codex_home="${HOME}/.codex"
	local config_file="${codex_home}/config.toml"

	if [ -e "${config_file}" ]; then
		printf '%s\n' "agentbox: ${config_file} already exists; leaving it unchanged" >&2
		return
	fi

	install -d -m 0700 "${codex_home}"

	local openai_base_url
	openai_base_url="$(toml_string "${OPENAI_BASE_URL}")"

	(
		umask 077
		cat >"${config_file}" <<EOF
model_provider = "openai_env"

[model_providers.openai_env]
name = "OpenAI"
base_url = ${openai_base_url}
env_key = "OPENAI_API_KEY"
wire_api = "responses"
supports_websockets = false
EOF
	)
}

generate_claude_config() {
	if [ "${AB_GEN_CLAUDE_CONFIG:-}" != "true" ]; then
		return
	fi
	if [ -z "${ANTHROPIC_BASE_URL:-}" ]; then
		return
	fi

	local claude_dir="${HOME}/.claude"
	local settings_file="${claude_dir}/settings.json"
	local state_file="${HOME}/.claude.json"
	local project_dir="${PWD:-/workspace}"

	install -d -m 0700 "${claude_dir}"

	if [ -e "${settings_file}" ]; then
		printf '%s\n' "agentbox: ${settings_file} already exists; leaving it unchanged" >&2
	else
		(
			umask 077
			jq -n \
				--arg anthropic_base_url "${ANTHROPIC_BASE_URL}" \
				--arg anthropic_api_key "${ANTHROPIC_API_KEY:-}" \
				--arg anthropic_model "${ANTHROPIC_MODEL:-}" \
				'{
					env: ({
						ANTHROPIC_BASE_URL: $anthropic_base_url,
						CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC: "1"
					}
					+ if $anthropic_api_key == "" then {} else {ANTHROPIC_API_KEY: $anthropic_api_key} end
					+ if $anthropic_model == "" then {} else {ANTHROPIC_MODEL: $anthropic_model} end)
				}' >"${settings_file}"
		)
	fi

	if [ -e "${state_file}" ]; then
		printf '%s\n' "agentbox: ${state_file} already exists; leaving it unchanged" >&2
		return
	fi

	local api_key_suffix=""
	if [ -n "${ANTHROPIC_API_KEY:-}" ]; then
		api_key_suffix="$(key_suffix "${ANTHROPIC_API_KEY}")"
	fi

	(
		umask 077
		jq -n \
			--arg project_dir "${project_dir}" \
			--arg api_key_suffix "${api_key_suffix}" \
			'
				{
					hasCompletedOnboarding: true,
					projects: {
						($project_dir): {
							hasTrustDialogAccepted: true
						}
					}
				}
				| if $api_key_suffix == "" then .
					else
						.customApiKeyResponses = {
							approved: [$api_key_suffix],
							rejected: []
						}
					end
			' >"${state_file}"
	)
}

if [ "${AB_DIND:-}" = "true" ]; then
	check_docker_mounts
	check_docker_cgroupns
	export DOCKER_HOST=unix:///var/run/docker.sock
	unset DOCKER_CONTEXT DOCKER_TLS DOCKER_TLS_VERIFY DOCKER_CERT_PATH DOCKER_API_VERSION DOCKER_TLS_CERTDIR
fi

generate_codex_config
generate_claude_config

if [ "${AB_DIND:-}" = "true" ]; then
	start_dockerd
fi

exec "$@"
