MAKEFLAGS += --warn-undefined-variables
SHELL := bash
.SHELLFLAGS := -eu -o pipefail -c

include Makefile.vars.mk

.PHONY: jsonnetfmt_check jsonnetfmt
jsonnetfmt_check: JSONNET_ENTRYPOINT=jsonnetfmt
jsonnetfmt_check:
	$(JSONNET_DOCKER) --test --pad-arrays -- *.jsonnet

jsonnetfmt: JSONNET_ENTRYPOINT=jsonnetfmt
jsonnetfmt:
	$(JSONNET_DOCKER) --in-place --pad-arrays -- *.jsonnet
