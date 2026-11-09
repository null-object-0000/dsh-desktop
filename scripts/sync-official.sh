#!/usr/bin/env bash
# Follow the official release stream and build Debian packages.
#
# usage:
#   ./scripts/sync-official.sh            # newest official tag + newest stable, if missing
#   ./scripts/sync-official.sh --all      # every official tag that has no build yet (hours)
#   ./scripts/sync-official.sh --latest   # newest official tag only
#
# Every build lands in dist/<tag>/ with the .deb and a manifest.json; the script
# also refreshes dist/index.json, which lists every built version and which
# version currently represents the stable and prerelease channels.
set -euo pipefail

KIT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
UPSTREAM="https://github.com/deepseek-ai/deepseek-harness.git"
MODE="${1:---channels}"

TAGS="$(git ls-remote --tags --refs "$UPSTREAM" 'refs/tags/dsh-v*' \
  | sed 's#.*refs/tags/##' | grep -E '^dsh-v[0-9]' | sort -V)"

newest() {
  printf '%s\n' "$TAGS" | tail -n1
}
newest_stable() {
  printf '%s\n' "$TAGS" | grep -Ev -- '-[0-9A-Za-z.]+$' | tail -n1 || true
}

case "$MODE" in
  --all)
    SELECTED="$TAGS"
    ;;
  --latest)
    SELECTED="$(newest)"
    ;;
  --channels|*)
    SELECTED="$(newest)"
    STABLE="$(newest_stable || true)"
    if [ -n "${STABLE:-}" ] && [ "$STABLE" != "$SELECTED" ]; then
      SELECTED="$(printf '%s\n%s\n' "$SELECTED" "$STABLE" | sort -V)"
    fi
    ;;
esac

for tag in $SELECTED; do
  if [ -f "$KIT/dist/$tag/manifest.json" ]; then
    echo "### skip $tag (already built)"
    continue
  fi
  echo "### build $tag"
  "$KIT/scripts/build-tag.sh" "$tag"
done

# Refresh the version index consumed by the store integration.
DIST="$KIT/dist" node --input-type=module - <<'NODE'
import { readdirSync, readFileSync, writeFileSync, existsSync } from 'node:fs'
import { join } from 'node:path'
const dist = process.env.DIST
const versions = []
for (const entry of readdirSync(dist, { withFileTypes: true })) {
  if (!entry.isDirectory()) continue
  const manifest = join(dist, entry.name, 'manifest.json')
  if (existsSync(manifest)) versions.push(JSON.parse(readFileSync(manifest, 'utf8')))
}
versions.sort((a, b) => a.upstreamTag.localeCompare(b.upstreamTag, undefined, { numeric: true }))
const pick = channel => versions.filter(v => v.channel === channel).at(-1) ?? null
writeFileSync(join(dist, 'index.json'), `${JSON.stringify({
  generatedAt: new Date().toISOString(),
  upstreamRepo: 'https://github.com/deepseek-ai/deepseek-harness',
  channels: { stable: pick('stable'), prerelease: pick('prerelease') },
  versions,
}, undefined, 2)}\n`)
console.log(`index.json: ${versions.length} version(s)`)
NODE
