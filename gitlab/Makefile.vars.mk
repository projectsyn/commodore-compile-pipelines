ifneq "$(shell which docker 2>/dev/null)" ""
	DOCKER_CMD    ?= $(shell which docker)
	DOCKER_USERNS ?= ""
else
	DOCKER_CMD    ?= podman
	DOCKER_USERNS ?= keep-id
endif
DOCKER_ARGS ?= run --rm -u "$$(id -u):$$(id -g)" --userns=$(DOCKER_USERNS) -w /work -e HOME="/work"

JSONNET_IMAGE      ?= docker.io/bitnami/jsonnet:latest
JSONNET_ENTRYPOINT ?= bash
JSONNET_DOCKER     ?= $(DOCKER_CMD) $(DOCKER_ARGS) -v "$${PWD}:/work" --entrypoint=$(JSONNET_ENTRYPOINT) $(JSONNET_IMAGE)
