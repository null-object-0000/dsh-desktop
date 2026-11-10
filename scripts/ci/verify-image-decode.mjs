/** CI regression check: the packaged app decodes and re-encodes images.
 *
 * Runs inside Electron's Node mode against the extracted deb (ASAR layout), so
 * it exercises the same standalone-Node image bridge the Host uses. A SIGSEGV
 * or a missing ASAR-unpacked sharp closure fails the build.
 */
import { crc32, deflateSync } from 'node:zlib'

const ASAR_ROOT = process.env.ASAR_ROOT
const DSH_HOME = process.env.DSH_HOME
if (!ASAR_ROOT || !DSH_HOME) throw new Error('ASAR_ROOT and DSH_HOME are required')

const { Context } = await import(`${ASAR_ROOT}/dsh/node_modules/@deepseek-ai/cordis/lib/index.js`)
const { default: LocalAttachmentStore } = await import(
  `${ASAR_ROOT}/dsh/node_modules/@deepseek-ai/dsh-attachment-local/lib/index.js`
)

function chunk(type, data) {
  const length = Buffer.alloc(4)
  length.writeUInt32BE(data.length)
  const body = Buffer.concat([Buffer.from(type, 'ascii'), data])
  const crc = Buffer.alloc(4)
  crc.writeUInt32BE(crc32(body) >>> 0)
  return Buffer.concat([length, body, crc])
}

/** Deterministic 900x700 noise PNG: large enough to force a real decode. */
function noisyPng(width, height) {
  const raw = Buffer.alloc((width * 3 + 1) * height)
  let seed = 42
  for (let y = 0; y < height; y++) {
    const row = y * (width * 3 + 1)
    for (let x = 0; x < width * 3; x++) {
      seed = (seed * 1103515245 + 12345) & 0x7fffffff
      raw[row + 1 + x] = seed & 0xff
    }
  }
  const ihdr = Buffer.alloc(13)
  ihdr.writeUInt32BE(width, 0)
  ihdr.writeUInt32BE(height, 4)
  ihdr[8] = 8
  ihdr[9] = 2
  return Buffer.concat([
    Buffer.from([0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a]),
    chunk('IHDR', ihdr),
    chunk('IDAT', deflateSync(raw)),
    chunk('IEND', Buffer.alloc(0)),
  ])
}

const store = new LocalAttachmentStore(new Context(), { dshHome: DSH_HOME })
const png = noisyPng(900, 700)
const saved = await store.saveImage({ data: png, mediaType: 'image/png', name: 'ci-noise.png' })
if (saved.width !== 900 || saved.height !== 700) {
  throw new Error(`unexpected saved dimensions ${saved.width}x${saved.height}`)
}
console.log('saveImage:', saved.width, saved.height, saved.mediaType, saved.bytes)

const request = await store.readImageRequest(saved, { width: 320, height: 240, maxBytes: 200_000 })
if (request.width !== 320 || request.width > saved.width || request.height > 240) {
  throw new Error(`unexpected request image ${request.width}x${request.height}`)
}
if (!['image/jpeg', 'image/webp', 'image/png'].includes(request.mediaType)) {
  throw new Error(`unexpected request media type ${request.mediaType}`)
}
console.log('readImageRequest:', request.width, request.height, request.mediaType, request.data.length)
console.log('IMAGE-DECODE-OK')
