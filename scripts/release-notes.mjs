/** Render release notes from a build manifest produced by scripts/build-tag.sh. */
import { readFileSync } from 'node:fs'

const manifestPath = process.argv[2]
if (!manifestPath) throw new Error('usage: release-notes.mjs <manifest.json>')
const manifest = JSON.parse(readFileSync(manifestPath, 'utf8'))

const lines = [
  `Unofficial Linux build of DeepSeek Harness Desktop, built from upstream tag \`${manifest.upstreamTag}\`.`,
  '',
  `- package: \`${manifest.packageName} ${manifest.packageVersion}\` (${manifest.architecture})`,
  `- channel: ${manifest.channel}`,
  `- upstream commit: \`${manifest.upstreamCommit}\``,
  '',
  'Artifacts:',
  ...manifest.artifacts.map(artifact =>
    `- \`${artifact.file}\` — ${(artifact.size / 1024 / 1024).toFixed(1)} MB, sha256 \`${artifact.sha256}\``),
  '',
  'Image decoding is handled by a bundled standalone Node child process '
  + '(sharp/libvips segfaults inside Electron\'s Node runtime on Linux); '
  + 'pasting and uploading images is verified by CI for every build.',
  '',
  'Unofficial community packaging; upstream Desktop does not publish Linux builds.',
]
process.stdout.write(`${lines.join('\n')}\n`)
