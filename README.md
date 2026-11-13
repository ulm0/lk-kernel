# lk-kernel

Minimal [LinuxKit](https://github.com/linuxkit/linuxkit) kernels, one flavor per project, built from LinuxKit's own
kernel packaging but with a config written from `allnoconfig` up instead of LinuxKit's.

| Flavor | Used by | Architectures |
|---|---|---|
| `natkit` | [natkit](https://github.com/ulm0/natkit): NAT instance AMI (EC2) | arm64, amd64 |
| `yagan` | [yagan](https://github.com/ulm0/yagan): k3s AMI (EC2 Graviton) | arm64 |
| `limakit` | [limakit](https://github.com/ulm0/limakit): Lima VM image | arm64 |

## Images

```
ghcr.io/ulm0/lk-kernel/<flavor>:<version>             moves to each main build of that version
ghcr.io/ulm0/lk-kernel/<flavor>:<version>-<hash>      one build: <hash> covers build.sh and the flavor's configs
ghcr.io/ulm0/lk-kernel/<flavor>:<version>-<hash>-<arch>
```

Each is a LinuxKit kernel image (`kernel`, `kernel.tar`, `kernel-dev.tar` with the headers for out-of-tree modules).
Reference it from a LinuxKit YAML pinned by digest, so a rebuild here only reaches a project through a PR there
(Renovate's docker datasource updates the digest):

```yaml
kernel:
  image: ghcr.io/ulm0/lk-kernel/natkit:6.18.62@sha256:...
```

## Flavors

`flavors/<flavor>/<flavor>.config` is the complete option list over `make allnoconfig`; anything not listed stays
off (or takes its Kconfig default if it only becomes visible through a listed option). An optional
`<flavor>-<uname -m>.config` (`aarch64`, `x86_64`) adds per-architecture options. `build.sh` fails if an option
doesn't end up in the final config as written (an unmet dependency would otherwise drop it silently). Put comments
on their own lines: a trailing one would be read into the value.

A new flavor: add its directory, then a `kernel` matrix entry per architecture and a `manifest` entry in
`.github/workflows/build.yml`.

## Building

```sh
make natkit     # ghcr.io/ulm0/lk-kernel/natkit:$(cat VERSION), for the docker daemon's architecture; 15-25 min
```

The version is in `VERSION` (Renovate bumps it); every flavor builds the same one. A version whose series LinuxKit
doesn't package yet borrows the newest series' packaging; review the resolved config (`flavors/<flavor>/config-*`,
also a CI artifact) after that.

## License

MIT.
