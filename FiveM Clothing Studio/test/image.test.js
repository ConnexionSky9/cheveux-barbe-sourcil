import { test } from 'node:test';
import assert from 'node:assert/strict';
import { testImage, maxDiff } from './helpers.js';
import { RGBAImage } from '../src/core/image/rgba.js';
import * as ops from '../src/core/image/ops.js';
import { TextureDocument } from '../src/core/image/layers.js';
import { decodeImage, encodeImage } from '../src/core/image/codecs.js';
import { readDdsHeader } from '../src/core/image/dds.js';
import { sniff } from '../src/core/detect.js';

test('PNG : aller-retour sans perte, transparence conservée', () => {
  const img = testImage();
  const { buffer, lossy } = encodeImage(img, { format: 'png' });
  assert.equal(lossy, false);
  const back = decodeImage(buffer, 'png').image;
  assert.equal(maxDiff(img, back), 0);
  assert.equal(back.hasAlpha(), true);
});

test('TGA : aller-retour sans perte', () => {
  const img = testImage(30, 20);
  const back = decodeImage(encodeImage(img, { format: 'tga' }).buffer, 'tga').image;
  assert.equal(back.width, 30); assert.equal(back.height, 20);
  assert.equal(maxDiff(img, back), 0);
});

test('JPEG : avertit de la perte de transparence', () => {
  const r = encodeImage(testImage(), { format: 'jpeg' });
  assert.equal(r.lossy, true);
  assert.ok(r.warnings.some((w) => /transparence/.test(w)));
  const back = decodeImage(r.buffer, 'jpg').image;
  assert.equal(back.hasAlpha(), false);
});

test('DDS BGRA8 avec mipmaps : sans perte, chaîne complète', () => {
  const img = testImage(64, 32);
  const r = encodeImage(img, { format: 'dds', dds: { format: 'bgra8' } });
  const h = readDdsHeader(r.buffer);
  assert.equal(h.mipCount, 7); // 64x32 → 1x1
  assert.equal(h.format, 'rgb32');
  assert.equal(maxDiff(img, decodeImage(r.buffer, 'dds').image), 0);
});

test('DDS DXT5 : alpha et couleurs proches de l\'original', () => {
  const img = testImage(64, 64);
  const r = encodeImage(img, { format: 'dds', dds: { format: 'dxt5' } });
  const back = decodeImage(r.buffer, 'dds');
  assert.equal(back.info.ddsFormat, 'dxt5');
  assert.equal(back.info.mipCount, 7);
  assert.ok(maxDiff(img, back.image) < 60, 'erreur de compression raisonnable');
  assert.equal(back.image.get(2, 2)[3], 128);
});

test('DDS DXT1 : couleur unie exacte', () => {
  const img = RGBAImage.filled(16, 16, [255, 0, 0, 255]);
  const back = decodeImage(encodeImage(img, { format: 'dds', dds: { format: 'dxt1' } }).buffer, 'dds').image;
  assert.deepEqual(back.get(5, 5), [255, 0, 0, 255]);
});

test('DDS compressé : dimensions non multiples de 4 refusées', () => {
  assert.throws(() => encodeImage(RGBAImage.filled(10, 10, [0, 0, 0]), { format: 'dds', dds: { format: 'dxt1' } }), /multiples de 4/);
});

test('Fichiers corrompus : erreurs claires', () => {
  const png = encodeImage(testImage(), { format: 'png' }).buffer;
  assert.throws(() => decodeImage(png.subarray(0, 60), 'png'), /corrompue|illisible/);
  assert.throws(() => decodeImage(Buffer.from('bonjour'), 'png'), /pas une image/);
  const dds = encodeImage(testImage(), { format: 'dds', dds: { format: 'dxt5' } }).buffer;
  assert.throws(() => decodeImage(dds.subarray(0, 200), 'dds'), /tronquées/);
});

test('Détection par signature : extension trompeuse signalée', () => {
  const png = encodeImage(testImage(), { format: 'png' }).buffer;
  const s = sniff(png, 'image.jpg');
  assert.equal(s.format, 'png');
  assert.equal(s.mismatch, true);
  assert.equal(sniff(Buffer.from('RSC7\x0d\x00\x00\x00'), 'x.ytd').format, 'rsc7');
});

test('Retouches : luminosité, contraste, teinte, colorer, recadrer, effacer, rotation', () => {
  const img = RGBAImage.filled(4, 4, [100, 100, 100, 255]);
  assert.equal(ops.brightness(img, 20).get(0, 0)[0], 151);
  assert.ok(ops.contrast(img, 50).get(0, 0)[0] < 100);
  const red = RGBAImage.filled(2, 2, [255, 0, 0, 255]);
  const g = ops.hueSaturation(red, 120, 0).get(0, 0);
  assert.ok(g[1] > 250 && g[0] < 5, 'rouge → vert');
  assert.equal(ops.hueSaturation(red, 0, -100).get(0, 0)[0], g[1] > 0 ? ops.hueSaturation(red, 0, -100).get(0, 0)[1] : 0);
  const blue = ops.colorize(RGBAImage.filled(2, 2, [128, 128, 128, 255]), [0, 0, 255], 100).get(0, 0);
  assert.ok(blue[0] === blue[1] && blue[0] < 5 + blue[2], 'gris neutre conservé (pas de saturation sur gris)');
  assert.equal(img.get(0, 0)[0], 100, 'original intact');
  const c = ops.crop(testImage(), 8, 8, 16, 10);
  assert.equal(c.width, 16); assert.equal(c.height, 10);
  const e = ops.erase(img, 0, 0, 2, 2);
  assert.equal(e.get(1, 1)[3], 0); assert.equal(e.get(3, 3)[3], 255);
  const r = ops.rotate90(testImage(10, 6));
  assert.equal(r.width, 6); assert.equal(r.height, 10);
  assert.deepEqual(ops.rotate90(testImage(10, 6), 4).data, testImage(10, 6).data);
});

test('Calques : ajout, opacité, ordre, logo transformé, annuler / rétablir', () => {
  const doc = new TextureDocument(32, 32, { undoSteps: 10 });
  const bg = doc.addLayer({ name: 'Fond', image: RGBAImage.filled(32, 32, [255, 255, 255, 255]) });
  const logo = doc.addLayer({ name: 'Logo', image: RGBAImage.filled(8, 8, [255, 0, 0, 255]), x: 4, y: 4 });
  let out = doc.composite();
  assert.deepEqual(out.get(6, 6), [255, 0, 0, 255]);
  assert.deepEqual(out.get(20, 20), [255, 255, 255, 255]);
  doc.updateLayer(logo, { opacity: 0.5 });
  out = doc.composite();
  assert.ok(Math.abs(out.get(6, 6)[1] - 128) <= 1);
  doc.updateLayer(logo, { visible: false });
  assert.deepEqual(doc.composite().get(6, 6), [255, 255, 255, 255]);
  doc.undo(); doc.undo();
  assert.deepEqual(doc.composite().get(6, 6), [255, 0, 0, 255]);
  doc.redo();
  assert.ok(Math.abs(doc.composite().get(6, 6)[1] - 128) <= 1);
  const dup = doc.duplicateLayer(logo);
  assert.equal(doc.layers.length, 3);
  doc.moveLayer(dup, 0);
  assert.equal(doc.layers[0].id, dup);
  doc.applyToLayer(bg, 'Assombrir', (im) => ops.brightness(im, -100));
  assert.equal(doc.layer(bg).image.get(0, 0)[0], 0);
  doc.undo();
  assert.equal(doc.layer(bg).image.get(0, 0)[0], 255);
  doc.removeLayer(dup);
  assert.equal(doc.layers.length, 2);
  // Rotation du logo : le pixel du centre reste rouge
  doc.updateLayer(logo, { rotation: 45, scale: 2, opacity: 1, visible: true });
  assert.deepEqual(doc.composite().get(12, 12), [255, 0, 0, 255]);
  // Sérialisation
  const s = doc.serialize();
  const back = TextureDocument.deserialize(s.json, s.images);
  assert.equal(maxDiff(back.composite(), doc.composite()), 0);
});

test('Calques : historique limité', () => {
  const doc = new TextureDocument(4, 4, { undoSteps: 3 });
  for (let i = 0; i < 6; i++) doc.addLayer({ name: `C${i}` });
  let n = 0; while (doc.undo()) n++;
  assert.equal(n, 3);
});

test('Recadrage du document non destructif', () => {
  const doc = new TextureDocument(32, 32);
  const l = doc.addLayer({ image: testImage(32, 32) });
  doc.cropDocument(8, 8, 16, 16);
  assert.equal(doc.width, 16);
  assert.equal(doc.layer(l).x, -8);
  assert.equal(doc.layer(l).image.width, 32);
  doc.undo();
  assert.equal(doc.width, 32);
});

test('Pinceau et gomme', () => {
  const img = RGBAImage.filled(20, 20, [0, 0, 0, 255]);
  ops.brushStroke(img, [[2, 10], [18, 10]], { size: 4, color: [255, 255, 255, 255], hardness: 1 });
  assert.deepEqual(img.get(10, 10), [255, 255, 255, 255]);
  assert.deepEqual(img.get(10, 2), [0, 0, 0, 255]);
  ops.brushStroke(img, [[10, 10]], { size: 4, erase: true, hardness: 1 });
  assert.equal(img.get(10, 10)[3], 0);
});
