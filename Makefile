IMAGE ?= agentbox
TAG ?= v1
PLATFORM ?= linux/amd64
SUPPORTED_PLATFORM := linux/amd64
IMAGE_REF := $(IMAGE):$(TAG)
WORKSPACE_DIR ?= work
SMOKE_SCRIPT := scripts/smoke.sh
SMOKE_SCRIPT_CONTAINER := /usr/local/share/agentbox-smoke.sh
BUILD_ARGS ?=
BUILD_NETWORK ?=
ifdef BUILD_NETWORK
BUILD_NETWORK_ARG := --network $(BUILD_NETWORK)
endif
ifdef http_proxy
BUILD_ARGS += --build-arg http_proxy=$(http_proxy)
endif
ifdef https_proxy
BUILD_ARGS += --build-arg https_proxy=$(https_proxy)
endif
ifdef HTTP_PROXY
BUILD_ARGS += --build-arg HTTP_PROXY=$(HTTP_PROXY)
endif
ifdef HTTPS_PROXY
BUILD_ARGS += --build-arg HTTPS_PROXY=$(HTTPS_PROXY)
endif

.PHONY: build refresh shell dind-shell smoke dind-smoke test help check-platform release-build
.NOTPARALLEL: test

.DEFAULT_GOAL := help

check-platform:
	@if [ "$(PLATFORM)" != "$(SUPPORTED_PLATFORM)" ]; then \
		printf '%s\n' "unsupported PLATFORM=$(PLATFORM); only $(SUPPORTED_PLATFORM) is supported" >&2; \
		exit 1; \
	fi

build: check-platform
	docker buildx build --pull --platform $(PLATFORM) $(BUILD_NETWORK_ARG) $(BUILD_ARGS) -t $(IMAGE_REF) --load .

refresh: check-platform
	docker buildx build --pull --no-cache --platform $(PLATFORM) $(BUILD_NETWORK_ARG) $(BUILD_ARGS) -t $(IMAGE_REF) --load .

release-build: check-platform
	IMAGE='$(IMAGE)' PLATFORM='$(PLATFORM)' BUILD_NETWORK='$(BUILD_NETWORK)' \
	http_proxy='$(http_proxy)' https_proxy='$(https_proxy)' \
	HTTP_PROXY='$(HTTP_PROXY)' HTTPS_PROXY='$(HTTPS_PROXY)' \
	scripts/release-build.sh

shell dind-shell: check-platform
	@set --; \
	if [ '$@' = 'dind-shell' ]; then \
		set -- --privileged --cgroupns=private -e AB_DIND=true; \
	fi; \
	workspace_dir='$(WORKSPACE_DIR)'; \
	case "$$workspace_dir" in \
		/*) workspace_host_dir="$$workspace_dir" ;; \
		*) workspace_host_dir="$$PWD/$$workspace_dir" ;; \
	esac; \
	if [ ! -e "$$workspace_host_dir" ]; then \
		if [ "$$workspace_dir" = "work" ]; then \
			mkdir -p "$$workspace_host_dir"; \
			chmod 0777 "$$workspace_host_dir"; \
		else \
			printf '%s\n' "WORKSPACE_DIR does not exist: $$workspace_host_dir" >&2; \
			exit 1; \
		fi; \
	elif [ ! -d "$$workspace_host_dir" ]; then \
		printf '%s\n' "WORKSPACE_DIR must be a directory: $$workspace_host_dir" >&2; \
		exit 1; \
	fi; \
	docker run --rm -it --platform $(PLATFORM) "$$@" -v "$$workspace_host_dir:/workspace" -w /workspace $(IMAGE_REF)

smoke: check-platform
	@set -eu; \
	tmpdir="$$(mktemp -d)"; \
	trap 'rm -rf "$$tmpdir"' EXIT INT TERM; \
	chmod 0777 "$$tmpdir"; \
	docker run --rm --network none --hostname localhost --platform $(PLATFORM) \
		-v "$$tmpdir:/workspace" \
		-v "$$PWD/$(SMOKE_SCRIPT):$(SMOKE_SCRIPT_CONTAINER):ro" \
		-w /workspace \
		$(IMAGE_REF) \
		bash $(SMOKE_SCRIPT_CONTAINER); \
	test -s "$$tmpdir/.agentbox-smoke-write-ok"

dind-smoke: check-platform
	IMAGE_REF='$(IMAGE_REF)' PLATFORM='$(PLATFORM)' bash scripts/smoke-host.sh

test: build smoke

help:
	@printf '%s\n' \
		'Targets:' \
		'  build     Build and load $(IMAGE_REF) for $(PLATFORM); pulls the base image and may reuse Docker layer cache.' \
		'  refresh   Build and load $(IMAGE_REF) with --pull --no-cache for rolling upstream refresh.' \
		'  release-build  Build and load IMAGE:<latest-reachable-git-tag>-<UTC-date> from the current checkout'\''s latest reachable git tag snapshot.' \
		'  shell     Start an interactive container with WORKSPACE_DIR mounted at /workspace.' \
		'            Only missing default ./work is auto-created and chmodded 0777; custom workspaces must already exist as directories.' \
		'  dind-shell  Start a privileged interactive container with an internal dockerd.' \
		'  smoke     Run a lightweight core runtime sanity gate.' \
		'  dind-smoke  Run the DinD-only smoke gate in a privileged container.' \
		'  test      Build $(IMAGE_REF), then run smoke.' \
		'  help      Show this help.' \
		'' \
		'Variables:' \
		'  IMAGE             Image name. Default: $(IMAGE)' \
		'  TAG               Image tag. Default: $(TAG)' \
		'  PLATFORM          Target platform. Only $(SUPPORTED_PLATFORM) is supported; other values fail before Docker.' \
		'  WORKSPACE_DIR     Host workspace for shell and dind-shell. Default: $(WORKSPACE_DIR)' \
		'  BUILD_NETWORK     Optional docker build network mode.' \
		'  http_proxy        Optional build-time proxy input.' \
		'  https_proxy       Optional build-time proxy input.' \
		'  HTTP_PROXY        Optional build-time proxy input.' \
		'  HTTPS_PROXY       Optional build-time proxy input.'
