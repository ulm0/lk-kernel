# lk-kernel

One minimal [LinuxKit](https://github.com/linuxkit/linuxkit) kernel, arm64 and amd64, for
[natkit](https://github.com/ulm0/natkit) (EC2 NAT instance), [yagan](https://github.com/ulm0/yagan) (EC2 k3s) and
[limakit](https://github.com/ulm0/limakit) (Lima VM). Built with LinuxKit's own kernel packaging, but from a config
written from `allnoconfig` up instead of LinuxKit's.

## Image

```
ghcr.io/ulm0/lk-kernel:<version>                  multi-arch; moves to each main build of that version
ghcr.io/ulm0/lk-kernel:<version>-<hash>           one build: <hash> covers build.sh and config/
ghcr.io/ulm0/lk-kernel:<version>-<hash>-<arch>
```

A LinuxKit kernel image (`kernel`, `kernel.tar`, and `kernel-dev.tar` with the headers for out-of-tree modules, such as
natkit's Jool). Pin it by digest in a LinuxKit YAML, so a rebuild here only reaches a project through a PR there
(Renovate's docker datasource updates the digest):

```yaml
kernel:
  image: ghcr.io/ulm0/lk-kernel:6.18.62@sha256:...
```

## Config

`config/lk.config` is the complete option list over `make allnoconfig`, and `config/lk-<uname -m>.config`
(`aarch64`, `x86_64`) adds per-architecture options. Anything not listed stays off, or takes its Kconfig default if
it only becomes visible through a listed option. Sections say which project needed an option first; every project
gets all of them. `build.sh` fails if an option doesn't end up in the final config as written (an unmet dependency
would otherwise drop it silently). Put comments on their own lines: a trailing one would be read into the value.

## Building

```sh
make            # ghcr.io/ulm0/lk-kernel:$(cat VERSION), for the docker daemon's architecture; 15-25 min
```

The version is in `VERSION` (Renovate bumps it). A version whose series LinuxKit doesn't package yet borrows the
newest series' packaging; review the resolved config (`config/config-*`, also a CI artifact) after that.

## License

MIT.
