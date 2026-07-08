#!/usr/bin/env bash
set -euo pipefail

fail() {
  printf '%s\n' "$*" >&2
  exit 1
}

image="${IMAGE:-agentbox}"
platform="${PLATFORM:-linux/amd64}"

if [ "${platform}" != "linux/amd64" ]; then
  fail "unsupported PLATFORM=${platform}; only linux/amd64 is supported"
fi

if ! git_tag="$(git describe --tags --abbrev=0 2>/dev/null)"; then
  fail "no git tags found; create a release tag first"
fi

date_utc="$(date -u +%Y%m%d)"
release_tag="${git_tag}-${date_utc}"

if [ "${#release_tag}" -gt 128 ] || ! [[ "${release_tag}" =~ ^[A-Za-z0-9_][A-Za-z0-9_.-]*$ ]]; then
  fail "git tag produces invalid Docker tag '${release_tag}'; use only [A-Za-z0-9_.-], start with [A-Za-z0-9_], and keep the tag component at 128 characters or less"
fi

image_ref="${image}:${release_tag}"
tmpdir="$(mktemp -d)"
trap 'rm -rf "${tmpdir}"' EXIT INT TERM

build_args=()
if [ -n "${BUILD_NETWORK:-}" ]; then
  build_args+=(--network "${BUILD_NETWORK}")
fi

for proxy_name in http_proxy https_proxy HTTP_PROXY HTTPS_PROXY; do
  if [ -n "${!proxy_name:-}" ]; then
    build_args+=(--build-arg "${proxy_name}=${!proxy_name}")
  fi
done

git archive "${git_tag}" | tar -x -C "${tmpdir}"

docker buildx build \
  --pull \
  --platform "${platform}" \
  "${build_args[@]}" \
  -t "${image_ref}" \
  --load \
  "${tmpdir}"

printf '%s\n' "built ${image_ref} from git tag ${git_tag}"
