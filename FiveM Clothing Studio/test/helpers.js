import fs from 'node:fs';
import path from 'node:path';
import os from 'node:os';
import { RGBAImage } from '../src/core/image/rgba.js';

/** Dossier temporaire dont le nom contient accents et espaces (cas Windows réel). */
export function tmpDir(prefix = 'fcs test é') {
  return fs.mkdtempSync(path.join(os.tmpdir(), `${prefix} `));
}

/** Damier coloré avec une zone semi-transparente : sert d'image de référence. */
export function testImage(w = 64, h = 64) {
  const img = new RGBAImage(w, h);
  for (let y = 0; y < h; y++) for (let x = 0; x < w; x++) {
    const i = (y * w + x) * 4, on = ((x >> 3) + (y >> 3)) & 1;
    img.data[i] = on ? 220 : 30; img.data[i + 1] = x * 4 % 256; img.data[i + 2] = y * 4 % 256;
    img.data[i + 3] = x < w / 4 ? 128 : 255;
  }
  return img;
}

export const maxDiff = (a, b) => { let m = 0; for (let i = 0; i < a.data.length; i++) m = Math.max(m, Math.abs(a.data[i] - b.data[i])); return m; };

import zlib from 'node:zlib';
/**
 * Fichier RSC7 SYNTHÉTIQUE (en-tête + flux deflate valides, contenu factice).
 * Il permet de tester la logique d'export ; ce n'est PAS un vrai vêtement GTA V.
 */
export function fakeRsc7(version, payload = 'contenu de test') {
  const head = Buffer.alloc(16);
  head.write('RSC7', 0, 'latin1');
  head.writeUInt32LE(version, 4);
  head.writeUInt32LE(0x10, 8);
  head.writeUInt32LE(0x20, 12);
  return Buffer.concat([head, zlib.deflateRawSync(Buffer.from(payload))]);
}

/** OBJ minimal : un quad avec UV et normales (créé pour les tests). */
export const QUAD_OBJ = `# quad de test
mtllib quad.mtl
o Quad
v -1 -1 0
v 1 -1 0
v 1 1 0
v -1 1 0
vt 0 0
vt 1 0
vt 1 1
vt 0 1
vn 0 0 1
usemtl Tissu
f 1/1/1 2/2/1 3/3/1 4/4/1
`;

/** GLB minimal valide (un triangle avec UV), construit octet par octet. */
export function makeGlb({ withUv = true } = {}) {
  const pos = new Float32Array([0, 0, 0, 1, 0, 0, 0, 1, 0]);
  const uv = new Float32Array([0, 0, 1, 0, 0, 1]);
  const bin = Buffer.concat([Buffer.from(pos.buffer), ...(withUv ? [Buffer.from(uv.buffer)] : [])]);
  const json = {
    asset: { version: '2.0', generator: 'tests FCS' },
    buffers: [{ byteLength: bin.length }],
    bufferViews: [{ buffer: 0, byteOffset: 0, byteLength: 36 }, ...(withUv ? [{ buffer: 0, byteOffset: 36, byteLength: 24 }] : [])],
    accessors: [{ bufferView: 0, componentType: 5126, count: 3, type: 'VEC3', min: [0, 0, 0], max: [1, 1, 0] },
      ...(withUv ? [{ bufferView: 1, componentType: 5126, count: 3, type: 'VEC2' }] : [])],
    materials: [{ name: 'Tissu' }],
    meshes: [{ primitives: [{ attributes: { POSITION: 0, ...(withUv ? { TEXCOORD_0: 1 } : {}) }, material: 0 }] }],
    nodes: [{ mesh: 0 }], scenes: [{ nodes: [0] }], scene: 0,
  };
  let j = Buffer.from(JSON.stringify(json));
  j = Buffer.concat([j, Buffer.alloc((4 - (j.length % 4)) % 4, 0x20)]);
  const b = Buffer.concat([bin, Buffer.alloc((4 - (bin.length % 4)) % 4)]);
  const head = Buffer.alloc(12); head.write('glTF', 0); head.writeUInt32LE(2, 4); head.writeUInt32LE(12 + 8 + j.length + 8 + b.length, 8);
  const ch = (len, type) => { const c = Buffer.alloc(8); c.writeUInt32LE(len, 0); c.writeUInt32LE(type, 4); return c; };
  return Buffer.concat([head, ch(j.length, 0x4e4f534a), j, ch(b.length, 0x004e4942), b]);
}

import { encodeSurface, buildMipmaps } from '../src/core/image/dds.js';
/**
 * .ytd SYNTHÉTIQUE construit selon la structure documentée (dictionnaire 0x40, textures 0x90).
 * textures : [{ name, image (RGBAImage), format: 'dxt1'|'dxt5'|'bgra8', levels }]
 * Sert à tester la logique ; ce n'est pas un fichier du jeu.
 */
export function makeYtd(textures) {
  const FMT = { dxt1: 0x31545844, dxt5: 0x35545844, bgra8: 21, bc7: 0x20374342 };
  const align = (n, a = 16) => Math.ceil(n / a) * a;
  const n = textures.length;
  let o = 0x40;
  const hashOff = o; o = align(o + n * 4);
  const listOff = o; o = align(o + n * 8);
  const texOff = textures.map(() => { const t = o; o += 0x90; return t; });
  const nameOff = textures.map((t) => { const p = o; o = align(o + t.name.length + 1); return p; });
  const sysSize = o;
  const gfx = [];
  let g = 0;
  const dataOff = textures.map((t) => {
    const p = g;
    const mips = t.format === 'bc7' ? [t.image] : buildMipmaps(t.image, t.levels);
    for (const m of mips) { const b = t.format === 'bc7' ? new Uint8Array(m.width * m.height) : encodeSurface(m, t.format); gfx.push(b); g += b.length; }
    return p;
  });
  const gfxSize = g;
  const flagsFor = (size) => { let ss = 0; while ((0x200 << ss) < size) ss++; return ((1 << 27) | ss) >>> 0; };
  const sysAlloc = 0x200 << (flagsFor(sysSize) & 0xf), gfxAlloc = 0x200 << (flagsFor(gfxSize) & 0xf);
  const data = Buffer.alloc(sysAlloc + gfxAlloc);
  const sp = (off) => 0x50000000n + BigInt(off), gp = (off) => 0x60000000n + BigInt(off);
  data.writeBigUInt64LE(sp(hashOff), 0x20); data.writeUInt16LE(n, 0x28); data.writeUInt16LE(n, 0x2a);
  data.writeBigUInt64LE(sp(listOff), 0x30); data.writeUInt16LE(n, 0x38); data.writeUInt16LE(n, 0x3a);
  textures.forEach((t, i) => {
    data.writeBigUInt64LE(sp(texOff[i]), listOff + i * 8);
    const s = texOff[i];
    data.writeBigUInt64LE(sp(nameOff[i]), s + 0x28);
    data.writeUInt16LE(t.image.width, s + 0x50); data.writeUInt16LE(t.image.height, s + 0x52); data.writeUInt16LE(1, s + 0x54);
    data.writeUInt32LE(FMT[t.format], s + 0x58); data[s + 0x5d] = t.format === 'bc7' ? 1 : t.levels;
    data.writeBigUInt64LE(gp(dataOff[i]), s + 0x70);
    data.write(t.name + '\0', nameOff[i], 'latin1');
  });
  Buffer.concat(gfx.map((b) => Buffer.from(b))).copy(data, sysAlloc);
  const head = Buffer.alloc(16); head.write('RSC7'); head.writeUInt32LE(13, 4); head.writeUInt32LE(flagsFor(sysSize), 8); head.writeUInt32LE(flagsFor(gfxSize), 12);
  return Buffer.concat([head, zlib.deflateRawSync(data)]);
}
