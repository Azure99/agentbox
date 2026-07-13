#!/usr/bin/env bash
set -euo pipefail

image_ref="${IMAGE_REF:?IMAGE_REF is required}"
platform="${PLATFORM:?PLATFORM is required}"
docker_run_args=(--network none --hostname localhost --cgroupns private --platform "${platform}")
tmpdir="$(mktemp -d)"
signal_container=""

cleanup() {
	if [ -n "${signal_container}" ]; then
		docker rm -fv "${signal_container}" >/dev/null 2>&1 || :
	fi
	rm -rf "${tmpdir}"
}

trap cleanup EXIT

fail() {
	printf '%s\n' "$*" >&2
	exit 1
}

run_smoke_script() {
	docker run --rm "${docker_run_args[@]}" "$@" \
		-v "${PWD}/scripts/smoke.sh:/usr/local/share/agentbox-smoke.sh:ro" \
		"${image_ref}" \
		bash /usr/local/share/agentbox-smoke.sh
}

expect_rejection() {
	local expected="$1"
	local output

	shift
	if output="$(docker run --rm "${docker_run_args[@]}" "$@" "${image_ref}" true 2>&1)"; then
		fail "expected agentbox to reject: ${expected}"
	fi
	case "${output}" in
	*"${expected}"*) ;;
	*)
		printf '%s\n' "${output}" >&2
		fail "expected rejection output to contain: ${expected}"
		;;
	esac
}

run_smoke_script --privileged -e AB_DIND=true -e AB_SMOKE_DIND_ONLY=true

expect_rejection "DinD requires a private cgroup namespace" \
	--cgroupns=host \
	-e AB_DIND=true

root_status=0
docker run --rm --privileged "${docker_run_args[@]}" --user root \
	-e AB_DIND=true \
	"${image_ref}" \
	sh -c 'docker info >/dev/null && exit 42' || root_status="$?"
if [ "${root_status}" -ne 42 ]; then
	fail "expected DinD root command to exit 42; got ${root_status}"
fi

signal_dir="${tmpdir}/signal"
mkdir "${signal_dir}"
chmod 0777 "${signal_dir}"
signal_container="agentbox-smoke-signal-${BASHPID}-${RANDOM}"
docker run -dit --privileged "${docker_run_args[@]}" \
	--name "${signal_container}" \
	-e AB_DIND=true \
	-v "${signal_dir}:/probe" \
	"${image_ref}" \
	bash -i -c "trap 'printf \"%s\\n\" term >/probe/term; exit 0' TERM; printf '%s\n' ready >/probe/ready; while :; do sleep 1; done" \
	>/dev/null
for _ in {1..60}; do
	if [ -s "${signal_dir}/ready" ]; then
		break
	fi
	sleep 1
done
if [ ! -s "${signal_dir}/ready" ]; then
	docker logs "${signal_container}" >&2
	fail "timed out waiting for the signal smoke payload"
fi
docker stop --time 5 "${signal_container}" >/dev/null
if [ ! -s "${signal_dir}/term" ]; then
	docker logs "${signal_container}" >&2
	fail "DinD payload did not receive SIGTERM"
fi
docker rm -v "${signal_container}" >/dev/null
signal_container=""

socket_file="${tmpdir}/docker.sock"
touch "${socket_file}"
docker run --rm "${docker_run_args[@]}" \
	-v "${socket_file}:/var/run/docker.sock" \
	"${image_ref}" true
expect_rejection "mounting host Docker runtime paths is not supported" \
	--privileged \
	-e AB_DIND=true \
	-v "${socket_file}:/var/run/docker.sock"

run_dir="${tmpdir}/run"
mkdir "${run_dir}"
touch "${run_dir}/docker.sock"
expect_rejection "mounting host Docker runtime paths is not supported" \
	--privileged \
	-e AB_DIND=true \
	-v "${run_dir}:/var/run"
