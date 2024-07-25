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

.PHONY: gen-golden
gen-golden:
	@rm -f tests/golden/$(instance).yml
	$(JSONNET_DOCKER) tests/run-instance.sh $(instance).env > tests/golden/$(instance).yml

.PHONY: golden-diff
golden-diff:
	@mkdir -p /tmp/commodore-compile-pipelines
	$(JSONNET_DOCKER) tests/run-instance.sh $(instance).env > /tmp/commodore-compile-pipelines/$(instance).yml
	@git diff --exit-code --minimal --no-index -- tests/golden/$(instance).yml /tmp/commodore-compile-pipelines/$(instance).yml

.PHONY: golden-diff-all
golden-diff-all: recursive_target=golden-diff
golden-diff-all: $(test_instances)

.PHONY: gen-golden-all
gen-golden-all: recursive_target=gen-golden
gen-golden-all: $(test_instances)

.PHONY: $(test_instances)
$(test_instances):
	$(MAKE) $(recursive_target) -e instance=$(basename $(@F))
