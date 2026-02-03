#!/bin/bash

set -e -u -x

testdir=$(dirname "$0")
env="${testdir}/${1}"

# shellcheck source=/dev/null
source "${env}"

jsonnet --ext-str clusters="$CLUSTERS" \
  --ext-str cluster_catalog_urls="$CLUSTER_CATALOG_URLS" \
  --ext-str server_fqdn="git.vshn.net:80" \
  --ext-str server_ssh_host="git.vshn.net" \
  --ext-str server_ssh_port="" \
  --ext-str memory_limits="${MEMORY_LIMITS:-}" \
  --ext-str cpu_limits="${CPU_LIMITS:-}" \
  --ext-str cpu_requests="${CPU_REQUESTS:-}" \
  commodore-compile.jsonnet
