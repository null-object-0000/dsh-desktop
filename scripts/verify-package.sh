#!/usr/bin/env bash
# Verify that the packaged application decodes images through the bundled
# standalone Node process and that ASAR layout is complete.
#
# usage: ./scripts/verify-package.sh <upstream-tag>
set -euo pipefail

KIT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TAG="${1:?usage: verify-package.sh <dsh-vX.Y.Z>}"
DIR="$KIT/dist/$TAG"
DEB="$(ls -1 "$DIR"/*.deb 2>/dev/null | head -n1 || true)"
[ -n "$DEB" ] || { echo "no .deb in $DIR" >&2; exit 1; }

WORK="${TMPDIR:-/tmp}/dsh-verify-$TAG"
rm -rf "$WORK"
mkdir -p "$WORK/root" "$WORK/home"
dpkg-deb -x "$DEB" "$WORK/root"

APP_ROOT="$WORK/root/opt/DeepSeek Harness"
ASAR="$APP_ROOT/resources/app.asar"
NODE24="$APP_ROOT/resources/runtime/primary-runtime/dependencies/node/bin/node"
BIN="$APP_ROOT/deepseek-harness"
for path in "$BIN" "$ASAR" "$NODE24"; do
  [ -e "$path" ] || { echo "missing packaged path: $path" >&2; exit 1; }
done

echo "### verifying image decode bridge in the packaged ASAR layout"
ELECTRON_RUN_AS_NODE=1 \
ASAR_ROOT="$ASAR" \
DSH_HOME="$WORK/home" \
DSH_DESKTOP_PRIMARY_RUNTIME_NODE="$NODE24" \
"$BIN" --expose-internals scripts/ci/verify-image-decode.mjs

echo "### image decode verification passed"
