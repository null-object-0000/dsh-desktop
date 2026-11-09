#!/usr/bin/env bash
# Package DeepSeek Harness Desktop as a Linux .deb (unsigned, upstream source tree).
set -euo pipefail

ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)
DESKTOP="$ROOT/apps/desktop"
TARGET_ROOT="$DESKTOP/.desktop-build/targets/linux-x64"
PACKED="$TARGET_ROOT/packed"

export DSH_DESKTOP_TARGET_PLATFORM=linux
export DSH_DESKTOP_TARGET_ARCH=x64
export DSH_DESKTOP_UNSIGNED=1
export DSH_DESKTOP_APP_ID=com.deepseek.harness
export CSC_IDENTITY_AUTO_DISCOVERY=false
export DSH_GATE_CONCURRENCY=${DSH_GATE_CONCURRENCY:-2}
export NODE_OPTIONS=${NODE_OPTIONS:---max-old-space-size=3072}
export ELECTRON_MIRROR=${ELECTRON_MIRROR:-https://npmmirror.com/mirrors/electron/}
export DSH_DESKTOP_BUILD_COMMIT=$(git -C "$ROOT" rev-parse HEAD)
if [ -n "$(git -C "$ROOT" status --porcelain)" ]; then export DSH_DESKTOP_BUILD_DIRTY=true; else export DSH_DESKTOP_BUILD_DIRTY=false; fi

step() { echo; echo "### $*"; }

step "build: artifacts (profile local)"
cd "$ROOT"
pnpm exec tsx scripts/build.ts --scope artifacts --profile local --serial

step "prepare: packed inputs"
rm -rf "$PACKED"
mkdir -p "$PACKED/dsh" "$PACKED/vendor" "$PACKED/landlock"
pnpm exec tsx apps/desktop/scripts/pack-local-packages.ts --out "$PACKED/dsh" --concurrency 2
pnpm --dir apps/desktop-host pack --pack-destination "$PACKED/dsh"
pnpm run release:pack --family vendor --out "$PACKED/vendor" --concurrency 2
pnpm --dir native/system run build:ts
pnpm --dir native/system/packages/entry pack --pack-destination "$PACKED/landlock"

cd "$DESKTOP"
step "prepare:runtime (electron + primary runtime + cli)"
pnpm run prepare:runtime

step "prepare:packages"
pnpm run prepare:packages

step "prepare:dsh"
pnpm run prepare:dsh

step "electron-builder (linux deb)"
pnpm exec electron-builder --config electron-builder.config.mjs --linux --x64 --publish never

echo
echo "### artifacts"
ls -la "$TARGET_ROOT/unsigned-artifacts" || true
