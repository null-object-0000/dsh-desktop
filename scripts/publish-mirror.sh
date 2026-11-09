#!/usr/bin/env bash
# 把已构建的版本发布到 GitHub Release 镜像仓库，供 UManager 的 releaseApi 读取。
#
# usage:
#   export MIRROR_REPO=owner/repo
#   ./scripts/publish-mirror.sh dsh-v0.2.2-rc.1
#
# 前置：本机已 `gh auth login`；镜像仓库已存在；该 tag 尚未发布。
# 资产名保持 electron-builder 的原始文件名（不要改名），UManager 的
# assetNamePattern 依赖它。
set -euo pipefail

KIT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TAG="${1:?usage: publish-mirror.sh <dsh-vX.Y.Z>}"
: "${MIRROR_REPO:?set MIRROR_REPO=owner/repo for the mirror repository}"
DIR="$KIT/dist/$TAG"
[ -f "$DIR/manifest.json" ] || { echo "no build for $TAG in $DIR" >&2; exit 1; }

VERSION="${TAG#dsh-v}"
NOTES="$(node --input-type=module -e "
import { readFileSync } from 'node:fs'
const m = JSON.parse(readFileSync('$DIR/manifest.json','utf8'))
const lines = m.artifacts.map(a => '- ' + a.file + ' — sha256 ' + a.sha256)
console.log(['Built from upstream tag ' + m.upstreamTag + ' (commit ' + m.upstreamCommit + ').', '', ...lines].join('\n'))
")"

ARGS=()
for f in "$DIR"/*.deb "$DIR"/*.AppImage; do
  [ -e "$f" ] && ARGS+=("$f")
done
[ "${#ARGS[@]}" -gt 0 ] || { echo "no artifacts in $DIR" >&2; exit 1; }

PRERELEASE=()
case "$VERSION" in *-*) PRERELEASE+=(--prerelease) ;; esac

gh release create "$TAG" "${ARGS[@]}" \
  --repo "$MIRROR_REPO" \
  --title "DeepSeek Harness $VERSION (Linux)" \
  --notes "$NOTES" \
  "${PRERELEASE[@]}"

echo "published $TAG to $MIRROR_REPO"
