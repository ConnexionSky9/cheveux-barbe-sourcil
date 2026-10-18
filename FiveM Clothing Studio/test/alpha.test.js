import { test } from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import path from 'node:path';
import { makeYtd, tmpDir } from './helpers.js';
import { RGBAImage } from '../src/core/image/rgba.js';
import { encodeImage } from '../src/core/image/codecs.js';
import { readYtd, decodeYtdTexture } from '../src/core/gta/ytd.js';
import { analyseAlpha, makeOpaque, rectMask } from '../src/core/gta/alpha.js';
import { analyse, repair } from '../scripts/transparence.js';

// Robe rouge 64×64 : un trou accidentel (8..23, 32..39, couleur blanche cachée dessous)
// et une découpe voulue (48..55, 0..7) qui doit rester transparente.
function dress() {
  const img = RGBAImage.filled(64, 64, [200, 20, 20, 255]);
  for (let y = 32; y < 40; y++) for (let x = 8; x < 24; x++) img.data.set([255, 255, 255, 0], (y * 64 + x) * 4);
  for (let y = 0; y < 8; y++) for (let x = 48; x < 56; x++) img.data.set([0, 0, 0, 0], (y * 64 + x) * 4);
  return img;
}

test('Alpha : statistiques et zone englobante des découpes', () => {
  const s = analyseAlpha(dress());
  assert.equal(s.cut, 16 * 8 + 8 * 8);
  assert.deepEqual(s.cutBox, { x: 8, y: 0, w: 48, h: 40 });
  assert.equal(analyseAlpha(RGBAImage.filled(4, 4, [1, 2, 3, 255])).cutBox, null);
});

test('Alpha : seule la zone du masque devient opaque, recolorée depuis les voisins', () => {
  const img = dress();
  const r = makeOpaque(img, rectMask(64, 64, { x: 0, y: 30, w: 30, h: 12 }));
  assert.equal(r.changed, 16 * 8);
  assert.equal(r.refilled, 16 * 8);
  assert.deepEqual(r.image.get(15, 35), [200, 20, 20, 255], 'trou bouché en rouge, pas en blanc');
  assert.equal(r.image.get(50, 3)[3], 0, 'découpe voulue conservée');
  const raw = makeOpaque(img, rectMask(64, 64, { x: 0, y: 30, w: 30, h: 12 }), { fill: false });
  assert.deepEqual(raw.image.get(15, 35), [255, 255, 255, 255]);
  assert.throws(() => makeOpaque(img, RGBAImage.filled(32, 32, [255, 255, 255])), /même taille/);
});

test('Transparence : analyse d\'un .ytd puis réparation dans un autre dossier', () => {
  const dir = tmpDir();
  const file = path.join(dir, 'mp_f_freemode_01_test^jbib_diff_003_a_uni.ytd');
  fs.writeFileSync(file, makeYtd([{ name: 'jbib_diff_003_a_uni', image: dress(), format: 'dxt5', levels: 4 }]));
  const a = analyse(file, path.join(dir, 'analyse'));
  assert.equal(a.results[0].cut, 16 * 8 + 8 * 8);
  for (const s of ['couleur', 'alpha', 'apercu']) assert.ok(fs.existsSync(path.join(dir, 'analyse', `jbib_diff_003_a_uni_${s}.png`)));

  const mask = rectMask(64, 64, { x: 0, y: 30, w: 30, h: 12 });
  fs.writeFileSync(path.join(dir, 'masque.png'), encodeImage(mask, { format: 'png' }).buffer);
  const before = fs.readFileSync(file);
  const r = repair(file, { texture: 'jbib_diff_003_a_uni', mask: path.join(dir, 'masque.png'), outDir: path.join(dir, 'corrige') });
  assert.equal(path.basename(r.out), path.basename(file), 'même nom de fichier');
  assert.deepEqual(fs.readFileSync(file), before, 'original intact');
  const fixed = decodeYtdTexture(readYtd(fs.readFileSync(r.out)), 0);
  const px = fixed.get(15, 35);
  assert.ok(px[3] === 255 && px[0] > 180 && px[1] < 40, `rouge opaque attendu, obtenu ${px}`);
  assert.equal(fixed.get(50, 3)[3], 0, 'découpe voulue conservée');
  assert.throws(() => repair(file, { texture: 'jbib_diff_003_a_uni', zone: '0,50,10,10', outDir: path.join(dir, 'c2') }), /rien à réparer/);
  assert.throws(() => repair(file, { texture: 'jbib_diff_003_a_uni', zone: '0,30,30,12', outDir: dir }), /différent/);
});
