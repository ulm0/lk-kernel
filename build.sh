#!/bin/sh
# Build linuxkit/kernel:<version>-lk for the docker daemon's architecture from LinuxKit's kernel packaging and
# config/lk.config + config/lk-<uname -m>.config: a complete option list over allnoconfig; LinuxKit's own config is
# not used. The resolved config is left in config/config-<uname -m>.
#
#   ./build.sh [KERNEL_VERSION]        the version defaults to the VERSION file
#
# A version whose series LinuxKit doesn't package yet borrows the newest series' packaging (Dockerfile,
# build-args); olddefconfig gives new options their defaults. Review the resolved config after that.
# Needs docker and LINUXKIT (default bin/linuxkit, see the Makefile); 15-25 min.
set -eu

DIR=$(cd "$(dirname "$0")" && pwd)
F=$DIR/config
KERNEL_VERSION=${1:-$(cat "$DIR/VERSION")}
LINUXKIT_REF=${LINUXKIT_REF:-f3906d1f6650f79d74adf3cba42b04ca9e21ea7d} # linuxkit/linuxkit master, 2026-10-15
LINUXKIT=$(cd "$(dirname "${LINUXKIT:-bin/linuxkit}")" && pwd)/$(basename "${LINUXKIT:-bin/linuxkit}")
SERIES=$(echo "$KERNEL_VERSION" | cut -d. -f1-2).x
SRC=$DIR/.build/linuxkit
case $(docker version -f '{{.Server.Arch}}') in
arm64 | aarch64) PLATFORM=linux/arm64 KARCH=arm64 UNAME=aarch64 ;;
amd64 | x86_64) PLATFORM=linux/amd64 KARCH=x86_64 UNAME=x86_64 ;;
*) echo "unsupported docker server arch" >&2 && exit 1 ;;
esac

# 1. LinuxKit's kernel packaging at a pinned commit
if [ ! -d "$SRC/.git" ]; then
	git clone -q https://github.com/linuxkit/linuxkit.git "$SRC"
fi
git -C "$SRC" fetch -q --depth 1 origin "$LINUXKIT_REF"
git -C "$SRC" checkout -q --force "$LINUXKIT_REF"
K=$SRC/kernel

# 2. series dir; for a series LinuxKit doesn't have, copy the newest one
if [ ! -d "$K/$SERIES" ]; then
	BASE=$(cd "$K" && printf '%s\n' [0-9]*.x | grep -v -- -rt | sort -V | tail -n 1)
	echo "LinuxKit has no $SERIES; starting from $BASE"
	cp -R "$K/$BASE" "$K/$SERIES"
	rm -rf "$K/$SERIES/patches" # patches are series-specific
fi
sed -i.bak -e "s/^KERNEL_VERSION=.*/KERNEL_VERSION=$KERNEL_VERSION/" -e "s/^KERNEL_SERIES=.*/KERNEL_SERIES=$SERIES/" "$K/$SERIES/build-args"
rm -f "$K/$SERIES/build-args.bak"

# 3. allnoconfig + lk.config + lk-<arch>.config, normalized with olddefconfig (LinuxKit's build rejects a config that
#    isn't), in LinuxKit's own builder image: the config records the compiler and pahole versions
BUILD_IMAGE=$(sed -n 's/^BUILD_IMAGE=//p' "$K/$SERIES/build-args")
# BTF (CONFIG_DEBUG_INFO_BTF, e.g. Cilium's) needs pahole, and python3 for resolve_btfids' libbpf headers; neither
# is in the builder's package mirror: take them from Alpine. Unused by a config without BTF.
PAHOLE='v=v$(cut -d. -f1,2 /etc/alpine-release) && apk add -q --repository https://dl-cdn.alpinelinux.org/alpine/$v/main --repository https://dl-cdn.alpinelinux.org/alpine/$v/community pahole python3'
grep -q pahole "$K/common/Dockerfile" ||
	awk -v run="RUN $PAHOLE" '{print} /^    zlib-dev$/ && !done {print run; done=1}' "$K/common/Dockerfile" >"$K/common/Dockerfile.new" &&
	mv "$K/common/Dockerfile.new" "$K/common/Dockerfile"
docker run --rm --platform "$PLATFORM" -v "$F:/f" "$BUILD_IMAGE" sh -euc "
	apk add -q bash build-base bc bison flex perl linux-headers openssl-dev elfutils-dev curl xz >/dev/null
	$PAHOLE >/dev/null
	cd /tmp && curl -fsSL https://cdn.kernel.org/pub/linux/kernel/v${KERNEL_VERSION%%.*}.x/linux-$KERNEL_VERSION.tar.xz | tar xJ
	cd linux-$KERNEL_VERSION && make ARCH=$KARCH allnoconfig >/dev/null
	cat /f/lk.config /f/lk-$UNAME.config | grep '^CONFIG_' >/tmp/want
	while IFS== read -r o v; do scripts/config --set-val \"\${o#CONFIG_}\" \"\$v\"; done </tmp/want
	# plain make (the native ARCH: x86, not x86_64): LinuxKit's build diffs the config's header line too
	make olddefconfig >/dev/null
	# a select/depends chain that isn't met silently drops an option: fail instead
	# (=n also holds when the symbol is absent: its menu is off)
	while read -r l; do
		case \"\$l\" in
		*=n) ! grep -q \"^\${l%=n}=\" .config ;;
		*) grep -qx \"\$l\" .config ;;
		esac || { echo \"not applied: \$l\"; exit 1; }
	done </tmp/want
	cp .config /f/config-$UNAME"
cp "$F/config-$UNAME" "$K/$SERIES/config-$UNAME"

# 4. build with LinuxKit's own kernel packaging (same as kernel/Makefile buildplainkernel-%)
(cd "$K" && "$LINUXKIT" pkg build . --docker --force --force-dirty --platforms "$PLATFORM" \
	--build-yml ./common/build-kernel.yml --hash lk --tag "$KERNEL_VERSION-{{.Hash}}" \
	--build-arg-file "$SERIES/build-args" --progress plain)
echo "built linuxkit/kernel:$KERNEL_VERSION-lk ($PLATFORM)"
