FROM dockerhub.vshn.net/library/alpine:latest

RUN apk add --no-cache yamllint jsonnet jq curl
COPY ./bin/* /usr/local/bin/
COPY ./commodore-compile.jsonnet /opt/commodore-compile.jsonnet
