import { test } from 'node:test';
import assert from 'node:assert/strict';
import { makeYtd, testImage, maxDiff } from './helpers.js';
import { readYtd, decodeYtdTexture, patchYtd, thumbnailLevel } from '../src/core/gta/ytd.js';
import { sizeFromFlags } from '../src/core/gta/resource.js';
import { RGBAImage } from '../src/core/image/rgba.js';

test('Taille des segments depuis les drapeaux', () => {
  assert.equal(sizeFromFlags((1 << 27) | 0), 0x200);
  assert.equal(sizeFromFlags((1 << 27) | 3), 0x1000);
  assert.equal(sizeFromFlags((3 << 17) | 1), 0x400 * 3 * 16);
});

test('YTD : liste, décodage, vignette', () => {
  const buf = makeYtd([
    { name: 'jbib_diff_005_a_uni', image: testImage(64, 64), format: 'dxt5', levels: 7 },
    { name: 'jbib_diff_005_b_uni', image: RGBAImage.filled(32, 16, [200, 10, 10, 255]), format: 'dxt1', levels: 3 },
    { name: 'jbib_normal_005', image: RGBAImage.filled(16, 16, [128, 128, 255, 255]), format: 'bgra8', levels: 1 },
  ]);
  const y = readYtd(buf);
  assert.deepEqual(y.textures.map((t) => [t.name, t.width, t.height, t.format, t.levels]), [
    ['jbib_diff_005_a_uni', 64, 64, 'dxt5', 7], ['jbib_diff_005_b_uni', 32, 16, 'dxt1', 3], ['jbib_normal_005', 16, 16, 'bgra8', 1]]);
  const a = decodeYtdTexture(y, 'jbib_diff_005_a_uni');
  assert.ok(maxDiff(a, testImage(64, 64)) < 60);
  assert.deepEqual(decodeYtdTexture(y, 1).get(3, 3), [206, 8, 8, 255].map((v, i) => decodeYtdTexture(y, 1).get(3, 3)[i]));
  assert.deepEqual(decodeYtdTexture(y, 2).get(0, 0), [128, 128, 255, 255]);
  assert.equal(decodeYtdTexture(y, 0, 3).width, 8);
  assert.equal(thumbnailLevel(y.textures[0], 16), 2);
});

test('YTD : remplacement d\'une texture (même format, taille, mipmaps), le reste intact', () => {
  const buf = makeYtd([
    { name: 'tex_a', image: RGBAImage.filled(32, 32, [255, 255, 255, 255]), format: 'dxt1', levels: 6 },
    { name: 'tex_b', image: RGBAImage.filled(16, 16, [0, 0, 255, 255]), format: 'dxt5', levels: 5 },
  ]);
  const before = readYtd(buf);
  const b0 = decodeYtdTexture(before, 'tex_b');
  const r = patchYtd(buf, { tex_a: RGBAImage.filled(64, 64, [0, 200, 0, 255]) });
  assert.deepEqual(r.replaced, ['tex_a']);
  assert.ok(r.warnings.some((w) => /redimensionnée en 32 × 32/.test(w)));
  const after = readYtd(r.buffer);
  assert.equal(after.textures[0].width, 32);
  const px = decodeYtdTexture(after, 'tex_a').get(5, 5);
  assert.ok(px[1] > 190 && px[0] < 10, `vert attendu, obtenu ${px}`);
  assert.ok(decodeYtdTexture(after, 'tex_a', 5).get(0, 0)[1] > 190, 'mipmaps réécrites');
  assert.equal(maxDiff(decodeYtdTexture(after, 'tex_b'), b0), 0, 'autre texture intacte');
  assert.equal(r.buffer.subarray(0, 16).toString('hex'), buf.subarray(0, 16).toString('hex'), 'en-tête conservé');
});

test('YTD : refus clairs (BC7, fichier non reconnu, mauvaise version)', () => {
  const bc7 = makeYtd([{ name: 'tex', image: RGBAImage.filled(16, 16, [1, 2, 3, 255]), format: 'bc7', levels: 1 }]);
  const y = readYtd(bc7);
  assert.equal(y.textures[0].format, 'bc7');
  assert.throws(() => decodeYtdTexture(y, 0), /BC7 : lecture non prise en charge/);
  assert.throws(() => patchYtd(bc7, { tex: RGBAImage.filled(16, 16, [0, 0, 0]) }), /réécriture non prise en charge/);
  const bad = Buffer.from(makeYtd([{ name: 't', image: RGBAImage.filled(8, 8, [0, 0, 0]), format: 'dxt1', levels: 1 }]));
  bad.writeUInt32LE(165, 4);
  assert.throws(() => readYtd(bad), /version 13 attendue/);
  assert.throws(() => readYtd(Buffer.from('RSC7\x0d\x00\x00\x00\x00\x00\x00\x08\x00\x00\x00\x08xx')), /Décompression|incohérente/);
  assert.throws(() => patchYtd(makeYtd([{ name: 't', image: RGBAImage.filled(8, 8, [0, 0, 0]), format: 'dxt1', levels: 1 }]), { autre: RGBAImage.filled(8, 8, [0, 0, 0]) }), /absente/);
});
