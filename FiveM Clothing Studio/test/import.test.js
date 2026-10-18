import { test } from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import path from 'node:path';
import { tmpDir, testImage, fakeRsc7, QUAD_OBJ, makeGlb } from './helpers.js';
import { inspectFile } from '../src/core/importer.js';
import { inspectObj, inspectGltf, inspectFbx } from '../src/core/model/inspect.js';
import { encodeImage } from '../src/core/image/codecs.js';

const write = (dir, name, data) => { const p = path.join(dir, name); fs.writeFileSync(p, data); return p; };

test('OBJ valide : géométrie, UV, matériaux', () => {
  const r = inspectObj(QUAD_OBJ);
  assert.equal(r.vertices, 4); assert.equal(r.uvs, 4); assert.equal(r.faces, 1); assert.equal(r.triangles, 2);
  assert.deepEqual(r.materials, ['Tissu']);
  assert.equal(r.issues.filter((i) => i.level === 'error').length, 0);
});

test('OBJ invalide : faces hors limites, pas de géométrie, pas d\'UV', () => {
  assert.ok(inspectObj('v 0 0 0\nf 1 2 3\n').issues.some((i) => /invalide/.test(i.message)));
  assert.ok(inspectObj('# vide\n').issues.some((i) => /Aucune géométrie/.test(i.message)));
  assert.ok(inspectObj('v 0 0 0\nv 1 0 0\nv 0 1 0\nf 1 2 3\n').issues.some((i) => /UV/.test(i.message)));
});

test('GLB valide / sans UV / tronqué', () => {
  const ok = inspectGltf(makeGlb());
  assert.equal(ok.format, 'glb'); assert.equal(ok.meshes, 1); assert.equal(ok.hasUv, true);
  assert.deepEqual(ok.materials, ['Tissu']);
  assert.equal(ok.issues.filter((i) => i.level === 'error').length, 0);
  assert.ok(inspectGltf(makeGlb({ withUv: false })).issues.some((i) => /UV/.test(i.message)));
  assert.ok(inspectGltf(makeGlb().subarray(0, 40)).issues.some((i) => i.level === 'error'));
  assert.ok(inspectGltf(Buffer.from('{"asset":{"version":"1.0"},"meshes":[]}')).issues.some((i) => /version/.test(i.message)));
});

test('FBX : version lue, prise en charge annoncée comme partielle', () => {
  const head = Buffer.alloc(27); head.write('Kaydara FBX Binary  \0', 0, 'latin1'); head.writeUInt32LE(7400, 23);
  const r = inspectFbx(head);
  assert.equal(r.version, 7400);
  assert.ok(r.issues.some((i) => /partielle/.test(i.message)));
});

test('Import : texture PNG (états distincts)', () => {
  const d = tmpDir();
  const r = inspectFile(write(d, 'tee shirt é.png', encodeImage(testImage(100, 64), { format: 'png' }).buffer));
  assert.equal(r.kind, 'texture');
  assert.deepEqual(r.status, { readable: true, editable: true, viewable: true, convertible: true, exportable: false });
  assert.ok(r.issues.some((i) => /puissances de 2/.test(i.message)));
});

test('Import : modèle générique jamais déclaré exportable', () => {
  const d = tmpDir();
  const r = inspectFile(write(d, 'veste.glb', makeGlb()));
  assert.equal(r.kind, 'model');
  assert.equal(r.status.viewable, true);
  assert.equal(r.status.exportable, false);
  assert.ok(r.issues.some((i) => /n'est pas un vêtement GTA V/.test(i.message)));
});

test('Import : fichiers GTA (RSC7 synthétique), nom reconnu, faux fichier refusé', () => {
  const d = tmpDir();
  const r = inspectFile(write(d, 'mp_m_freemode_01^jbib_diff_005_a_uni.ytd', fakeRsc7(13)));
  assert.equal(r.role, 'ytd');
  assert.equal(r.status.exportable, true);
  assert.equal(r.status.viewable, false);
  assert.equal(r.info.garment.slot, 'jbib');
  const fake = inspectFile(write(d, 'faux.ydd', encodeImage(testImage(), { format: 'png' }).buffer));
  assert.ok(fake.issues.some((i) => /ne correspond pas/.test(i.message)));
  assert.equal(fake.status.exportable, false);
});

test('Import : refus des fichiers vides, trop gros, archives, inconnus', () => {
  const d = tmpDir();
  assert.ok(inspectFile(write(d, 'vide.png', Buffer.alloc(0))).issues.some((i) => /vide/.test(i.message)));
  assert.ok(inspectFile(write(d, 'gros.png', Buffer.alloc(2000)), { limits: { maxImportBytes: 1000 } }).issues.some((i) => /volumineux/.test(i.message)));
  assert.ok(inspectFile(write(d, 'pack.zip', Buffer.from('PK\x03\x04xxxx'))).issues.some((i) => /ZIP/.test(i.message)));
  assert.ok(inspectFile(write(d, 'x.bin', Buffer.from([1, 2, 3, 0, 9]))).issues.some((i) => /non reconnu/.test(i.message)));
  assert.ok(inspectFile(path.join(d, 'absent.png')).issues.some((i) => /introuvable/.test(i.message)));
});

test('Import : shop meta reconnu', () => {
  const d = tmpDir();
  const r = inspectFile(write(d, 'shop.meta', '<?xml version="1.0"?>\n<ShopPedApparel><pedName>mp_f_freemode_01</pedName><dlcName>x</dlcName></ShopPedApparel>'));
  assert.equal(r.role, 'shopmeta');
  assert.equal(r.info.pedName, 'mp_f_freemode_01');
});

test('Interface : l\'empreinte CSP correspond à la carte d\'import (importmap)', async () => {
  const { createHash } = await import('node:crypto');
  const html = fs.readFileSync(new URL('../src/renderer/index.html', import.meta.url), 'utf8');
  const map = /<script type="importmap">([\s\S]*?)<\/script>/.exec(html)[1];
  const hash = createHash('sha256').update(map).digest('base64');
  assert.ok(html.includes(`'sha256-${hash}'`), 'Mettez à jour le hash CSP dans index.html');
});
