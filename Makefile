# make: ghcr.io/ulm0/lk-kernel:<VERSION>, built for the docker daemon's architecture (build.sh)
export DOCKER_HOST ?= $(shell docker context inspect --format "{{.Endpoints.docker.Host}}")
# linuxkit master: no release since v1.8.2 (2025-09). Built from source; the ref is in the file name so
# bumping it rebuilds.
LINUXKIT_REF := 0e34a007431a3a3c19a03fc6bca00fba51774706 # 2026-10-27
LK := bin/linuxkit-$(shell echo $(LINUXKIT_REF) | cut -c1-12)
GOLANG := golang:1.27-alpine@sha256:eb61c3873c97416fff0116553fff65d67a3549f72e11d9758849a689cdd8b523
IMAGE := ghcr.io/ulm0/lk-kernel
VERSION := $(shell cat VERSION)

.PHONY: kernel clean
kernel: | $(LK)
	LINUXKIT=$(LK) ./build.sh $(VERSION)
	docker tag linuxkit/kernel:$(VERSION)-lk $(IMAGE):$(VERSION)

$(LK):
	mkdir -p bin
	curl -fsSL https://codeload.github.com/linuxkit/linuxkit/tar.gz/$(LINUXKIT_REF) | docker run --rm -i \
		-e CGO_ENABLED=0 -e GOOS=$$(uname -s | tr A-Z a-z) -e GOARCH=$$(uname -m | sed 's/x86_64/amd64/;s/aarch64/arm64/') \
		$(GOLANG) sh -c 'mkdir /s && cd /s && tar xz --strip-components=1 && cd src/cmd/linuxkit && \
		go build -trimpath -ldflags "-s -w -X github.com/linuxkit/linuxkit/src/cmd/linuxkit/version.GitCommit=$(LINUXKIT_REF) \
		-X github.com/linuxkit/linuxkit/src/cmd/linuxkit/version.Version=master" -o /lk . >&2 && cat /lk' >$@.tmp
	chmod +x $@.tmp && mv $@.tmp $@

clean:
	rm -rf bin .build config/config-*
