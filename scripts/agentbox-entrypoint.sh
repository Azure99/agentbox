#!/bin/bash
set -euo pipefail

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

generate_codex_config
generate_claude_config
exec "$@"
