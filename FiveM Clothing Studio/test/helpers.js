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
