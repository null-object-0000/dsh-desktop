#!/usr/bin/env bash
# 构建一个官方 DSH tag，产出 Debian 包（以及 electron-builder 顺带产出的 AppImage）。
#
# usage: ./scripts/build-tag.sh dsh-v0.2.2-rc.1
#
# 流程：在 <kit>/src 检出该 tag → 应用 patches/ → pnpm install →
# 上游打包流水线（scripts/linux/package-linux.sh）→ 产物与 manifest.json
# 落到 <kit>/dist/<tag>/。
set -euo pipefail

KIT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TAG="${1:?usage: build-tag.sh <dsh-vX.Y.Z>}"
SRC="$KIT/src"
OUT="$KIT/dist/$TAG"
UPSTREAM="https://github.com/deepseek-ai/deepseek-harness.git"

mkdir -p "$OUT"

echo "### source: $TAG"
if [ -d "$SRC/.git" ]; then
  git -C "$SRC" fetch --depth 1 origin "refs/tags/$TAG:refs/tags/$TAG"
  git -C "$SRC" checkout -f "refs/tags/$TAG"
else
  rm -rf "$SRC"
  git clone --depth 1 --branch "$TAG" "$UPSTREAM" "$SRC"
fi
git -C "$SRC" reset --hard "refs/tags/$TAG"

for patch in "$KIT"/patches/*.patch; do
  [ -e "$patch" ] || continue
  echo "### patch: $(basename "$patch")"
  git -C "$SRC" apply --3way "$patch"
done

echo "### dependencies"
cd "$SRC"
pnpm install --frozen-lockfile --fetch-retries=8 --fetch-timeout=300000 --network-concurrency=4

echo "### packaging"
set +e
bash "$SRC/scripts/linux/package-linux.sh" 2>&1 | tee "$OUT/build.log"
PACKAGE_EXIT=${PIPESTATUS[0]}
set -e
if [ "$PACKAGE_EXIT" -ne 0 ]; then
  echo "package-linux.sh failed: see $OUT/build.log" >&2
  exit "$PACKAGE_EXIT"
fi

ARTIFACTS="$SRC/apps/desktop/.desktop-build/targets/linux-x64/unsigned-artifacts"
DEB="$(ls -1 "$ARTIFACTS"/*.deb 2>/dev/null | head -n1 || true)"
if [ -z "$DEB" ]; then
  echo "no .deb produced in $ARTIFACTS" >&2
  exit 1
fi
cp -f "$DEB" "$OUT/"
APPIMAGE="$(ls -1 "$ARTIFACTS"/*.AppImage 2>/dev/null | head -n1 || true)"
if [ -n "$APPIMAGE" ]; then cp -f "$APPIMAGE" "$OUT/"; fi

VERSION="${TAG#dsh-v}"
CHANNEL="stable"
case "$VERSION" in
  *-*) CHANNEL="prerelease" ;;
esac

MANIFEST="$OUT/manifest.json" OUT="$OUT" TAG="$TAG" VERSION="$VERSION" CHANNEL="$CHANNEL" \
APPIMAGE_PRESENT="${APPIMAGE:+1}" node --input-type=module - <<'NODE'
import { createHash } from 'node:crypto'
import { readFileSync, readdirSync, writeFileSync } from 'node:fs'
import { execFileSync } from 'node:child_process'
import { join } from 'node:path'
const env = process.env
const dir = env.OUT
const debName = readdirSync(dir).find(name => name.endsWith('.deb'))
const debPath = join(dir, debName)
const deb = readFileSync(debPath)
const field = name => execFileSync('dpkg-deb', ['-f', debPath, name], { encoding: 'utf8' }).trim()
const artifacts = [{
  kind: 'deb', file: debName, size: deb.length, sha256: createHash('sha256').update(deb).digest('hex'),
}]
if (env.APPIMAGE_PRESENT === '1') {
  const appImageName = readdirSync(dir).find(name => name.endsWith('.AppImage'))
  const appImage = readFileSync(join(dir, appImageName))
  artifacts.push({ kind: 'AppImage', file: appImageName, size: appImage.length,
    sha256: createHash('sha256').update(appImage).digest('hex') })
}
writeFileSync(env.MANIFEST, `${JSON.stringify({
  appId: 'deepseek-harness-desktop',
  upstreamTag: env.TAG,
  upstreamRepo: 'https://github.com/deepseek-ai/deepseek-harness',
  version: env.VERSION,
  channel: env.CHANNEL,
  packageName: field('Package'),
  packageVersion: field('Version'),
  architecture: field('Architecture'),
  artifacts,
  upstreamCommit: execFileSync('git', ['-C', join(env.OUT, '..', '..', 'src'), 'rev-parse', 'HEAD'], { encoding: 'utf8' }).trim(),
  builtAt: new Date().toISOString(),
}, undefined, 2)}\n`)
NODE

echo "### built"
cat "$OUT/manifest.json"
